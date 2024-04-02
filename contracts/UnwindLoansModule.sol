// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import './interfaces/GnosisSafe.sol';
import './interfaces/AddressResolver.sol';
import './interfaces/ICollateralEthReduced.sol';

// UnwindLoansModule is a module, which is able to ...
//
// @see: https://sips.synthetix.io/sips/sip-2095/
contract UnwindLoansModule is Ownable, ReentrancyGuard {
  address public constant SNX_PDAO_MULTISIG_ADDRESS = 0x6cd3f878852769e04A723A5f66CA7DD4d9E38A6C;
  // address public constant SNX_ADDRESS_RESOLVER = 0x95A6a3f44a70172E7d50a9e28c85Dfd712756B8C;
  address public constant SNX_COLLATERAL_ETH = 0x5c8344bcdC38F1aB5EB5C1d4a35DdEeA522B5DfA; // https://etherscan.io/address/0x5c8344bcdC38F1aB5EB5C1d4a35DdEeA522B5DfA

  GnosisSafe private _pDAOSafe;
  // AddressResolver private _addressResolver;

  bool public isPaused;
  address public endorsedAccount;

  constructor(address _owner, address _endorsedAccount) {
    // Do not call Ownable constructor which sets the owner to the msg.sender and set it to _owner.
    _transferOwnership(_owner);

    // _addressResolver = AddressResolver(SNX_ADDRESS_RESOLVER);
    _pDAOSafe = GnosisSafe(SNX_PDAO_MULTISIG_ADDRESS);

    // endorsedAccount
    endorsedAccount = _endorsedAccount;

    // start as paused
    isPaused = true;
  }

  // --- External/Public --- //

  // @dev set MMV to zero on the corresponding market.
  function unwind(
    uint minCratioUpdatedValue,
    address liquidatedUserAddress,
    uint loanId,
    uint liquidationAmount,
    uint pendingWithdrawalAmount
  ) external returns (bool success) {
    require(!isPaused, 'Module paused');
    require(msg.sender == endorsedAccount, 'Not endorsed');

    ICollateralEthReduced collateralEth = ICollateralEthReduced(SNX_COLLATERAL_ETH);

    // 1- read the inicial minCRatio
    uint256 previousMinCratio = collateralEth.minCratio();
    // 2- set the new minCRatio
    success = _executeSafeTransaction_UpdateMinCratio(minCratioUpdatedValue);
    require(success, 'Failed to update minCratio to updated value');
    // 3- call liquidate
    collateralEth.liquidate(liquidatedUserAddress, loanId, liquidationAmount);
    // 4- set the minCRatio back to the original value
    success = _executeSafeTransaction_UpdateMinCratio(previousMinCratio);
    require(success, 'Failed to update minCratio to previous value');
    // 5- read pendingWithdrawals and compare value with pendingWithdrawalAmount. Must be higher
    uint256 pendingWithdrawal = collateralEth.pendingWithdrawals(address(this));
    require(pendingWithdrawal >= pendingWithdrawalAmount, 'not enough pending withdrawal');
    // 6- call claim
    collateralEth.claim(pendingWithdrawal);
  }

  // @dev sets the paused state
  function setPaused(bool _isPaused) external onlyOwner {
    isPaused = _isPaused;
  }

  // @dev sets the endorsed account
  function setEndorsedAccount(address _endorsedAccount) external onlyOwner {
    endorsedAccount = _endorsedAccount;
  }

  function withdrawErc20(uint256 amount, address underlyingContract) external nonReentrant {
    require(msg.sender == endorsedAccount, 'Not endorsed');
    bool success = IERC20(underlyingContract).transfer(msg.sender, amount);
    require(success, 'Transfer failed');
  }

  function withdrawEth(uint256 amount) external nonReentrant {
    require(msg.sender == endorsedAccount, 'Not endorsed');
    // solhint-disable avoid-low-level-calls
    (bool success, ) = msg.sender.call{value: amount}('');
    require(success, 'Transfer failed');
  }

  // --- Internal --- //

  function _executeSafeTransaction_UpdateMinCratio(
    uint256 minCratio
  ) internal returns (bool success) {
    // bytes memory payload = abi.encodeWithSignature(
    //   'setMaxMarketValue(bytes32,uint256)',
    //   marketKey,
    //   0
    // );
    // address marketSettingsAddress = _addressResolver.requireAndGetAddress(
    //   'PerpsV2MarketSettings',
    //   'Missing Perpsv2MarketSettings address'
    // );

    bytes memory payload = abi.encodeWithSignature('setMinCratio(uint256)', minCratio);

    success = _pDAOSafe.execTransactionFromModule(
      SNX_COLLATERAL_ETH,
      0,
      payload,
      Enum.Operation.Call
    );
    // uint256 _lastParamterUpdatedAtTime = block.timestamp;

    // if (success) {
    //   emit ReduceMMVDone(marketKey, _lastParamterUpdatedAtTime);
    // } else {
    //   emit ReduceMMVFailed(marketKey, _lastParamterUpdatedAtTime);
    // }
  }

  // --- Events --- //

  // event ReduceMMVDone(bytes32 marketKey, uint256 paramterUpdatedAtTime);
  // event ReduceMMVFailed(bytes32 marketKey, uint256 paramterUpdateAttemptedAtTime);
}
