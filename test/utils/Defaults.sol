// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

/// @notice Contract with default values used throughout the tests.
contract Defaults {
    uint256 public constant REWARD_BUDGET = 1_000_000 ether;
    uint256 public constant EPOCH_REWARD_EMISSION = 1000 ether;
    uint256 public constant EPOCH_DURATION = 1 days;
    uint256 public constant FIRST_EPOCH = 1;
    uint256 public constant PERFORMANCE_SCALE = 1e18;
    uint256 public constant MAX_NODES = 50;
}
