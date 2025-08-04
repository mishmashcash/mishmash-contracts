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

import { V3OracleHelper } from "../libraries/V3OracleHelper.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IMishMashInstance.sol";
import "../registries/InstanceRegistry.sol";

/// @dev contract which calculates the fee for each pool
contract FeeManager {
  using SafeMath for uint256;

  uint256 public constant PROTOCOL_FEE_DIVIDER = 10000;
  address public immutable mash;
  address public immutable governance;
  InstanceRegistry public immutable instanceRegistry;

  uint24 public mashPoolSwappingFee;
  uint32 public timePeriod;

  uint24 public updateFeeTimeLimit;

  mapping(IMishMashInstance => uint160) public instanceFee;
  mapping(IMishMashInstance => uint256) public instanceFeeUpdated;

  event FeeUpdated(address indexed instance, uint256 newFee);
  event MashPoolSwappingFeeChanged(uint24 newFee);

  modifier onlyGovernance() {
    require(msg.sender == governance);
    _;
  }

  struct Deviation {
    address instance;
    int256 deviation; // in 10**-1 percents, so it can be like -2.3% if the price of MASH declined
  }

  constructor(
    address _mash,
    address _governance,
    address _instanceRegistry
  ) public {
    mash = _mash;
    governance = _governance;
    instanceRegistry = InstanceRegistry(_instanceRegistry);
  }

  /**
   * @notice This function should update the fees of each pool
   */
  function updateAllFees() external {
    updateFees(instanceRegistry.getAllInstanceAddresses());
  }

  /**
   * @notice This function should update the fees for MishMash instances
   *         (here called pools)
   * @param _instances pool addresses to update fees for
   * */
  function updateFees(IMishMashInstance[] memory _instances) public {
    for (uint256 i = 0; i < _instances.length; i++) {
      updateFee(_instances[i]);
    }
  }

  /**
   * @notice This function should update the fee of a specific pool
   * @param _instance address of the pool to update fees for
   */
  function updateFee(IMishMashInstance _instance) public {
    uint160 newFee = calculatePoolFee(_instance);
    instanceFee[_instance] = newFee;
    instanceFeeUpdated[_instance] = block.timestamp;
    emit FeeUpdated(address(_instance), newFee);
  }

  /**
   * @notice This function should return the fee of a specific pool and update it if the time has come
   * @param _instance address of the pool to get fees for
   */
  function instanceFeeWithUpdate(IMishMashInstance _instance) public returns (uint160) {
    if (block.timestamp - instanceFeeUpdated[_instance] > updateFeeTimeLimit) {
      updateFee(_instance);
    }
    return instanceFee[_instance];
  }

  /**
   * @notice function to update a single fee entry
   * @param _instance instance for which to update data
   * @return newFee the new fee pool
   */
  function calculatePoolFee(IMishMashInstance _instance) public view returns (uint160) {
    (bool isERC20, IERC20 token, uint256 denomination, , uint24 poolSwappingFee, uint32 protocolFeePercentage) = instanceRegistry.instances(_instance);
    if (protocolFeePercentage == 0) {
      return 0;
    }

    token = token == IERC20(0) && !isERC20 ? IERC20(V3OracleHelper.WETH) : token; // for eth instances
    uint256 tokenPriceRatio = V3OracleHelper.getPriceRatioOfTokens(
      [mash, address(token)],
      [mashPoolSwappingFee, poolSwappingFee],
      timePeriod
    );
    // prettier-ignore
    return
      uint160(
        denomination
        .mul(V3OracleHelper.RATIO_DIVIDER)
        .div(tokenPriceRatio)
        .mul(uint256(protocolFeePercentage))
        .div(PROTOCOL_FEE_DIVIDER)
      );
  }

  /**
   * @notice function to update the uniswap fee
   * @param _mashPoolSwappingFee new uniswap fee
   */
  function setMashPoolSwappingFee(uint24 _mashPoolSwappingFee) public onlyGovernance {
    mashPoolSwappingFee = _mashPoolSwappingFee;
    emit MashPoolSwappingFeeChanged(mashPoolSwappingFee);
  }

  /**
   * @notice This function should allow governance to set a new period for twap measurement
   * @param newPeriod the new period to use
   * */
  function setPeriodForTWAPOracle(uint32 newPeriod) external onlyGovernance {
    timePeriod = newPeriod;
  }

  /**
   * @notice This function should allow governance to set a new update fee time limit for instance fee updating
   * @param newLimit the new time limit to use
   * */
  function setUpdateFeeTimeLimit(uint24 newLimit) external onlyGovernance {
    updateFeeTimeLimit = newLimit;
  }

  /**
   * @notice returns fees deviations for each instance, so it can be easily seen what instance requires an update
   */
  function feeDeviations() public view returns (Deviation[] memory results) {
    IMishMashInstance[] memory instances = instanceRegistry.getAllInstanceAddresses();
    results = new Deviation[](instances.length);

    for (uint256 i = 0; i < instances.length; i++) {
      uint256 marketFee = calculatePoolFee(instances[i]);
      int256 deviation;
      if (marketFee != 0) {
        deviation = int256((instanceFee[instances[i]] * 1000) / marketFee) - 1000;
      }

      results[i] = Deviation({ instance: address(instances[i]), deviation: deviation });
    }
  }
}