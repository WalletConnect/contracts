// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakeWeight_Integration_Shared_Test } from "test/integration/shared/StakeWeight.t.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract IncreasePerpetualLockDuration_StakeWeight_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    uint256 constant INITIAL_AMOUNT = 1000 ether;
    uint256 constant INITIAL_DURATION = 4 weeks;

    function setUp() public override {
        super.setUp();
        vm.prank(users.admin);
        l2wct.disableTransferRestrictions();
    }

    function test_RevertWhen_ContractIsPaused() external {
        _pause();

        vm.startPrank(users.alice);
        vm.expectRevert(StakeWeight.Paused.selector);
        stakeWeight.increasePermanentLockDuration(8 weeks);
        vm.stopPrank();
    }

    modifier whenContractIsNotPaused() {
        _;
    }

    function test_RevertWhen_UserHasNoLock() external whenContractIsNotPaused {
        vm.startPrank(users.alice);
        vm.expectRevert(StakeWeight.NonExistentLock.selector);
        stakeWeight.increasePermanentLockDuration(8 weeks);
        vm.stopPrank();
    }

    modifier whenUserHasALock() {
        // Create a standard decaying lock for Alice
        uint256 amount = INITIAL_AMOUNT;
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
        stakeWeight.increasePermanentLockDuration(8 weeks);
        vm.stopPrank();
    }

    modifier whenLockIsPerpetual() {
        // Create a permanent lock for Alice with initial duration
        uint256 amount = INITIAL_AMOUNT;

        deal(address(l2wct), users.alice, amount);
        vm.startPrank(users.alice);
        IERC20(address(l2wct)).approve(address(stakeWeight), amount);
        stakeWeight.createPermanentLock(amount, INITIAL_DURATION);
        vm.stopPrank();
        _;
    }

    function test_RevertWhen_NewDurationIsNotInValidSet() external whenContractIsNotPaused whenLockIsPerpetual {
        vm.startPrank(users.alice);
        // Try invalid duration (5 weeks is not in the valid set)
        vm.expectRevert(abi.encodeWithSelector(StakeWeight.InvalidDuration.selector, 5 weeks));
        stakeWeight.increasePermanentLockDuration(5 weeks);

        // Try another invalid duration
        vm.expectRevert(abi.encodeWithSelector(StakeWeight.InvalidDuration.selector, 60 weeks));
        stakeWeight.increasePermanentLockDuration(60 weeks);
        vm.stopPrank();
    }

    function test_RevertWhen_NewDurationIsShorterThanOrEqualToCurrent()
        external
        whenContractIsNotPaused
        whenLockIsPerpetual
    {
        vm.startPrank(users.alice);

        // Try to set same duration (4 weeks)
        vm.expectRevert(abi.encodeWithSelector(StakeWeight.InvalidDuration.selector, INITIAL_DURATION));
        stakeWeight.increasePermanentLockDuration(INITIAL_DURATION);
        vm.stopPrank();
    }

    modifier whenNewDurationIsValidAndLonger() {
        // The test will use 52 weeks as the new duration
        _;
    }

    function test_WhenNewDurationIsValidAndLonger()
        external
        whenContractIsNotPaused
        whenLockIsPerpetual
        whenNewDurationIsValidAndLonger
    {
        // Get initial lock state
        StakeWeight.LockedBalance memory lockBefore = stakeWeight.locks(users.alice);
        assertEq(
            stakeWeight.permanentBaseWeeks(users.alice) * 1 weeks,
            INITIAL_DURATION,
            "Initial duration should be 4 weeks"
        );
        assertEq(lockBefore.end, 0, "End should be 0 for permanent");

        assertEq(uint256(int256(lockBefore.amount)), INITIAL_AMOUNT, "Amount should be the actual tokens");

        // Record balance before increasing duration
        uint256 balanceBefore = stakeWeight.balanceOf(users.alice);

        vm.startPrank(users.alice);

        uint256 newDuration = 52 weeks;
        // Calculate expected weight using slope-first helper
        uint256 expectedWeight = _calculatePermanentBias(INITIAL_AMOUNT, newDuration);

        // Expect DurationIncreased event
        vm.expectEmit(true, true, true, true);
        emit DurationIncreased(users.alice, newDuration, block.timestamp);

        // Increase duration
        stakeWeight.increasePermanentLockDuration(newDuration);

        // Verify lock was updated
        StakeWeight.LockedBalance memory lockAfter = stakeWeight.locks(users.alice);
        assertEq(
            stakeWeight.permanentBaseWeeks(users.alice) * 1 weeks, newDuration, "Duration should be updated to 52 weeks"
        );
        assertEq(uint256(int256(lockAfter.amount)), INITIAL_AMOUNT, "Amount should remain constant");
        assertEq(lockAfter.end, 0, "Should still be permanent (end = 0)");

        // Check that balance reflects the new weight
        assertEq(stakeWeight.balanceOf(users.alice), expectedWeight, "Balance should reflect new weight");

        // Verify balance increased due to longer duration
        assertGt(stakeWeight.balanceOf(users.alice), balanceBefore, "Balance should increase with longer duration");

        vm.stopPrank();
    }

    function test_MultipleIncrements()
        external
        whenContractIsNotPaused
        whenLockIsPerpetual
        whenNewDurationIsValidAndLonger
    {
        vm.startPrank(users.alice);

        // First increment: 4 weeks -> 8 weeks
        stakeWeight.increasePermanentLockDuration(8 weeks);
        StakeWeight.LockedBalance memory lock1 = stakeWeight.locks(users.alice);
        assertEq(stakeWeight.permanentBaseWeeks(users.alice) * 1 weeks, 8 weeks);
        assertEq(uint256(int256(lock1.amount)), INITIAL_AMOUNT, "Amount should remain constant");
        uint256 expectedBalance1 = _calculatePermanentBias(INITIAL_AMOUNT, 8 weeks);
        assertEq(stakeWeight.balanceOf(users.alice), expectedBalance1, "Balance should reflect new weight");

        // Second increment: 8 weeks -> 26 weeks
        stakeWeight.increasePermanentLockDuration(26 weeks);
        StakeWeight.LockedBalance memory lock2 = stakeWeight.locks(users.alice);
        assertEq(stakeWeight.permanentBaseWeeks(users.alice) * 1 weeks, 26 weeks);
        assertEq(uint256(int256(lock2.amount)), INITIAL_AMOUNT, "Amount should remain constant");
        uint256 expectedBalance2 = _calculatePermanentBias(INITIAL_AMOUNT, 26 weeks);
        assertEq(stakeWeight.balanceOf(users.alice), expectedBalance2, "Balance should reflect new weight");

        // Third increment: 26 weeks -> 104 weeks
        stakeWeight.increasePermanentLockDuration(104 weeks);
        StakeWeight.LockedBalance memory lock3 = stakeWeight.locks(users.alice);
        assertEq(stakeWeight.permanentBaseWeeks(users.alice) * 1 weeks, 104 weeks);
        assertEq(uint256(int256(lock3.amount)), INITIAL_AMOUNT, "Amount should remain constant");
        uint256 expectedBalance3 = _calculatePermanentBias(INITIAL_AMOUNT, 104 weeks);
        assertEq(stakeWeight.balanceOf(users.alice), expectedBalance3, "Balance should reflect new weight");

        vm.stopPrank();
    }
}
