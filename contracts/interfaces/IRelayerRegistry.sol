// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

interface IRelayerRegistry {
  function getRelayerName(address relayer) external view returns (string memory);
  function getRelayerHostName(address relayer) external view returns (string memory);
  function getRelayerBalance(address relayer) external view returns (uint256);
  function isRelayerRegistered(address relayer, address toResolve) external view returns (bool);
}