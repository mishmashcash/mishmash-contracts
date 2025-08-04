// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "../interfaces/IRelayerRegistry.sol";

struct Relayer {
  address relayerAddress;
  string relayerName;
  string hostName;
  uint256 balance;
  bool isRegistered;
}

contract RelayerAggregator {

  IRelayerRegistry public immutable relayerRegistry;
  
  constructor(address _relayerRegistry){
    relayerRegistry = IRelayerRegistry(_relayerRegistry);
  }

  function relayersData(address[] memory _relayers) public view returns (Relayer[] memory) {
    Relayer[] memory relayers = new Relayer[](_relayers.length);
    for (uint256 i = 0; i < _relayers.length; i++) {
      relayers[i].relayerAddress = _relayers[i];
      relayers[i].relayerName = relayerRegistry.getRelayerName(_relayers[i]);
      relayers[i].hostName = relayerRegistry.getRelayerHostName(_relayers[i]);
      relayers[i].balance = relayerRegistry.getRelayerBalance(_relayers[i]);
      relayers[i].isRegistered = relayerRegistry.isRelayerRegistered(_relayers[i], _relayers[i]);
    }
    return relayers;
  }
}