// SPDX-License-Identifier: MIT

pragma solidity >=0.8.25 <0.9.0;

import { Integration_Test } from "test/integration/Integration.t.sol";
import { StakeWeight } from "src/StakeWeight.sol";

contract ConvertToPermanent_StakeWeight_Unit_Fuzz_Test is Integration_Test {
    function setUp() public override {
        super.setUp();
        disableTransferRestrictions();
    }

    function testFuzz_ConvertToPermanent_TotalSupplyConsistency(
        uint256 amount,
        uint256 initialLockTime,
        uint256 timeElapsed,
        uint256 permanentDurationIndex
    )
        public
    {
        // Bound inputs
        amount = bound(amount, 1e18, 10_000e18);
        initialLockTime = bound(initialLockTime, 1 weeks, 104 weeks); // 1 week to 2 years
        permanentDurationIndex = permanentDurationIndex % 7; // Ensure it's always 0-6 using modulo

        uint256[] memory validDurations = new uint256[](7);
        validDurations[0] = 4 weeks;
        validDurations[1] = 8 weeks;
        validDurations[2] = 12 weeks;
        validDurations[3] = 26 weeks;
        validDurations[4] = 52 weeks;
        validDurations[5] = 78 weeks;
        validDurations[6] = 104 weeks;

        // Create initial decaying lock with rounded end time
        address user = users.alice;
        deal(address(l2wct), user, amount);

        vm.startPrank(user);
        l2wct.approve(address(stakeWeight), amount);
        uint256 lockEnd = ((block.timestamp + initialLockTime) / 1 weeks) * 1 weeks;
        stakeWeight.createLock(amount, lockEnd);

        // Get actual lock details
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(user);
        uint256 actualLockTime = lock.end - block.timestamp;

        // Bound timeElapsed to not exceed actual lock time (avoid expired locks)
        timeElapsed = bound(timeElapsed, 0, actualLockTime > 1 ? actualLockTime - 1 : 0);

        // Skip the test if lock would be expired
        if (actualLockTime == 0) {
            vm.stopPrank();
            return;
        }

        // Record supply before conversion
        uint256 supplyBefore = stakeWeight.totalSupply();
        uint256 balanceBefore = stakeWeight.balanceOf(user);

        // Advance time
        if (timeElapsed > 0) {
            skip(timeElapsed);
        }

        // Calculate remaining time and pick valid duration
        uint256 remainingTime = lock.end - block.timestamp;
        uint256 selectedDuration = validDurations[permanentDurationIndex];

        // Skip if duration is too short for remaining time
        if (selectedDuration < remainingTime) {
            // Pick the shortest valid duration that's >= remaining time
            bool found = false;
            for (uint256 i = 0; i < validDurations.length; i++) {
                if (validDurations[i] >= remainingTime) {
                    selectedDuration = validDurations[i];
                    found = true;
                    break;
                }
            }
            if (!found) {
                selectedDuration = validDurations[6]; // Use max if none found
            }
        }

        // Convert to permanent
        stakeWeight.convertToPermanent(selectedDuration);
        vm.stopPrank();

        // Calculate expected permanent weight
        uint256 expectedWeight = (amount * selectedDuration) / stakeWeight.MAX_LOCK_CAP();

        // Verify conversion
        lock = stakeWeight.locks(user);
        assertEq(stakeWeight.permanentBaseWeeks(user) * 1 weeks, selectedDuration, "Duration should be set");
        assertEq(lock.end, 0, "End time should be cleared for permanent lock");
        assertEq(stakeWeight.permanentOf(user), expectedWeight, "Permanent weight should be correct");

        // Verify supply consistency
        uint256 supplyAfter = stakeWeight.totalSupply();
        uint256 balanceAfter = stakeWeight.balanceOf(user);

        // Balance should be the permanent weight
        assertEq(balanceAfter, expectedWeight, "Balance should equal permanent weight");

        // Total supply should include the permanent weight
        assertGe(supplyAfter, expectedWeight, "Total supply should include permanent weight");
    }

    function testFuzz_ConvertToPermanent_ConversionFrequencyLimit(uint256 attempts) public {
        attempts = bound(attempts, 2, 10);

        // Setup initial lock
        address user = users.alice;
        uint256 amount = 1000e18;
        deal(address(l2wct), user, amount);

        vm.startPrank(user);
        l2wct.approve(address(stakeWeight), amount);
        stakeWeight.createLock(amount, block.timestamp + 52 weeks);

        // First conversion should succeed
        stakeWeight.convertToPermanent(52 weeks);

        // Subsequent attempts should fail because it's already permanent
        for (uint256 i = 1; i < attempts; i++) {
            vm.expectRevert(StakeWeight.AlreadyPermanent.selector);
            stakeWeight.convertToPermanent(104 weeks);
        }

        // Advance to next week - should still fail because it's already permanent
        skip(1 weeks);

        vm.expectRevert(StakeWeight.AlreadyPermanent.selector);
        stakeWeight.convertToPermanent(104 weeks);

        vm.stopPrank();
    }

    function testFuzz_ConvertToPermanent_DurationValidation(uint256 remainingWeeks, uint256 permanentWeeks) public {
        remainingWeeks = bound(remainingWeeks, 1, 104); // 1 to 104 weeks remaining
        permanentWeeks = bound(permanentWeeks, 1, 200); // Test various durations, keep reasonable to avoid overflow

        // Setup lock with specific remaining time - round to week boundaries
        address user = users.alice;
        uint256 amount = 1000e18;
        deal(address(l2wct), user, amount);

        vm.startPrank(user);
        l2wct.approve(address(stakeWeight), amount);
        // Lock end time is rounded to week boundaries in the contract
        uint256 lockEnd = ((block.timestamp + remainingWeeks * 1 weeks) / 1 weeks) * 1 weeks;
        stakeWeight.createLock(amount, lockEnd);

        // Get actual remaining time after rounding
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(user);
        uint256 actualRemainingTime = lock.end - block.timestamp;

        // Check if duration is valid and long enough
        uint256[] memory validDurations = new uint256[](7);
        validDurations[0] = 4 weeks;
        validDurations[1] = 8 weeks;
        validDurations[2] = 12 weeks;
        validDurations[3] = 26 weeks;
        validDurations[4] = 52 weeks;
        validDurations[5] = 78 weeks;
        validDurations[6] = 104 weeks;

        bool isValidDuration = false;
        for (uint256 i = 0; i < validDurations.length; i++) {
            if (permanentWeeks * 1 weeks == validDurations[i]) {
                isValidDuration = true;
                break;
            }
        }

        if (!isValidDuration) {
            // Should revert with invalid duration
            vm.expectRevert(abi.encodeWithSelector(StakeWeight.InvalidDuration.selector, permanentWeeks * 1 weeks));
            stakeWeight.convertToPermanent(permanentWeeks * 1 weeks);
        } else if (permanentWeeks * 1 weeks < actualRemainingTime) {
            // Should revert if duration is too short
            vm.expectRevert(
                abi.encodeWithSelector(
                    StakeWeight.DurationTooShort.selector, permanentWeeks * 1 weeks, actualRemainingTime
                )
            );
            stakeWeight.convertToPermanent(permanentWeeks * 1 weeks);
        } else {
            // Should succeed
            stakeWeight.convertToPermanent(permanentWeeks * 1 weeks);

            // Verify conversion
            lock = stakeWeight.locks(user);
            assertEq(stakeWeight.permanentBaseWeeks(user) * 1 weeks, permanentWeeks * 1 weeks, "Duration should be set");
        }

        vm.stopPrank();
    }

    function testFuzz_ConvertToPermanent_ExpiredLockHandling(uint256 lockDuration, uint256 timeAfterExpiry) public {
        lockDuration = bound(lockDuration, 1 weeks, 52 weeks);
        timeAfterExpiry = bound(timeAfterExpiry, 1, 52 weeks);

        // Create and let lock expire
        address user = users.alice;
        uint256 amount = 1000e18;
        deal(address(l2wct), user, amount);

        vm.startPrank(user);
        l2wct.approve(address(stakeWeight), amount);
        // Locks are rounded to week boundaries
        uint256 lockEnd = ((block.timestamp + lockDuration) / 1 weeks) * 1 weeks;
        stakeWeight.createLock(amount, lockEnd);

        // Get the actual lock end time from the contract
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(user);
        uint256 actualLockEnd = lock.end;
        vm.stopPrank();

        // Advance past expiry
        skip(lockDuration + timeAfterExpiry);

        // Should not be able to convert expired lock - the error will have the actual lock end time
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(StakeWeight.ExpiredLock.selector, block.timestamp, actualLockEnd));
        stakeWeight.convertToPermanent(52 weeks);
    }

    function testFuzz_ConvertToPermanent_WeightCalculationAccuracy(uint256 amount, uint256 durationIndex) public {
        amount = bound(amount, 1e15, 1e26); // Wide range to test precision (max 100M tokens)
        durationIndex = durationIndex % 7; // Ensure it's always 0-6 using modulo

        // Pick a valid duration
        uint256[] memory validDurations = new uint256[](7);
        validDurations[0] = 4 weeks;
        validDurations[1] = 8 weeks;
        validDurations[2] = 12 weeks;
        validDurations[3] = 26 weeks;
        validDurations[4] = 52 weeks;
        validDurations[5] = 78 weeks;
        validDurations[6] = 104 weeks;
        uint256 duration = validDurations[durationIndex];

        // Create initial lock
        address user = users.alice;
        deal(address(l2wct), user, amount);

        vm.startPrank(user);
        l2wct.approve(address(stakeWeight), amount);
        stakeWeight.createLock(amount, block.timestamp + duration);

        // Convert immediately
        stakeWeight.convertToPermanent(duration);
        vm.stopPrank();

        // Verify weight calculation precision
        uint256 expectedWeight = (amount * duration) / stakeWeight.MAX_LOCK_CAP();
        uint256 actualWeight = stakeWeight.permanentOf(user);

        // Allow for rounding down in integer division
        assertLe(actualWeight, expectedWeight, "Weight should not exceed expected");
        assertGe(actualWeight, expectedWeight - 1, "Weight should be within 1 of expected (rounding)");
    }
}
