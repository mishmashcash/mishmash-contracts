// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "./IUserVault.sol";

interface IGovernance {
  function lockedBalance(address account) external view returns (uint256);
  function userVault() external view returns (IUserVault);
}