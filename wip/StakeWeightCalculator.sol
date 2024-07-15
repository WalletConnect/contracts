// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { StakingStorage } from "./StakingStorage.sol";

/// @title Stake Weight Calculator Contract
/// @notice Calculates stake weights for the BakersSyndicate staking system
/// @author BakersSyndicate
contract StakeWeightCalculator is StakingStorage {
    /// @notice Calculates the stake weight for a user
    /// @param user The address of the user
    /// @param stakeAmount The amount of tokens staked by the user
    /// @param lockEndTime The timestamp when the stake lock ends
    /// @param totalStaked The total amount of tokens staked in the system
    /// @return The calculated stake weight
    function calculateStakeWeight(
        address user,
        uint256 stakeAmount,
        uint256 lockEndTime,
        uint256 totalStaked
    )
        external
        view
        returns (uint256)
    {
        if (block.timestamp >= lockEndTime || stakeAmount == 0) {
            return 0;
        }

        uint256 lockDuration = lockEndTime - block.timestamp;
        uint256 boostFactor = ((lockDuration * (MAX_BOOST_FACTOR - 1e18)) / MAX_LOCK_DURATION) + 1e18;
        uint256 stakeWeight = (stakeAmount * boostFactor) / 1e18;

        uint256 cappedStakeWeight = (totalStaked * STAKE_WEIGHT_CAP) / 100;
        return stakeWeight > cappedStakeWeight ? cappedStakeWeight : stakeWeight;
    }
}
