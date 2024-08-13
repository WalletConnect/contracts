// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25;

/// @notice Contract with default values used throughout the tests.
contract Defaults {
    uint256 public constant EPOCH_REWARD_EMISSION = 1000 ether;
    uint256 public constant REWARD_BUDGET = EPOCH_REWARD_EMISSION * 1000;
    uint256 public constant EPOCH_DURATION = 1 days;
    uint256 public constant FIRST_EPOCH = 1;
    uint256 public constant PERFORMANCE_SCALE = 1e18;
    uint8 public constant MAX_NODES = 50;
    uint256 public constant MIN_STAKE = 100_000 ether;
    uint8 public constant MAX_REGISTRY_NODES = 50;
}
