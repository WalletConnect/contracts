// SPDX-License-Identifier: MIT

pragma solidity >=0.8.25 <0.9.0;

import { Integration_Test } from "test/integration/Integration.t.sol";
import { StakeWeight } from "src/StakeWeight.sol";

contract CreatePermanentLock_StakeWeight_Unit_Fuzz_Test is Integration_Test {
    function setUp() public override {
        super.setUp();
        disableTransferRestrictions();
    }

    function testFuzz_CreatePermanentLock_WeightCalculation(uint256 amount, uint256 durationIndex) public {
        // Bound inputs
        amount = bound(amount, 1e18, 10_000e18); // 1 to 10,000 tokens
        durationIndex = durationIndex % 7; // Ensure it's always 0-6 using modulo

        // Valid durations per StakeWeight._isValidDuration
        uint256[] memory validDurations = new uint256[](7);
        validDurations[0] = 4 weeks;
        validDurations[1] = 8 weeks;
        validDurations[2] = 12 weeks;
        validDurations[3] = 26 weeks;
        validDurations[4] = 52 weeks;
        validDurations[5] = 78 weeks;
        validDurations[6] = 104 weeks;

        uint256 duration = validDurations[durationIndex];

        // Setup
        address user = users.alice;
        deal(address(l2wct), user, amount);

        // Execute
        vm.startPrank(user);
        l2wct.approve(address(stakeWeight), amount);
        stakeWeight.createPermanentLock(amount, duration);
        vm.stopPrank();

        // Verify weight calculation
        uint256 expectedWeight = (amount * duration) / stakeWeight.MAX_LOCK_CAP();
        assertEq(
            stakeWeight.permanentOf(user), expectedWeight, "Weight should equal (amount * duration) / MAX_LOCK_CAP"
        );

        // Verify lock state
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(user);
        assertEq(uint256(int256(lock.amount)), amount, "Lock amount should match");
        assertEq(stakeWeight.permanentBaseWeeks(user) * 1 weeks, duration, "Duration should match");
        assertEq(lock.end, 0, "Permanent locks should have no end time");

        // Verify balance
        uint256 balance = stakeWeight.balanceOf(user);
        assertEq(balance, expectedWeight, "Balance should equal permanent weight");

        // Verify total supply includes permanent weight
        uint256 totalSupply = stakeWeight.totalSupply();
        assertGe(totalSupply, expectedWeight, "Total supply should include permanent weight");
    }

    function testFuzz_CreatePermanentLock_DurationBoundaries(uint256 amount, uint256 invalidWeeks) public {
        amount = bound(amount, 1e18, 10_000e18);

        // Generate invalid durations that are NOT in the valid set
        // Valid durations are: 4, 8, 12, 26, 52, 78, 104 weeks
        // So we'll test with durations that are definitely invalid
        invalidWeeks = bound(invalidWeeks, 1, 200);

        // Skip if it's a valid duration
        if (
            invalidWeeks == 4 || invalidWeeks == 8 || invalidWeeks == 12 || invalidWeeks == 26 || invalidWeeks == 52
                || invalidWeeks == 78 || invalidWeeks == 104
        ) {
            return; // Skip valid durations
        }

        uint256 invalidDuration = invalidWeeks * 1 weeks;

        address user = users.alice;
        deal(address(l2wct), user, amount);

        vm.startPrank(user);
        l2wct.approve(address(stakeWeight), amount);

        // Should revert with invalid duration
        vm.expectRevert(abi.encodeWithSelector(StakeWeight.InvalidDuration.selector, invalidDuration));
        stakeWeight.createPermanentLock(amount, invalidDuration);
        vm.stopPrank();
    }

    function testFuzz_CreatePermanentLock_AmountBoundaries(uint256 zeroAmount, uint256 duration) public {
        zeroAmount = 0;
        duration = 52 weeks; // Valid 1 year duration

        address user = users.alice;

        vm.startPrank(user);

        // Should revert with zero amount
        vm.expectRevert(abi.encodeWithSelector(StakeWeight.InvalidAmount.selector, zeroAmount));
        stakeWeight.createPermanentLock(zeroAmount, duration);
        vm.stopPrank();
    }

    function testFuzz_CreatePermanentLock_MultipleUsers(uint256 seed) public {
        // Create permanent locks for multiple users with different parameters
        uint256 numUsers = bound(seed % 10, 2, 10);

        uint256[] memory validDurations = new uint256[](7);
        validDurations[0] = 4 weeks;
        validDurations[1] = 8 weeks;
        validDurations[2] = 12 weeks;
        validDurations[3] = 26 weeks;
        validDurations[4] = 52 weeks;
        validDurations[5] = 78 weeks;
        validDurations[6] = 104 weeks;

        uint256 totalPermanentSupply = 0;

        for (uint256 i = 0; i < numUsers; i++) {
            address user = address(uint160(uint256(keccak256(abi.encodePacked(seed, i)))));
            uint256 amount = bound(uint256(keccak256(abi.encodePacked(seed, i, "amount"))), 1e18, 1000e18);
            uint256 durationIndex = uint256(keccak256(abi.encodePacked(seed, i, "duration"))) % 7;
            uint256 duration = validDurations[durationIndex];

            deal(address(l2wct), user, amount);

            vm.startPrank(user);
            l2wct.approve(address(stakeWeight), amount);
            stakeWeight.createPermanentLock(amount, duration);
            vm.stopPrank();

            uint256 expectedWeight = (amount * duration) / stakeWeight.MAX_LOCK_CAP();
            totalPermanentSupply += expectedWeight;
        }

        // Verify total permanent supply
        assertEq(
            stakeWeight.permanentSupply(), totalPermanentSupply, "Total permanent supply should match sum of weights"
        );
    }

    function testFuzz_CreatePermanentLock_MaxAmountMaxDuration(uint256 multiplier) public {
        // Test with very large amounts and max duration
        multiplier = bound(multiplier, 1, 100);
        uint256 amount = multiplier * 1e24; // Large amount
        uint256 duration = 104 weeks; // Max duration (2 years)

        address user = users.alice;
        deal(address(l2wct), user, amount);

        vm.startPrank(user);
        l2wct.approve(address(stakeWeight), amount);
        stakeWeight.createPermanentLock(amount, duration);
        vm.stopPrank();

        // Verify calculation doesn't overflow
        uint128 expectedWeight = uint128((amount * duration) / stakeWeight.MAX_LOCK_CAP());
        assertEq(stakeWeight.permanentOf(user), expectedWeight, "Weight calculation should handle large values");

        // Verify permanentSupply is updated correctly
        assertEq(stakeWeight.permanentSupply(), expectedWeight, "Permanent supply should match weight");
    }
}
