// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25;

/// @notice Contract with default values used throughout the tests.
contract Defaults {
    uint256 public constant SECONDS_PER_BLOCK = 2;
    uint256 public constant ONE_WEEK_IN_BLOCKS = 1 weeks / SECONDS_PER_BLOCK;
    // NodeRewardManager
    uint256 public constant EPOCH_REWARD_EMISSION = 1000 ether;
    uint256 public constant REWARD_BUDGET = EPOCH_REWARD_EMISSION * 1000;
    uint256 public constant EPOCH_DURATION = 1 days;
    uint256 public constant FIRST_EPOCH = 1;
    uint256 public constant PERFORMANCE_SCALE = 1e18;
    uint8 public constant MAX_NODES = 50;
    uint8 public constant MAX_REGISTRY_NODES = 50;
    uint256 public constant MIN_STAKE = 100_000 ether;
    // Staking Rewards
    uint256 public constant STAKING_REWARD_DURATION = 2 * 365 days;
    uint256 public constant STAKING_REWARD_RATE = 5.4e27; // 1875000 ether / 30 days
    uint256 public constant STAKING_REWARD_BUDGET = STAKING_REWARD_DURATION * STAKING_REWARD_RATE;
    // Airdrop
    uint256 public constant AIRDROP_BUDGET = 1_000_000 ether;
}
