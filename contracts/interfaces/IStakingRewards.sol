// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

interface IStakingRewards {
    function updateRewardsOnLockedBalanceChange(address account, uint256 amountLockedBeforehand) external;
} 