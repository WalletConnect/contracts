// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakeWeight } from "src/StakeWeight.sol";
import { StakeWeight_Integration_Shared_Test } from "test/integration/shared/StakeWeight.t.sol";

contract TotalSupplyAtTime_StakeWeight_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    function setUp() public override {
        super.setUp();
        vm.prank(users.admin);
        l2wct.disableTransferRestrictions();
    }

    function test_WhenQueryingSupplyAtTimeBeforeAnyLocks() external {
        assertEq(stakeWeight.totalSupplyAtTime(block.timestamp), 0, "Total supply should be zero before any locks");
        // Underflow
        vm.expectRevert();
        stakeWeight.totalSupplyAtTime(block.timestamp - 1);
    }

    function test_WhenQueryingSupplyAtCurrentTime() external {
        uint256 amount = 100e18;
        uint256 lockDuration = 1 weeks;
        _createLockForUser(users.alice, amount, block.timestamp + lockDuration);

        assertEq(
            stakeWeight.totalSupplyAtTime(block.timestamp),
            stakeWeight.totalSupply(),
            "Total supply at current time should match regular totalSupply"
        );
    }

    function test_WhenQueryingSupplyAtTimeWithActiveLocks() external {
        uint256 aliceAmount = 100e18;
        uint256 bobAmount = 200e18;
        uint256 lockDuration1 = 1 weeks;
        uint256 lockDuration2 = 2 weeks;

        _createLockForUser(users.alice, aliceAmount, block.timestamp + lockDuration1);
        _createLockForUser(users.bob, bobAmount, block.timestamp + lockDuration2);

        uint256 queryTime = block.timestamp + 3 days;
        uint256 supplyAtTime = stakeWeight.totalSupplyAtTime(queryTime);

        assertGt(supplyAtTime, 0, "Supply at time should be greater than zero");
        assertLe(
            supplyAtTime,
            stakeWeight.totalSupply(),
            "Supply at time should be less than or equal to current totalSupply"
        );
    }

    function test_WhenQueryingSupplyAtTimeAfterSomeLocksHaveExpired() external {
        uint256 aliceAmount = 100e18;
        uint256 bobAmount = 200e18;
        uint256 lockDuration1 = 1 weeks;
        uint256 lockDuration2 = 2 weeks;

        _createLockForUser(users.alice, aliceAmount, block.timestamp + lockDuration1);
        _createLockForUser(users.bob, bobAmount, block.timestamp + lockDuration2);

        uint256 initialSupply = stakeWeight.totalSupply();
        uint256 queryTime = block.timestamp + lockDuration1 + 1 days;

        uint256 supplyAtTime = stakeWeight.totalSupplyAtTime(queryTime);

        assertLt(supplyAtTime, initialSupply, "Supply at time should be less than the original totalSupply");
    }

    function test_WhenQueryingSupplyAtTimeAfterAllLocksHaveExpired() external {
        uint256 amount1 = 100e18;
        uint256 amount2 = 200e18;
        uint256 lockDuration = 1 weeks;

        _createLockForUser(users.alice, amount1, block.timestamp + lockDuration);
        _createLockForUser(users.bob, amount2, block.timestamp + lockDuration);

        uint256 queryTime = block.timestamp + lockDuration + 1 days;

        assertEq(
            stakeWeight.totalSupplyAtTime(queryTime), 0, "Total supply should be zero after all locks have expired"
        );
    }

    function test_WhenLocksHaveDifferentDurations() external {
        uint256 aliceAmount = 100e18;
        uint256 bobAmount = 200e18;
        uint256 lockDuration1 = 1 weeks;
        uint256 lockDuration2 = 4 weeks;

        _createLockForUser(users.alice, aliceAmount, block.timestamp + lockDuration1);
        _createLockForUser(users.bob, bobAmount, block.timestamp + lockDuration2);

        uint256 queryTime = block.timestamp + 2 weeks;
        uint256 supplyAtTime = stakeWeight.totalSupplyAtTime(queryTime);

        assertGt(supplyAtTime, 0, "Supply at time should be greater than zero");
        assertLt(supplyAtTime, stakeWeight.totalSupply(), "Supply at time should be less than current totalSupply");
    }

    function test_WhenQueryingSupplyIntoFuture() external {
        // Create various locks at different times
        uint256 initialTime = block.timestamp;
        _createLockForUser(users.alice, 100e18, initialTime + 1 weeks);
        _createLockForUser(users.bob, 200e18, initialTime + 2 weeks);
        _createLockForUser(users.carol, 300e18, initialTime + 3 weeks);

        uint256 lastSupply = stakeWeight.totalSupply();
        for (uint256 i = 1; i <= 4; i++) {
            uint256 queryTime = initialTime + i * 1 weeks;
            uint256 supplyAtTime = stakeWeight.totalSupplyAtTime(queryTime);
            assertLe(supplyAtTime, lastSupply, "Supply at time should be less than or equal to initial supply");
            lastSupply = supplyAtTime;
        }

        assertGt(
            stakeWeight.totalSupplyAtTime(initialTime + 2 weeks + 5 days), 0, "Supply before 3 weeks should be > 0"
        );
        assertEq(stakeWeight.totalSupplyAtTime(initialTime + 3 weeks), 0, "Supply at 3 weeks should be 0");
    }

    function test_WhenQueryingSupplyBackwardsAfterWarping() external {
        // Set initial time and create locks
        uint256 initialTime = block.timestamp;

        _createLockForUser(users.alice, 100e18, initialTime + 1 weeks);
        _createLockForUser(users.bob, 200e18, initialTime + 2 weeks);
        _createLockForUser(users.carol, 300e18, initialTime + 3 weeks);

        uint256 initialSupply = stakeWeight.totalSupply();

        // Warp 3 weeks into the future
        vm.warp(initialTime + 3 weeks);

        uint256 lastSupply;
        for (uint256 i = 0; i < 4; i++) {
            uint256 queryTime = initialTime + (3 - i) * 1 weeks;
            uint256 supplyAtTime = stakeWeight.totalSupplyAtTime(queryTime);

            if (i > 0) {
                assertGt(supplyAtTime, lastSupply, "Supply at time should increase as we query backwards");
            } else {
                assertEq(supplyAtTime, lastSupply, "Supply at time should be equal to last supply");
            }

            lastSupply = supplyAtTime;
        }

        assertEq(
            stakeWeight.totalSupplyAtTime(initialTime),
            initialSupply,
            "Supply at initial time should be the same we got at that time"
        );
        assertEq(stakeWeight.totalSupplyAtTime(block.timestamp + 1), 0, "Supply at 1 second after expiries should be 0");
    }

    modifier whenQueryingSupplyAtTimeWithPermanentLocks() {
        _;
    }

    function test_WhenQueryingSupplyAtTimeWithPermanentLocks() external whenQueryingSupplyAtTimeWithPermanentLocks {
        // Setup: Create a permanent lock
        uint256 amount = 1000e18;
        uint256 duration = 52 weeks; // 1 year permanent lock

        vm.startPrank(users.alice);
        deal(address(l2wct), users.alice, amount);
        l2wct.approve(address(stakeWeight), amount);
        stakeWeight.createPermanentLock(amount, duration);
        vm.stopPrank();

        // Get the permanent weight
        uint256 permanentWeight = stakeWeight.permanentOf(users.alice);
        assertGt(permanentWeight, 0, "Permanent weight should be greater than 0");

        // Test that totalSupply and totalSupplyAtTime(block.timestamp) are equal
        uint256 totalSupply = stakeWeight.totalSupply();
        uint256 totalSupplyAtCurrentTime = stakeWeight.totalSupplyAtTime(block.timestamp);

        assertEq(
            totalSupply,
            totalSupplyAtCurrentTime,
            "totalSupply() should equal totalSupplyAtTime(block.timestamp) with permanent locks"
        );

        // Test that the supply includes permanent weight correctly (not double-counted)
        assertEq(
            totalSupply, permanentWeight, "Total supply should equal permanent weight when only permanent locks exist"
        );
    }

    function test_WhenQueryingSupplyAtTimeWithPermanentLocks_NotDecayOverTime()
        external
        whenQueryingSupplyAtTimeWithPermanentLocks
    {
        // Setup: Create a permanent lock
        uint256 amount = 1000e18;
        uint256 duration = 52 weeks;

        vm.startPrank(users.alice);
        deal(address(l2wct), users.alice, amount);
        l2wct.approve(address(stakeWeight), amount);
        stakeWeight.createPermanentLock(amount, duration);
        vm.stopPrank();

        uint256 initialSupply = stakeWeight.totalSupply();

        // Warp time forward
        vm.warp(block.timestamp + 26 weeks);

        // Permanent locks should not decay
        uint256 supplyAfterWarp = stakeWeight.totalSupply();
        uint256 supplyAtTimeAfterWarp = stakeWeight.totalSupplyAtTime(block.timestamp);

        assertEq(initialSupply, supplyAfterWarp, "Permanent lock supply should not decay over time");

        assertEq(
            supplyAfterWarp,
            supplyAtTimeAfterWarp,
            "totalSupply() should equal totalSupplyAtTime(block.timestamp) after time warp"
        );
    }

    modifier whenQueryingSupplyAtTimeAfterConversionToPermanent() {
        _;
    }

    function test_WhenQueryingSupplyAtTimeAfterConversionToPermanent_ShowsDecayingWeightBefore()
        external
        whenQueryingSupplyAtTimeAfterConversionToPermanent
    {
        // Create a regular lock first
        uint256 amount = 1000e18;
        uint256 lockDuration = 52 weeks;

        vm.startPrank(users.alice);
        deal(address(l2wct), users.alice, amount);
        l2wct.approve(address(stakeWeight), amount);
        stakeWeight.createLock(amount, block.timestamp + lockDuration);
        vm.stopPrank();

        // Get supply before conversion
        uint256 supplyBeforeConversion = stakeWeight.totalSupply();

        // Warp forward a bit to see decay
        vm.warp(block.timestamp + 4 weeks);
        uint256 decayedSupply = stakeWeight.totalSupply();
        assertLt(decayedSupply, supplyBeforeConversion, "Regular lock should decay over time");

        // Query historical supply (should show decaying weight)
        uint256 historicalSupply = stakeWeight.totalSupplyAtTime(block.timestamp - 2 weeks);
        assertGt(historicalSupply, decayedSupply, "Historical supply should be higher than current decayed supply");
    }

    function test_WhenQueryingSupplyAtTimeAfterConversionToPermanent_ShowsConstantWeightAfter()
        external
        whenQueryingSupplyAtTimeAfterConversionToPermanent
    {
        // Create a regular lock
        uint256 amount = 1000e18;
        uint256 lockDuration = 52 weeks;

        vm.startPrank(users.alice);
        deal(address(l2wct), users.alice, amount);
        l2wct.approve(address(stakeWeight), amount);
        stakeWeight.createLock(amount, block.timestamp + lockDuration);

        // Convert to permanent
        stakeWeight.convertToPermanent(52 weeks);
        vm.stopPrank();

        uint256 supplyAfterConversion = stakeWeight.totalSupply();

        // Warp forward and check supply remains constant
        vm.warp(block.timestamp + 26 weeks);
        uint256 supplyLater = stakeWeight.totalSupply();

        assertEq(supplyAfterConversion, supplyLater, "Permanent lock supply should remain constant after conversion");

        // Verify totalSupplyAtTime matches
        assertEq(
            supplyLater,
            stakeWeight.totalSupplyAtTime(block.timestamp),
            "totalSupply() should equal totalSupplyAtTime(block.timestamp) for permanent locks"
        );
    }

    function test_MixedPermanentAndRegularLocks_SupplyConsistency() external {
        // Create a regular lock
        uint256 regularAmount = 500e18;
        uint256 regularDuration = 26 weeks;

        vm.startPrank(users.alice);
        deal(address(l2wct), users.alice, regularAmount);
        l2wct.approve(address(stakeWeight), regularAmount);
        stakeWeight.createLock(regularAmount, block.timestamp + regularDuration);
        vm.stopPrank();

        // Create a permanent lock
        uint256 permanentAmount = 1000e18;
        uint256 permanentDuration = 52 weeks;

        vm.startPrank(users.bob);
        deal(address(l2wct), users.bob, permanentAmount);
        l2wct.approve(address(stakeWeight), permanentAmount);
        stakeWeight.createPermanentLock(permanentAmount, permanentDuration);
        vm.stopPrank();

        // Verify consistency at current time
        uint256 totalSupply = stakeWeight.totalSupply();
        uint256 totalSupplyAtNow = stakeWeight.totalSupplyAtTime(block.timestamp);

        assertEq(
            totalSupply,
            totalSupplyAtNow,
            "With mixed locks, totalSupply() should equal totalSupplyAtTime(block.timestamp)"
        );

        // Verify sum of individual balances equals total supply
        uint256 aliceBalance = stakeWeight.balanceOf(users.alice);
        uint256 bobBalance = stakeWeight.balanceOf(users.bob);
        uint256 sumOfBalances = aliceBalance + bobBalance;

        assertEq(totalSupply, sumOfBalances, "Total supply should equal sum of all individual balances");

        // Warp forward and verify permanent stays constant while regular decays
        vm.warp(block.timestamp + 13 weeks);

        uint256 newTotalSupply = stakeWeight.totalSupply();
        uint256 newTotalSupplyAtNow = stakeWeight.totalSupplyAtTime(block.timestamp);

        assertEq(
            newTotalSupply,
            newTotalSupplyAtNow,
            "After time warp, totalSupply() should still equal totalSupplyAtTime(block.timestamp)"
        );

        // Bob's permanent lock should remain the same
        uint256 bobNewBalance = stakeWeight.balanceOf(users.bob);
        assertEq(bobBalance, bobNewBalance, "Permanent lock balance should not change");

        // Alice's regular lock should have decayed
        uint256 aliceNewBalance = stakeWeight.balanceOf(users.alice);
        assertLt(aliceNewBalance, aliceBalance, "Regular lock balance should decay");
    }
}
