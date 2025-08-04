// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

import { EtnSend } from "./EtnSend.sol";

/**
 * @notice this contract should store ETN for gas compensations and also retrieve the basefee
 * */
contract GasCompensationVault {
  using EtnSend for address;

  address public governance;

  constructor(address _governance) {
    governance = _governance;
  }

  modifier onlyGovernance() {
    require(msg.sender == governance, "only gov");
    _;
  }

  /**
   * @notice function to compensate gas by sending amount ETN to a recipient
   * @param recipient address to receive amount ETN
   * @param gasAmount the amount of gas to be compensated
   * */
  function compensateGas(address recipient, uint256 gasAmount) external onlyGovernance {
    uint256 vaultBalance = address(this).balance;
    uint256 toCompensate = gasAmount * block.basefee;
    if (vaultBalance == 0) return;
    payable(recipient).send((toCompensate > vaultBalance) ? vaultBalance : toCompensate);
  }

  /**
   * @notice function to withdraw compensate ETN back to governance
   * @param amount the amount of etn to withdraw back to governance
   * */
  function withdrawToGovernance(uint256 amount) external onlyGovernance {
    uint256 vaultBalance = address(this).balance;
    require(governance.sendEtn((amount > vaultBalance) ? vaultBalance : amount), "pay fail");
  }

  /**
   * @notice receive etn function, does nothing but receive etn
   * */
  receive() external payable {}
}