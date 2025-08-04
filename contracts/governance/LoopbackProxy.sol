// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

/*
 * 888b     d888 d8b          888      888b     d888                   888                                     888     
 * 8888b   d8888 Y8P          888      8888b   d8888                   888                                     888     
 * 88888b.d88888              888      88888b.d88888                   888                                     888     
 * 888Y88888P888 888 .d8888b  88888b.  888Y88888P888  8888b.  .d8888b  88888b.       .d8888b  8888b.  .d8888b  88888b. 
 * 888 Y888P 888 888 88K      888 "88b 888 Y888P 888     "88b 88K      888 "88b     d88P"        "88b 88K      888 "88b
 * 888  Y8P  888 888 "Y8888b. 888  888 888  Y8P  888 .d888888 "Y8888b. 888  888     888      .d888888 "Y8888b. 888  888
 * 888   "   888 888      X88 888  888 888   "   888 888  888      X88 888  888 d8b Y88b.    888  888      X88 888  888
 * 888       888 888  88888P' 888  888 888       888 "Y888888  88888P' 888  888 Y8P  "Y8888P "Y888888  88888P' 888  888
 *
 * https://ipfs.mishmash.cash
 * https://x.com/MishMash_Cash
 * 
 * MishMash.cash is a Tornado.cash clone enabling non-custodial anonymous transactions on Electroneum 2.0
 */

import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

/**
 * @dev TransparentUpgradeableProxy that sets its admin to the implementation itself allowing upgrades via governance
 * It is also allowed to call implementation methods.
 */
contract LoopbackProxy is TransparentUpgradeableProxy {
  /**
   * @dev Initializes an upgradeable proxy backed by the implementation at `_logic`.
   */
  constructor(address _logic, bytes memory _data) payable TransparentUpgradeableProxy(_logic, address(this), _data) {}

  /**
   * @dev Override to allow admin (itself) access the fallback function.
   */
  function _beforeFallback() internal override {}
} 