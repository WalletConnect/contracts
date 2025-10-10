// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakeWeight } from "src/StakeWeight.sol";
import { StakeWeight_Integration_Shared_Test } from "test/integration/shared/StakeWeight.t.sol";
import { console2 } from "forge-std/console2.sol";

contract TotalSupply_StakeWeight_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    function setUp() public override {
        super.setUp();
        vm.prank(users.admin);
        l2wct.disableTransferRestrictions();
    }

    function test_GivenNoLocksExist() external view {
        assertEq(stakeWeight.totalSupply(), 0, "Total supply should be zero when no locks exist");
    }

    function test_GivenLocksExist() external {
        uint256 amount = 100e18;
        uint256 lockDuration = 1 weeks;
        _createLockForUser(users.alice, amount, block.timestamp + lockDuration);

        uint256 bias = _calculateBias(amount, block.timestamp + lockDuration, block.timestamp);

        assertEq(stakeWeight.totalSupply(), bias, "Total supply should equal the locked amount");
        assertGt(stakeWeight.totalSupply(), 0, "Total supply should be greater than zero");
        assertLe(stakeWeight.totalSupply(), bias, "Total supply should not exceed the total locked amount");
    }

    function test_GivenMultipleUsersHaveLocks() external {
        uint256 aliceAmount = 100e18;
        uint256 bobAmount = 200e18;
        uint256 lockDuration1 = 1 weeks;
        uint256 lockDuration2 = 2 weeks;

        _createLockForUser(users.alice, aliceAmount, block.timestamp + lockDuration1);
        _createLockForUser(users.bob, bobAmount, block.timestamp + lockDuration2);

        uint256 aliceBias = _calculateBias(aliceAmount, block.timestamp + lockDuration1, block.timestamp);
        uint256 bobBias = _calculateBias(bobAmount, block.timestamp + lockDuration2, block.timestamp);

        assertEq(stakeWeight.totalSupply(), aliceBias + bobBias, "Total supply should correctly sum all active locks");
    }

    function test_AfterLockExpires() external {
        uint256 aliceAmount = 100e18;
        uint256 bobAmount = 200e18;
        uint256 lockDuration1 = 1 weeks;
        uint256 lockDuration2 = 2 weeks;

        _createLockForUser(users.alice, aliceAmount, block.timestamp + lockDuration1);
        _createLockForUser(users.bob, bobAmount, block.timestamp + lockDuration2);

        uint256 initialBalanceSum = stakeWeight.balanceOf(users.alice) + stakeWeight.balanceOf(users.bob);

        uint256 initialSupply = stakeWeight.totalSupply();
        assertEq(initialSupply, initialBalanceSum, "Initial supply should equal the sum of initial balances");

        // Warp time to after the first lock expires
        vm.warp(block.timestamp + lockDuration1 + 1);

        uint256 bobBalance = stakeWeight.balanceOf(users.bob);

        assertEq(
            stakeWeight.totalSupply(),
            bobBalance,
            "Total supply should just be bob's balance (as alice's lock has expired)"
        );
        assertLt(stakeWeight.totalSupply(), initialSupply, "Total supply should decrease after a lock expires");
    }

    function test_GivenAllLocksExpire() external {
        uint256 amount1 = 100e18;
        uint256 amount2 = 200e18;
        uint256 lockDuration = 1 weeks;

        _createLockForUser(users.alice, amount1, block.timestamp + lockDuration);
        _createLockForUser(users.bob, amount2, block.timestamp + lockDuration);

        // Warp time to after all locks expire
        vm.warp(block.timestamp + lockDuration + 1);

        assertEq(stakeWeight.totalSupply(), 0, "Total supply should return to zero when all locks expire");
    }

    function test_GivenPermanentLocksExist() external {
        uint256 aliceAmount = 100e18;
        uint256 bobAmount = 200e18;
        uint256 aliceDuration = 26 weeks;
        uint256 bobDuration = 52 weeks;

        // Create permanent locks for both users
        deal(address(l2wct), users.alice, aliceAmount);
        vm.startPrank(users.alice);
        l2wct.approve(address(stakeWeight), aliceAmount);
        stakeWeight.createPermanentLock(aliceAmount, aliceDuration);
        vm.stopPrank();

        deal(address(l2wct), users.bob, bobAmount);
        vm.startPrank(users.bob);
        l2wct.approve(address(stakeWeight), bobAmount);
        stakeWeight.createPermanentLock(bobAmount, bobDuration);
        vm.stopPrank();

        // Calculate expected weights
        uint256 aliceWeight = _calculatePermanentBias(aliceAmount, aliceDuration);
        uint256 bobWeight = _calculatePermanentBias(bobAmount, bobDuration);

        assertEq(stakeWeight.totalSupply(), aliceWeight + bobWeight, "Total supply should sum permanent weights");

        // Verify total supply remains constant over time
        uint256 initialSupply = stakeWeight.totalSupply();

        // Advance time significantly
        vm.warp(block.timestamp + 10 weeks);

        assertEq(stakeWeight.totalSupply(), initialSupply, "Permanent locks should not decay over time");
    }

    function test_GivenMixOfPermanentAndDecayingLocks() external {
        uint256 permanentAmount = 150e18;
        uint256 decayingAmount = 100e18;
        uint256 permanentDuration = 52 weeks;
        uint256 decayingLockTime = _timestampToFloorWeek(block.timestamp) + 26 weeks;

        // Create permanent lock for Alice
        deal(address(l2wct), users.alice, permanentAmount);
        vm.startPrank(users.alice);
        l2wct.approve(address(stakeWeight), permanentAmount);
        stakeWeight.createPermanentLock(permanentAmount, permanentDuration);
        vm.stopPrank();

        // Create decaying lock for Bob
        _createLockForUser(users.bob, decayingAmount, decayingLockTime);

        // Calculate initial weights
        uint256 permanentWeight = _calculatePermanentBias(permanentAmount, permanentDuration);
        uint256 decayingWeight = _calculateBias(decayingAmount, decayingLockTime, block.timestamp);
        uint256 initialSupply = stakeWeight.totalSupply();

        assertEq(initialSupply, permanentWeight + decayingWeight, "Initial supply should sum both lock types");

        // Advance time - permanent should stay constant, decaying should decrease
        vm.warp(block.timestamp + 13 weeks);

        uint256 newDecayingWeight = _calculateBias(decayingAmount, decayingLockTime, block.timestamp);
        uint256 expectedSupply = permanentWeight + newDecayingWeight;

        assertEq(
            stakeWeight.totalSupply(), expectedSupply, "Supply should reflect permanent constant + decaying reduction"
        );
        assertLt(stakeWeight.totalSupply(), initialSupply, "Total supply should decrease due to decaying lock");
    }

    // NOTE: This test exposes a critical issue with converting decaying locks to permanent.
    // The global totalSupply calculation becomes incorrect after conversion due to how
    // the checkpoint mechanism handles the state transition. This would significantly
    // impact reward distribution. A proper fix would require either:
    // 1. Tracking permanent supply separately (adds complexity)
    // 2. Preventing conversions between states (simpler but less flexible)
    // 3. Implementing state-aware bias adjustments in _checkpoint (complex)
    function test_AfterConvertingDecayingToPermanent_CRITICAL_ISSUE() external {
        uint256 amount = 100e18;
        uint256 initialLockTime = _timestampToFloorWeek(block.timestamp) + 26 weeks;
        uint256 permanentDuration = 52 weeks;

        // Create decaying lock for Alice
        _createLockForUser(users.alice, amount, initialLockTime);

        uint256 initialSupply = stakeWeight.totalSupply();

        // Advance time so lock is partially decayed
        vm.warp(block.timestamp + 10 weeks);

        uint256 decayedSupply = stakeWeight.totalSupply();
        assertLt(decayedSupply, initialSupply, "Supply should decay over time");

        // Get the supply value before conversion to understand the remaining weight
        uint256 remainingWeight = stakeWeight.balanceOf(users.alice);

        // Debug: Check totalSupply before conversion
        uint256 totalSupplyBefore = stakeWeight.totalSupply();
        console2.log("Total supply before conversion:", totalSupplyBefore);
        console2.log("Remaining decaying weight:", remainingWeight);

        // Convert to permanent
        vm.prank(users.alice);
        stakeWeight.convertToPermanent(permanentDuration);

        // Debug: Check totalSupply immediately after
        uint256 totalSupplyImmediately = stakeWeight.totalSupply();
        console2.log("Total supply immediately after conversion:", totalSupplyImmediately);
        console2.log("Expected permanent weight:", _calculatePermanentBias(amount, permanentDuration));
        console2.log(
            "Difference (old decaying still there?):",
            totalSupplyImmediately - _calculatePermanentBias(amount, permanentDuration)
        );

        // Calculate expected permanent weight
        uint256 permanentWeight = _calculatePermanentBias(amount, permanentDuration);

        // Check user's balance after conversion
        uint256 userBalanceAfter = stakeWeight.balanceOf(users.alice);
        assertEq(userBalanceAfter, permanentWeight, "User balance should match permanent weight");

        // After conversion, the totalSupply should equal the user's permanent balance
        // since they are the only user in the system
        uint256 totalSupplyAfter = stakeWeight.totalSupply();
        assertEq(totalSupplyAfter, userBalanceAfter, "Total supply should match the only user's balance");

        // Verify the supply stays constant over time (doesn't decay)
        uint256 supplyAfterConversion = totalSupplyAfter;
        vm.warp(block.timestamp + 20 weeks);

        assertEq(stakeWeight.totalSupply(), supplyAfterConversion, "Permanent supply should not decay");

        // Additional verification: balance should also remain constant
        assertEq(stakeWeight.balanceOf(users.alice), permanentWeight, "User balance should remain constant");
    }
}
