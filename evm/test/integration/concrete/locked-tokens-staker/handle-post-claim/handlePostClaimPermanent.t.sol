// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { LockedTokenStaker_Integration_Shared_Test } from "test/integration/shared/LockedTokenStaker.t.sol";
import { LockedTokenStaker } from "src/LockedTokenStaker.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IPostClaimHandler, IERC20 } from "src/utils/magna/MerkleVester.sol";

/**
 * @title HandlePostClaimPermanent_LockedTokenStaker_Integration_Concrete_Test
 * @notice Test that permanent locks properly prevent vesting bypass
 * @dev Critical security test to ensure permanent locks don't allow early withdrawal
 */
contract HandlePostClaimPermanent_LockedTokenStaker_Integration_Concrete_Test is
    LockedTokenStaker_Integration_Shared_Test
{
    uint256 constant LOCK_AMOUNT = 100 ether;
    uint256 constant LOCK_DURATION = 52 weeks;
    uint256 constant CLAIM_AMOUNT = 50 ether;
    bytes decodableArgs;
    bytes32[] proof;

    IPostClaimHandler postClaimHandler;

    function setUp() public override {
        super.setUp();
        (decodableArgs, proof) = _createAllocation(users.alice, LOCK_AMOUNT);

        skip(90 days); // Fast forward to allow vesting
        postClaimHandler = IPostClaimHandler(address(lockedTokenStaker));

        vm.startPrank(users.admin);
        vester.addPostClaimHandlerToWhitelist(postClaimHandler);
        vm.stopPrank();
    }

    /**
     * @notice Test that converting to permanent lock prevents vesting bypass
     * @dev This is the CRITICAL security test - permanent locks must respect vesting
     */
    function test_RevertGiven_PermanentLockCannotBypassVesting() external {
        // Create initial lock for the user
        _createLockForUser(users.alice, LOCK_AMOUNT, block.timestamp + LOCK_DURATION, decodableArgs, proof);

        // Convert to permanent lock
        vm.prank(users.alice);
        stakeWeight.convertToPermanent(52 weeks);

        // Verify the lock is now permanent (end == 0)
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(users.alice);
        assertEq(lock.end, 0, "Lock should be permanent with end == 0");
        assertGt(lock.amount, 0, "Lock should have amount");

        // Attempt to claim vested tokens - should be blocked
        bytes memory extraData = abi.encode(uint32(0), decodableArgs, proof);

        // The permanent lock should be treated as active, preventing excessive claims
        vm.expectRevert(
            abi.encodeWithSelector(
                LockedTokenStaker.CannotClaimLockedTokens.selector,
                LOCK_AMOUNT, // remainingAllocation
                LOCK_AMOUNT, // lockedAmount
                LOCK_AMOUNT // claimAmount attempting
            )
        );

        vm.prank(users.alice);
        vester.withdraw(
            LOCK_AMOUNT, // Try to withdraw full allocation
            0, // rootIndex
            decodableArgs,
            proof,
            postClaimHandler,
            extraData
        );
    }

    /**
     * @notice Test that permanent locks allow partial claims up to available amount
     * @dev Permanent locks should behave like active locks for vesting purposes
     */
    function test_GivenPermanentLockAllowsPartialClaims() external {
        uint256 lockAmount = LOCK_AMOUNT / 2; // Lock only half
        uint256 claimableAmount = LOCK_AMOUNT - lockAmount; // Other half is claimable

        // Create initial lock for half the allocation
        _createLockForUser(users.alice, lockAmount, block.timestamp + LOCK_DURATION, decodableArgs, proof);

        // Convert to permanent lock
        vm.prank(users.alice);
        stakeWeight.convertToPermanent(52 weeks);

        // Verify permanent lock status
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(users.alice);
        assertEq(lock.end, 0, "Should be permanent");

        bytes memory extraData = abi.encode(uint32(0), decodableArgs, proof);

        uint256 initialBalance = l2wct.balanceOf(users.alice);

        // Should be able to claim the unlocked portion
        vm.prank(users.alice);
        vester.withdraw(claimableAmount, 0, decodableArgs, proof, postClaimHandler, extraData);

        assertEq(l2wct.balanceOf(users.alice), initialBalance + claimableAmount, "Should receive claimable amount");

        // But still cannot claim the locked portion
        vm.expectRevert(
            abi.encodeWithSelector(
                LockedTokenStaker.CannotClaimLockedTokens.selector,
                lockAmount, // remainingAllocation
                lockAmount, // lockedAmount
                lockAmount // claimAmount attempting
            )
        );

        vm.prank(users.alice);
        vester.withdraw(
            lockAmount, // Try to claim locked portion
            0,
            decodableArgs,
            proof,
            postClaimHandler,
            extraData
        );
    }

    /**
     * @notice Test that triggering unlock allows eventual withdrawal
     * @dev After triggering unlock, user must wait for decay period
     */
    function test_GivenPermanentCanUnlockAndEventuallyWithdraw() external {
        // Create and convert to permanent
        _createLockForUser(users.alice, LOCK_AMOUNT, block.timestamp + LOCK_DURATION, decodableArgs, proof);

        vm.prank(users.alice);
        stakeWeight.convertToPermanent(52 weeks);

        // Trigger unlock to start decay
        vm.prank(users.alice);
        stakeWeight.triggerUnlock();

        // Check lock is no longer permanent but still active
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(users.alice);
        assertGt(lock.end, block.timestamp, "Should have future end time");

        bytes memory extraData = abi.encode(uint32(0), decodableArgs, proof);

        // Still cannot claim while lock is active
        vm.expectRevert(
            abi.encodeWithSelector(
                LockedTokenStaker.CannotClaimLockedTokens.selector, LOCK_AMOUNT, LOCK_AMOUNT, LOCK_AMOUNT
            )
        );

        vm.prank(users.alice);
        vester.withdraw(LOCK_AMOUNT, 0, decodableArgs, proof, postClaimHandler, extraData);

        // Fast forward past lock expiry
        vm.warp(lock.end + 1);

        uint256 initialBalance = l2wct.balanceOf(users.alice);

        // Now can claim after lock expired
        vm.prank(users.alice);
        vester.withdraw(LOCK_AMOUNT, 0, decodableArgs, proof, postClaimHandler, extraData);

        assertEq(l2wct.balanceOf(users.alice), initialBalance + LOCK_AMOUNT, "Should receive full amount after unlock");

        // Verify stake was withdrawn
        lock = stakeWeight.locks(users.alice);
        assertEq(lock.amount, 0, "Stake should be withdrawn");
    }

    /**
     * @notice Test that permanent locks with 52-week duration prevent vesting
     * @dev Permanent locks should be treated as active regardless of baseWeeks
     */
    function test_GivenPermanentDurationPreventsVesting() external {
        // Test with 104-week permanent lock
        uint256 duration = 104 weeks;

        // Create lock with sufficient duration for the conversion
        _createLockForUser(users.alice, LOCK_AMOUNT, block.timestamp + 104 weeks, decodableArgs, proof);

        // Convert to permanent
        vm.prank(users.alice);
        stakeWeight.convertToPermanent(duration);

        // Verify permanent lock prevents vesting bypass
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(users.alice);
        assertEq(lock.end, 0, "Should be permanent");
        assertEq(stakeWeight.permanentBaseWeeks(users.alice), 104, "Should have 104 base weeks");

        bytes memory extraData = abi.encode(uint32(0), decodableArgs, proof);

        // Permanent lock should prevent claiming locked amount
        vm.expectRevert(
            abi.encodeWithSelector(
                LockedTokenStaker.CannotClaimLockedTokens.selector, LOCK_AMOUNT, LOCK_AMOUNT, LOCK_AMOUNT
            )
        );

        vm.prank(users.alice);
        vester.withdraw(LOCK_AMOUNT, 0, decodableArgs, proof, postClaimHandler, extraData);
    }
}
