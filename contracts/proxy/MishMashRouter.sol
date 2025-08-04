// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

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

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "../interfaces/IMishMashInstance.sol";
import "../registries/InstanceRegistry.sol";
import "../registries/RelayerRegistry.sol";

contract MishMashRouter {
  using SafeERC20 for IERC20;

  event EncryptedNote(address indexed sender, bytes encryptedNote);

  address public immutable governance;
  InstanceRegistry public immutable instanceRegistry;
  RelayerRegistry public immutable relayerRegistry;

  modifier onlyGovernance() {
    require(msg.sender == governance, "Not authorized");
    _;
  }

  modifier onlyInstanceRegistry() {
    require(msg.sender == address(instanceRegistry), "Not authorized");
    _;
  }

  constructor(
    address _governance,
    address _instanceRegistry,
    address _relayerRegistry
  ) {
    governance = _governance;
    instanceRegistry = InstanceRegistry(_instanceRegistry);
    relayerRegistry = RelayerRegistry(_relayerRegistry);
  }

  function deposit(
    IMishMashInstance _instance,
    bytes32 _commitment,
    bytes calldata _encryptedNote
  ) public payable virtual {
    (bool isERC20, IERC20 token, ,InstanceRegistry.InstanceState state, , ) = instanceRegistry.instances(_instance);
    require(state != InstanceRegistry.InstanceState.DISABLED, "The instance is not supported");

    if (isERC20) {
      token.safeTransferFrom(msg.sender, address(this), _instance.denomination());
    }
    _instance.deposit{ value: msg.value }(_commitment);
    emit EncryptedNote(msg.sender, _encryptedNote);
  }

  function withdraw(
    IMishMashInstance _instance,
    bytes calldata _proof,
    bytes32 _root,
    bytes32 _nullifierHash,
    address payable _recipient,
    address payable _relayer,
    uint256 _fee,
    uint256 _refund
  ) public payable virtual {
    (, , ,InstanceRegistry.InstanceState state, , ) = instanceRegistry.instances(_instance);
    require(state != InstanceRegistry.InstanceState.DISABLED, "The instance is not supported");
    relayerRegistry.burn(msg.sender, _relayer, _instance);

    _instance.withdraw{ value: msg.value }(_proof, _root, _nullifierHash, _recipient, _relayer, _fee, _refund);
  }

  /**
   * @dev Sets `amount` allowance of `_spender` over the router's (this contract) tokens.
   */
  function approveExactToken(
    IERC20 _token,
    address _spender,
    uint256 _amount
  ) external onlyInstanceRegistry {
    _token.safeApprove(_spender, _amount);
  }

  /**
   * @notice Manually backup encrypted notes
   */
  function backupNotes(bytes[] calldata _encryptedNotes) external virtual {
    for (uint256 i = 0; i < _encryptedNotes.length; i++) {
      emit EncryptedNote(msg.sender, _encryptedNotes[i]);
    }
  }

  /// @dev Method to claim junk and accidentally sent tokens
  function rescueTokens(
    IERC20 _token,
    address payable _to,
    uint256 _amount
  ) external virtual onlyGovernance {
    require(_to != address(0), "MASH: can not send to zero address");

    if (_token == IERC20(0)) {
      // for Ether
      uint256 totalBalance = address(this).balance;
      uint256 balance = Math.min(totalBalance, _amount);
      _to.transfer(balance);
    } else {
      // any other erc20
      uint256 totalBalance = _token.balanceOf(address(this));
      uint256 balance = Math.min(totalBalance, _amount);
      require(balance > 0, "MASH: trying to send 0 balance");
      _token.safeTransfer(_to, balance);
    }
  }
}