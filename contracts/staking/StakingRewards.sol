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

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { IGovernance } from "../interfaces/IGovernance.sol";

/**
 * @notice This is the staking contract of the governance staking upgrade.
 *         This contract should hold the staked funds which are received upon relayer registration,
 *         and properly attribute rewards to addresses without security issues.
 * @dev CONTRACT RISKS:
 *      - Relayer staked MASH at risk if contract is compromised.
 * */
contract StakingRewards {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  /// @notice 1e25
  uint256 public immutable ratioConstant;
  IGovernance public immutable Governance;
  IERC20 public immutable mash;
  address public immutable relayerRegistry;

  /// @notice the sum mash_burned_i/locked_amount_i*coefficient where i is incremented at each burn
  uint256 public accumulatedRewardPerMash;
  /// @notice notes down accumulatedRewardPerMash for an address on a lock/unlock/claim
  mapping(address => uint256) public accumulatedRewardRateOnLastUpdate;
  /// @notice notes down how much an account may claim
  mapping(address => uint256) public accumulatedRewards;

  event RewardsUpdated(address indexed account, uint256 rewards);
  event RewardsClaimed(address indexed account, uint256 rewardsClaimed);

  modifier onlyGovernance() {
    require(msg.sender == address(Governance), "only governance");
    _;
  }

  constructor(
    address governanceAddress,
    address mashAddress,
    address _relayerRegistry
  ) public {
    Governance = IGovernance(governanceAddress);
    mash = IERC20(mashAddress);
    relayerRegistry = _relayerRegistry;
    ratioConstant = IERC20(mashAddress).totalSupply();
  }

  /**
   * @notice This function should safely send a user his rewards.
   * @dev IMPORTANT FUNCTION:
   *      We know that rewards are going to be updated every time someone locks or unlocks
   *      so we know that this function can't be used to falsely increase the amount of
   *      lockedMash by locking in governance and subsequently calling it.
   *      - set rewards to 0 greedily
   */
  function getReward() external {
    uint256 rewards = _updateReward(msg.sender, Governance.lockedBalance(msg.sender));
    rewards = rewards.add(accumulatedRewards[msg.sender]);
    accumulatedRewards[msg.sender] = 0;
    mash.safeTransfer(msg.sender, rewards);
    emit RewardsClaimed(msg.sender, rewards);
  }

  /**
   * @notice This function should increment the proper amount of rewards per mash for the contract
   * @dev IMPORTANT FUNCTION:
   *      - calculation must not overflow with extreme values
   *        (amount <= 1e25) * 1e25 / (balance of vault <= 1e25) -> (extreme values)
   * @param amount amount to add to the rewards
   */
  function addBurnRewards(uint256 amount) external {
    uint vaultBalance = mash.balanceOf(address(Governance.userVault()));
    require(vaultBalance > 0 && (msg.sender == address(Governance) || msg.sender == relayerRegistry), "unauthorized");
    accumulatedRewardPerMash = accumulatedRewardPerMash.add(
      amount.mul(ratioConstant).div(vaultBalance)
    );
  }

  /**
   * @notice This function should allow governance to properly update the accumulated rewards rate for an account
   * @param account address of account to update data for
   * @param amountLockedBeforehand the balance locked beforehand in the governance contract
   * */
  function updateRewardsOnLockedBalanceChange(address account, uint256 amountLockedBeforehand) external onlyGovernance {
    uint256 claimed = _updateReward(account, amountLockedBeforehand);
    accumulatedRewards[account] = accumulatedRewards[account].add(claimed);
  }

  /**
   * @notice This function should allow governance rescue tokens from the staking rewards contract
   * */
  function withdrawMash(uint256 amount) external onlyGovernance {
    if (amount == type(uint256).max) amount = mash.balanceOf(address(this));
    mash.safeTransfer(address(Governance), amount);
  }

  /**
   * @notice This function should calculated the proper amount of rewards attributed to user since the last update
   * @dev IMPORTANT FUNCTION:
   *      - calculation must not overflow with extreme values
   *        (accumulatedReward <= 1e25) * (lockedBeforehand <= 1e25) / 1e25
    *      - result may go to 0, since this implies on 1 MASH locked => accumulatedReward <= 1e7, meaning a very small reward
   * @param account address of account to calculate rewards for
   * @param amountLockedBeforehand the balance locked beforehand in the governance contract
   * @return claimed the rewards attributed to user since the last update
   */
  function _updateReward(address account, uint256 amountLockedBeforehand) private returns (uint256 claimed) {
    if (amountLockedBeforehand != 0)
      claimed = (accumulatedRewardPerMash.sub(accumulatedRewardRateOnLastUpdate[account])).mul(amountLockedBeforehand).div(
        ratioConstant
      );
    accumulatedRewardRateOnLastUpdate[account] = accumulatedRewardPerMash;
    emit RewardsUpdated(account, claimed);
  }

  /**
   * @notice This function should show a user his rewards.
   * @param account address of account to calculate rewards for
   */
  function checkReward(address account) external view returns (uint256 rewards) {
    uint256 amountLocked = Governance.lockedBalance(account);
    if (amountLocked != 0)
      rewards = (accumulatedRewardPerMash.sub(accumulatedRewardRateOnLastUpdate[account])).mul(amountLocked).div(ratioConstant);
    rewards = rewards.add(accumulatedRewards[account]);
  }
}