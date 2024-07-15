// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Reward Calculator Contract
/// @notice Calculates rewards for the BakersSyndicate staking system
/// @author BakersSyndicate
contract RewardCalculator {
    /// @notice Calculates the reward rate
    /// @param bMax The maximum reward rate
    /// @param bMin The minimum reward rate
    /// @param k The kink parameter
    /// @param p The power parameter
    /// @param totalStaked The total amount of tokens staked
    /// @param circulatingSupply The circulating supply of tokens
    /// @return The calculated reward rate
    function calculateRewardRate(
        uint256 bMax,
        uint256 bMin,
        uint256 k,
        uint256 p,
        uint256 totalStaked,
        uint256 circulatingSupply
    )
        external
        pure
        returns (uint256)
    {
        uint256 stakeRatio = (totalStaked * 1e18) / circulatingSupply;
        uint256 cappedStakeRatio = stakeRatio > k ? k : stakeRatio;

        uint256 rewardRate = ((bMax - bMin) * cappedStakeRatio / k + bMin) * 1e18 / 10_000;

        if (p != 1) {
            rewardRate = (rewardRate ** p) / (1e18 ** (p - 1));
        }

        return rewardRate;
    }

    /// @notice Calculates the reward per token
    /// @param rewardRate The current reward rate
    /// @param lastUpdateTime The timestamp of the last update
    /// @param totalStakeWeight The total stake weight
    /// @return The calculated reward per token
    function calculateRewardPerToken(
        uint256 rewardRate,
        uint256 lastUpdateTime,
        uint256 totalStakeWeight
    )
        external
        view
        returns (uint256)
    {
        if (totalStakeWeight == 0) {
            return 0;
        }
        return (rewardRate * (block.timestamp - lastUpdateTime) * 1e18) / totalStakeWeight;
    }

    /// @notice Calculates the earned rewards for an account
    /// @param account The address of the account
    /// @param stakeWeight The stake weight of the account
    /// @param rewardPerToken The current reward per token
    /// @param lastRewardCalculationTime The timestamp of the last reward calculation
    /// @param accumulatedRewards The accumulated rewards so far
    /// @return The total earned rewards
    function calculateEarned(
        address account,
        uint256 stakeWeight,
        uint256 rewardPerToken,
        uint256 lastRewardCalculationTime,
        uint256 accumulatedRewards
    )
        external
        pure
        returns (uint256)
    {
        return accumulatedRewards + (stakeWeight * (rewardPerToken - lastRewardCalculationTime) / 1e18);
    }

    function calculateStakeWeight(
        address user,
        uint256 stakeAmount,
        uint40 lockEndTime,
        uint256 totalStaked
    )
        external
        view
        returns (uint256)
    {
        uint256 oneWeekLockEndTime = block.timestamp + 1 weeks;
        if (lockEndTime < oneWeekLockEndTime) {
            return stakeAmount * 1;
        }
        return stakeAmount;
    }

    /// @notice Gets the circulating supply of tokens
    /// @return The circulating supply
    function getCirculatingSupply() external view returns (uint256) {
        // Implementation depends on how circulating supply is tracked
        // This is a placeholder
        return 1_000_000_000 * 1e18;
    }
}
