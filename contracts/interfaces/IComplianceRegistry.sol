// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

interface IComplianceRegistry {
  function isSanctioned(address account) external view returns (bool);
}