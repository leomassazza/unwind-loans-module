// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ICollateralEthReduced {
  function minCratio() external view returns (uint256);

  function setMinCratio(uint256 _minCratio) external;

  function liquidate(address borrower, uint256 id, uint256 amount) external;

  function pendingWithdrawals(address account) external view returns (uint256);

  function claim(uint256 amount) external;
}
