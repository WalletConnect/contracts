// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { StakeWeight } from "src/StakeWeight.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";
import { IMerkleVester, Allocation, IPostClaimHandler, IERC20, SafeERC20 } from "./interfaces/MerkleVester.sol";
import { Pauser } from "./Pauser.sol";

/**
 * @title LockedTokenStaker
 * @notice This contract handles staking without token transfer, as the tokens are already locked in the vesting
 * contract. Then on postClaim, it prevents
 */
contract LockedTokenStaker is IPostClaimHandler {
    using SafeERC20 for IERC20;

    // The address of the vester contract that will call this handler
    IMerkleVester public immutable vesterContract;

    // The configuration for the WalletConnect system
    WalletConnectConfig public immutable config;

    error InvalidCaller();
    error CannotClaimWithActiveLock();
    error InsufficientAllocation();
    error Paused();

    /**
     * @notice Constructor to set up the ClaimAndStakeHandler
     * @param vesterContract_ The address of the vester contract
     * @param config_ The configuration for the WalletConnect system
     */
    constructor(IMerkleVester vesterContract_, WalletConnectConfig config_) {
        vesterContract = vesterContract_;
        config = config_;
    }

    function createLockFor(
        address for_,
        uint256 amount,
        uint256 unlockTime,
        uint32 rootIndex,
        bytes memory decodableArgs,
        bytes32[] calldata proof
    )
        external
    {
        if (Pauser(config.getPauser()).isLockedTokenStakerPaused()) {
            revert Paused();
        }
        Allocation memory allocation = vesterContract.getLeafJustAllocationData(rootIndex, decodableArgs, proof);
        if (allocation.totalAllocation < amount) {
            revert InsufficientAllocation();
        }
        if (allocation.originalBeneficiary != msg.sender) {
            revert InvalidCaller();
        }
        StakeWeight(config.getStakeWeight()).createLockFor(for_, amount, unlockTime);
    }

    /**
     * @notice Increases the lock amount for a given address
     * @dev This function verifies the allocation and increases the lock amount if valid
     * @param for_ The address for which to increase the lock amount
     * @param amount The amount to increase the lock by
     * @param rootIndex The index of the Merkle root
     * @param decodableArgs Encoded arguments for leaf verification
     * @param proof The Merkle proof
     */
    function increaseLockAmountFor(
        address for_,
        uint256 amount,
        uint32 rootIndex,
        bytes memory decodableArgs,
        bytes32[] calldata proof
    )
        external
    {
        if (Pauser(config.getPauser()).isLockedTokenStakerPaused()) {
            revert Paused();
        }
        // Verify the allocation using the vester contract
        Allocation memory allocation = vesterContract.getLeafJustAllocationData(rootIndex, decodableArgs, proof);

        // Ensure the caller is the beneficiary
        if (allocation.originalBeneficiary != msg.sender) {
            revert InvalidCaller();
        }

        StakeWeight stakeWeight = StakeWeight(config.getStakeWeight());

        // Get the current lock for the address
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(for_);

        // Calculate the new total amount after increase
        uint256 newAmount = uint256(int256(lock.amount)) + amount;

        // Check if the new amount exceeds the total allocation
        if (newAmount > allocation.totalAllocation) {
            revert InsufficientAllocation();
        }

        // Increase the lock amount in the staking contract
        stakeWeight.increaseLockAmountFor(for_, amount);
    }

    function increaseUnlockTimeFor(address for_, uint256 newUnlockTime) external {
        if (Pauser(config.getPauser()).isLockedTokenStakerPaused()) {
            revert Paused();
        }

        // Ensure the caller is the beneficiary
        if (for_ != msg.sender) {
            revert InvalidCaller();
        }

        StakeWeight(config.getStakeWeight()).increaseUnlockTimeFor(for_, newUnlockTime);
    }

    function withdrawAllFor(address for_) external {
        if (Pauser(config.getPauser()).isLockedTokenStakerPaused()) {
            revert Paused();
        }

        if (for_ != msg.sender) {
            revert InvalidCaller();
        }

        StakeWeight(config.getStakeWeight()).withdrawAllFor(for_);
    }

    /**
     * @notice Handles the post-claim action: revert if there's an active lock in the staking contract
     * @dev This function should only be called by the vester contract
     * @param claimToken The address of the vesting token being claimed
     * @param amount The amount of vesting tokens claimed
     * @param originalBeneficiary The original owner of the vesting tokens
     * @param withdrawalAddress The current owner of the vesting tokens
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
    {
        if (Pauser(config.getPauser()).isLockedTokenStakerPaused()) {
            revert Paused();
        }

        if (msg.sender != address(vesterContract)) {
            revert InvalidCaller();
        }

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
