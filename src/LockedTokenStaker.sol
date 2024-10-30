// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { StakeWeight } from "src/StakeWeight.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";
import {
    MerkleVester,
    Allocation,
    IPostClaimHandler,
    IERC20,
    SafeERC20,
    CalendarUnlockSchedule,
    DistributionState,
    CalendarAllocation
} from "./interfaces/MerkleVester.sol";
import { Pauser } from "./Pauser.sol";

/**
 * @title LockedTokenStaker
 * @author WalletConnect
 * @notice This contract handles staking without token transfer, as the tokens are already locked in the vesting
 * contract. Then on postClaim, it prevents claiming with an active lock in the staking contract.
 */
contract LockedTokenStaker is IPostClaimHandler {
    using SafeERC20 for IERC20;

    // The address of the vester contract that will call this handler
    MerkleVester public immutable vesterContract;

    // The configuration for the WalletConnect system
    WalletConnectConfig public immutable config;

    error InvalidCaller();
    error TerminatedAllocation();
    error CannotClaimWithActiveLock();
    error InsufficientAllocation();
    error Paused();

    /**
     * @notice Constructor to set up the ClaimAndStakeHandler
     * @param vesterContract_ The address of the vester contract
     * @param config_ The configuration for the WalletConnect system
     */
    constructor(MerkleVester vesterContract_, WalletConnectConfig config_) {
        vesterContract = vesterContract_;
        config = config_;
    }

    modifier whenNotPaused() {
        if (Pauser(config.getPauser()).isLockedTokenStakerPaused()) {
            revert Paused();
        }
        _;
    }

    modifier onlyVester() {
        if (msg.sender != address(vesterContract)) {
            revert InvalidCaller();
        }
        _;
    }

    /**
     * @notice Creates a lock for the caller
     * @param amount The amount to lock
     * @param unlockTime The time when the lock expires
     * @param rootIndex The index of the Merkle root
     * @param decodableArgs Encoded arguments for leaf verification
     * @param proof The Merkle proof
     */
    function createLockFor(
        uint256 amount,
        uint256 unlockTime,
        uint32 rootIndex,
        bytes memory decodableArgs,
        bytes32[] calldata proof
    )
        external
        whenNotPaused
    {
        Allocation memory allocation = vesterContract.getLeafJustAllocationData(rootIndex, decodableArgs, proof);
        if (allocation.originalBeneficiary != msg.sender) {
            revert InvalidCaller();
        }

        (, uint32 terminatedTimestamp, uint256 withdrawn,,,) = vesterContract.schedules(allocation.id);
        if (terminatedTimestamp != 0) {
            revert TerminatedAllocation();
        }

        uint256 availableAmount = allocation.totalAllocation - withdrawn;
        if (availableAmount < amount) {
            revert InsufficientAllocation();
        }

        StakeWeight(config.getStakeWeight()).createLockFor(msg.sender, amount, unlockTime);
    }

    /**
     * @notice Increases the lock amount for a given address
     * @dev This function verifies the allocation and increases the lock amount if valid
     * @param amount The amount to increase the lock by
     * @param rootIndex The index of the Merkle root
     * @param decodableArgs Encoded arguments for leaf verification
     * @param proof The Merkle proof
     */
    function increaseLockAmountFor(
        uint256 amount,
        uint32 rootIndex,
        bytes memory decodableArgs,
        bytes32[] calldata proof
    )
        external
        whenNotPaused
    {
        // Verify the allocation using the vester contract
        Allocation memory allocation = vesterContract.getLeafJustAllocationData(rootIndex, decodableArgs, proof);

        // Ensure the caller is the beneficiary
        if (allocation.originalBeneficiary != msg.sender) {
            revert InvalidCaller();
        }

        (, uint32 terminatedTimestamp, uint256 withdrawn,,,) = vesterContract.schedules(allocation.id);
        if (terminatedTimestamp != 0) {
            revert TerminatedAllocation();
        }

        StakeWeight stakeWeight = StakeWeight(config.getStakeWeight());

        // Get the current lock for the address
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(msg.sender);

        // Calculate the new total amount after increase
        uint256 newAmount = uint256(int256(lock.amount)) + amount;

        uint256 availableAmount = allocation.totalAllocation - withdrawn;

        // Check if the new amount exceeds the total available allocation
        if (newAmount > availableAmount) {
            revert InsufficientAllocation();
        }

        // Increase the lock amount in the staking contract
        stakeWeight.increaseLockAmountFor(msg.sender, amount);
    }

    /**
     * @notice Handles the post-claim action: revert if there's an active lock in the staking contract
     * @dev This function should only be called by the vester contract
     * @param claimToken The address of the vesting token being claimed
     * @param amount The amount of vesting tokens claimed
     * @param originalBeneficiary The original owner of the vesting tokens
     * @param withdrawalAddress The current owner of the vesting tokens
     * @param allocationId The ID of the allocation
     * @param extraData Additional data (unused in this implementation)
     */
    function handlePostClaim(
        IERC20 claimToken,
        uint256 amount,
        address originalBeneficiary,
        address withdrawalAddress,
        string memory allocationId,
        bytes memory extraData
    )
        external
        override
        whenNotPaused
        onlyVester
    {
        StakeWeight stakeWeight = StakeWeight(config.getStakeWeight());

        StakeWeight.LockedBalance memory lock = stakeWeight.locks(originalBeneficiary);
        if (lock.amount > 0) {
            if (lock.end > block.timestamp) {
                revert CannotClaimWithActiveLock();
            } else {
                stakeWeight.withdrawAllFor(originalBeneficiary);
            }
        }

        claimToken.safeTransfer(withdrawalAddress, amount);
    }
}
