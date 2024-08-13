// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title Timelock
/// @notice A timelock contract with an immutable min delay
/// @author BakersSyndicate
contract Timelock is TimelockController {
    /// @notice The immutable delay period for timelock operations
    uint256 public immutable TIMELOCK_DELAY;

    /// @notice Thrown when an invalid delay is provided in the constructor
    error InvalidDelay();

    /// @notice Thrown when an invalid canceller is provided in the constructor
    error InvalidCanceller();

    /// @notice Thrown when an invalid proposer is provided in the constructor
    error InvalidProposer();

    /// @notice Thrown when an invalid executor is provided in the constructor
    error InvalidExecutor();

    /// @notice Initializes the Timelock contract
    /// @dev Sets up the timelock with a specified delay and initial roles
    /// @param delay The timelock delay in seconds (must be at least 3 days)
    /// @param proposers Array of addresses that can propose new operations
    /// @param executors Array of addresses that can execute operations
    /// @param canceller Address of the canceller role
    constructor(
        uint256 delay,
        address[] memory proposers,
        address[] memory executors,
        address canceller
    )
        TimelockController(delay, proposers, executors, address(0))
    {
        if (delay < 3 days) revert InvalidDelay();
        if (canceller == address(0)) revert InvalidCanceller();
        if (proposers.length == 0) revert InvalidProposer();
        if (executors.length == 0) revert InvalidExecutor();
        _grantRole(CANCELLER_ROLE, canceller);
    }
}
