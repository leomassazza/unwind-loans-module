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
  // address public constant SNX_PDAO_MULTISIG_ADDRESS = 0x6cd3f878852769e04A723A5f66CA7DD4d9E38A6C; // Optimism
  address public constant SNX_PDAO_MULTISIG_ADDRESS = 0xEb3107117FEAd7de89Cd14D463D340A2E6917769; // Ethereum
  address public constant SNX_TC_MULTISIG_ADDRESS = 0x99F4176EE457afedFfCB1839c7aB7A030a5e4A92; // TC Multisig
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

    // 0- check initial eth balance
    uint256 initialEthBalance = address(this).balance;
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
    // 6- call claim
    collateralEth.claim(pendingWithdrawal);
    // 7- confirm that the eth balance is higher than the initial balance by at least pendingWithdrawalAmount
    uint256 currentEthBalance = address(this).balance;
    require(currentEthBalance >= initialEthBalance, 'Eth balance is lower than initial balance');
    require(
      address(this).balance - initialEthBalance >= pendingWithdrawalAmount,
      'Not enough eth withdrawn'
    );
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
    require(
      msg.sender == endorsedAccount || msg.sender == SNX_TC_MULTISIG_ADDRESS,
      'Not endorsed or TC'
    );
    bool success = IERC20(underlyingContract).transfer(SNX_TC_MULTISIG_ADDRESS, amount);
    require(success, 'Transfer failed');
  }

  function withdrawEth(uint256 amount) external nonReentrant {
    require(
      msg.sender == endorsedAccount || msg.sender == SNX_TC_MULTISIG_ADDRESS,
      'Not endorsed or TC'
    );
    // solhint-disable avoid-low-level-calls
    (bool success, ) = SNX_TC_MULTISIG_ADDRESS.call{value: amount}('');
    require(success, 'Transfer failed');
  }

  // --- Internal --- //

  function _executeSafeTransaction_UpdateMinCratio(
    uint256 minCratio
  ) internal returns (bool success) {
    bytes memory payload = abi.encodeWithSignature('setMinCratio(uint256)', minCratio);

    success = _pDAOSafe.execTransactionFromModule(
      SNX_COLLATERAL_ETH,
      0,
      payload,
      Enum.Operation.Call
    );
  }

  // --- Events --- //
}
