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

import { Initializable } from "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interfaces/IMishMashInstance.sol";
import "../proxy/MishMashRouter.sol";
import "../proxy/FeeManager.sol";

contract InstanceRegistry is Initializable {
  using SafeERC20 for IERC20;

  enum InstanceState {
    DISABLED,
    ENABLED
  }

  struct Instance {
    bool isERC20;
    IERC20 token;
    uint256 denomination;
    InstanceState state;
    uint24 poolSwappingFee; // the fee of the pool which will be used to get a TWAP
    uint32 protocolFeePercentage; // the fee the protocol takes from relayer, it should be multiplied by PROTOCOL_FEE_DIVIDER from FeeManager.sol
  }

  struct MishMashInstance {
    IMishMashInstance addr;
    Instance instance;
  }

  address public immutable governance;
  MishMashRouter public router;

  mapping(IMishMashInstance => Instance) public instances;
  IMishMashInstance[] public instanceIds;

  event InstanceStateUpdated(IMishMashInstance indexed instance, InstanceState state);
  event RouterRegistered(address router);

  modifier onlyGovernance() {
    require(msg.sender == governance, "Not authorized");
    _;
  }

  constructor(address _governance) public {
    governance = _governance;
  }

  function initialize(MishMashInstance[] memory _instances, address _router) external initializer {
    router = MishMashRouter(_router);
    for (uint256 i = 0; i < _instances.length; i++) {
      _updateInstance(_instances[i]);
      instanceIds.push(_instances[i].addr);
    }
  }

  /**
   * @dev Add or update an instance.
   */
  function updateInstance(MishMashInstance calldata _instance) external virtual onlyGovernance {
    require(_instance.instance.state != InstanceState.DISABLED, "Use removeInstance() for remove");
    if (instances[_instance.addr].state == InstanceState.DISABLED) {
      instanceIds.push(_instance.addr);
    }
    _updateInstance(_instance);
  }

  /**
   * @dev Remove an instance.
   * @param _instanceId The instance id in `instanceIds` mapping to remove.
   */
  function removeInstance(uint256 _instanceId) external virtual onlyGovernance {
    IMishMashInstance _instance = instanceIds[_instanceId];
    (bool isERC20, IERC20 token) = (instances[_instance].isERC20, instances[_instance].token);

    if (isERC20) {
      uint256 allowance = token.allowance(address(router), address(_instance));
      if (allowance != 0) {
        router.approveExactToken(token, address(_instance), 0);
      }
    }

    delete instances[_instance];
    instanceIds[_instanceId] = instanceIds[instanceIds.length - 1];
    instanceIds.pop();
    emit InstanceStateUpdated(_instance, InstanceState.DISABLED);
  }

  /**
   * @notice This function should allow governance to set a new protocol fee for relayers
   * @param instance the to update
   * @param newFee the new fee to use
   * */
  function setProtocolFee(IMishMashInstance instance, uint32 newFee) external onlyGovernance {
    instances[instance].protocolFeePercentage = newFee;
  }

  /**
   * @notice This function should allow governance to set a new MishMashRouter address
   * @param routerAddress address of the new proxy
   * */
  function setRouter(address routerAddress) external onlyGovernance {
    router = MishMashRouter(routerAddress);
    emit RouterRegistered(routerAddress);
  }

  function _updateInstance(MishMashInstance memory _instance) internal virtual {
    instances[_instance.addr] = _instance.instance;
    if (_instance.instance.isERC20) {
      IERC20 token = IERC20(_instance.addr.token());
      require(token == _instance.instance.token, "Incorrect token");
      uint256 allowance = token.allowance(address(router), address(_instance.addr));

      if (allowance == 0) {
        router.approveExactToken(token, address(_instance.addr), type(uint256).max);
      }
    }
    emit InstanceStateUpdated(_instance.addr, _instance.instance.state);
  }

  /**
   * @dev Returns all instance configs
   */
  function getAllInstances() public view returns (MishMashInstance[] memory result) {
    result = new MishMashInstance[](instanceIds.length);
    for (uint256 i = 0; i < instanceIds.length; i++) {
      IMishMashInstance _instance = instanceIds[i];
      result[i] = MishMashInstance({ addr: _instance, instance: instances[_instance] });
    }
  }

  /**
   * @dev Returns all instance addresses
   */
  function getAllInstanceAddresses() public view returns (IMishMashInstance[] memory result) {
    result = new IMishMashInstance[](instanceIds.length);
    for (uint256 i = 0; i < instanceIds.length; i++) {
      result[i] = instanceIds[i];
    }
  }

  /// @notice get erc20 instance token
  /// @param instance the interface (contract) key to the instance data
  function getPoolToken(IMishMashInstance instance) external view returns (address) {
    return address(instances[instance].token);
  }
}