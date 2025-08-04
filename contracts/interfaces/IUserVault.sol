// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

interface IUserVault {
  function withdrawMash(address recipient, uint256 amount) external;
}