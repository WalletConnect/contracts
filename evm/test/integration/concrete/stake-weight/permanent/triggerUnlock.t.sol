// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakeWeight_Integration_Shared_Test } from "test/integration/shared/StakeWeight.t.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TriggerUnlock_StakeWeight_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    uint256 constant PERPETUAL_DURATION = 52 weeks;

    function setUp() public override {
        super.setUp();
        vm.prank(users.admin);
        l2wct.disableTransferRestrictions();
    }

    function test_RevertWhen_ContractIsPaused() external {
        _pause();

        vm.startPrank(users.alice);
        vm.expectRevert(StakeWeight.Paused.selector);
        stakeWeight.triggerUnlock();
        vm.stopPrank();
    }

    modifier whenContractIsNotPaused() {
        _;
    }

    function test_RevertWhen_UserHasNoLock() external whenContractIsNotPaused {
        vm.startPrank(users.alice);
        vm.expectRevert(StakeWeight.NonExistentLock.selector);
        stakeWeight.triggerUnlock();
        vm.stopPrank();
    }

    modifier whenUserHasALock() {
        // Create a standard decaying lock for Alice
        uint256 amount = 100 ether;
        uint256 unlockTime = _timestampToFloorWeek(block.timestamp) + 26 weeks;

        deal(address(l2wct), users.alice, amount);
        vm.startPrank(users.alice);
        IERC20(address(l2wct)).approve(address(stakeWeight), amount);
        stakeWeight.createLock(amount, unlockTime);
        vm.stopPrank();
        _;
    }

    function test_RevertWhen_LockIsNotPermanent() external whenContractIsNotPaused whenUserHasALock {
        // Lock is already decaying from the modifier
        vm.startPrank(users.alice);
        vm.expectRevert(StakeWeight.NotPermanent.selector);
        stakeWeight.triggerUnlock();
        vm.stopPrank();
    }

    modifier whenLockIsPerpetual() {
        // Create a permanent lock for Alice
        uint256 amount = 100 ether;

        deal(address(l2wct), users.alice, amount);
        vm.startPrank(users.alice);
        IERC20(address(l2wct)).approve(address(stakeWeight), amount);
        stakeWeight.createPermanentLock(amount, PERPETUAL_DURATION);
        vm.stopPrank();
        _;
    }

    function test_WhenLockIsPerpetual() external whenContractIsNotPaused whenLockIsPerpetual {
        // Get state before triggering unlock
        StakeWeight.LockedBalance memory lockBefore = stakeWeight.locks(users.alice);
        uint256 permanentBalance = stakeWeight.balanceOf(users.alice);
        uint256 supplyBefore = stakeWeight.supply();

        assertEq(lockBefore.end, 0, "End should be 0 for permanent");
        assertEq(stakeWeight.permanentBaseWeeks(users.alice) * 1 weeks, PERPETUAL_DURATION, "Duration should be stored");

        // Record checkpoint state before
        uint256 userEpochBefore = stakeWeight.userPointEpoch(users.alice);
        assertEq(stakeWeight.userPointHistory(users.alice, userEpochBefore).slope, 0, "Slope should be 0 for permanent");

        // Capture block number before triggering unlock for historical query
        uint256 blockBeforeTrigger = block.number;

        vm.startPrank(users.alice);

        // Calculate expected end time
        uint256 expectedEnd = _timestampToFloorWeek(block.timestamp) + PERPETUAL_DURATION;

        // Expect unlock triggered event
        vm.expectEmit(true, true, true, true);
        emit UnlockTriggered(users.alice, expectedEnd, block.timestamp);

        // Trigger unlock
        stakeWeight.triggerUnlock();

        // Verify lock was converted to decaying
        StakeWeight.LockedBalance memory lockAfter = stakeWeight.locks(users.alice);
        assertEq(lockAfter.amount, lockBefore.amount, "Amount should be preserved");
        assertEq(lockAfter.end, expectedEnd, "End should be set correctly");
        assertEq(stakeWeight.permanentBaseWeeks(users.alice), 0, "Duration should be cleared");

        // Verify new checkpoint was created with slope > 0
        uint256 userEpochAfter = stakeWeight.userPointEpoch(users.alice);
        assertEq(userEpochAfter, userEpochBefore + 1, "New epoch should be created");

        assertGt(
            stakeWeight.userPointHistory(users.alice, userEpochAfter).slope, 0, "Slope should be positive for decaying"
        );

        // Verify bias calculation accounts for decay starting now
        // The bias should be calculated as: amount * (remaining_time / MAX_LOCK_CAP)
        uint256 remainingTime = expectedEnd - block.timestamp;
        int128 expectedSlope = lockAfter.amount / int128(int256(stakeWeight.MAX_LOCK_CAP()));
        int128 expectedBias = expectedSlope * int128(int256(remainingTime));

        // Allow small rounding difference
        assertApproxEqAbs(
            uint256(int256(stakeWeight.userPointHistory(users.alice, userEpochAfter).bias)),
            uint256(int256(expectedBias)),
            1e10,
            "Bias should match expected decay calculation"
        );

        // Verify balance now decays over time
        uint256 currentBalance = stakeWeight.balanceOf(users.alice);
        assertLt(currentBalance, permanentBalance, "Balance should decrease immediately after unlock trigger");

        vm.stopPrank();

        // Mine blocks to advance time and verify decay continues
        _mineBlocks(10 weeks / 12); // Assuming 12 seconds per block
        uint256 futureBalance = stakeWeight.balanceOf(users.alice);
        assertLt(futureBalance, currentBalance, "Balance should continue decaying");

        // Verify total supply remains consistent
        assertEq(stakeWeight.supply(), supplyBefore, "Total supply should not change");

        // Verify historical queries using block-based query
        // Query the block from before triggerUnlock was called
        uint256 historicalPerpetualBalance = stakeWeight.balanceOfAt(users.alice, blockBeforeTrigger);
        // balanceOfAt estimates timestamp from block number which introduces some variance
        // Following the pattern from balanceOfAt tests, we check within a range
        assertGe(
            historicalPerpetualBalance,
            permanentBalance * 99 / 100,
            "Historical balance should be at least 99% of permanent balance"
        );
        assertLe(
            historicalPerpetualBalance,
            permanentBalance * 101 / 100,
            "Historical balance should be at most 101% of permanent balance"
        );
    }
}
