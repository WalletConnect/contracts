// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakeWeight_Integration_Shared_Test } from "test/integration/shared/StakeWeight.t.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UpdatePerpetualLock_StakeWeight_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    uint256 constant INITIAL_AMOUNT = 1000 ether;
    uint256 constant INITIAL_DURATION = 4 weeks;
    uint256 constant ADDITIONAL_AMOUNT = 500 ether;

    function setUp() public override {
        super.setUp();
        vm.prank(users.admin);
        l2wct.disableTransferRestrictions();
    }

    function test_RevertWhen_ContractIsPaused() external {
        _pause();

        vm.startPrank(users.alice);
        vm.expectRevert(StakeWeight.Paused.selector);
        stakeWeight.updatePermanentLock(100 ether, 8 weeks);
        vm.stopPrank();
    }

    modifier whenContractIsNotPaused() {
        _;
    }

    function test_RevertWhen_UserHasNoLock() external whenContractIsNotPaused {
        vm.startPrank(users.alice);
        vm.expectRevert(StakeWeight.NonExistentLock.selector);
        stakeWeight.updatePermanentLock(100 ether, 8 weeks);
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
        deal(address(l2wct), users.alice, ADDITIONAL_AMOUNT);
        vm.startPrank(users.alice);
        IERC20(address(l2wct)).approve(address(stakeWeight), ADDITIONAL_AMOUNT);
        vm.expectRevert(StakeWeight.NotPermanent.selector);
        stakeWeight.updatePermanentLock(ADDITIONAL_AMOUNT, 8 weeks);
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

    function test_RevertWhen_NewDurationIsInvalid() 
        external 
        whenContractIsNotPaused 
        whenLockIsPerpetual 
    {
        deal(address(l2wct), users.alice, ADDITIONAL_AMOUNT);
        vm.startPrank(users.alice);
        IERC20(address(l2wct)).approve(address(stakeWeight), ADDITIONAL_AMOUNT);
        
        // Try invalid duration (5 weeks is not in the valid set)
        vm.expectRevert(abi.encodeWithSelector(StakeWeight.InvalidDuration.selector, 5 weeks));
        stakeWeight.updatePermanentLock(ADDITIONAL_AMOUNT, 5 weeks);
        
        // Try another invalid duration
        vm.expectRevert(abi.encodeWithSelector(StakeWeight.InvalidDuration.selector, 60 weeks));
        stakeWeight.updatePermanentLock(ADDITIONAL_AMOUNT, 60 weeks);
        vm.stopPrank();
    }

    function test_RevertWhen_NewDurationIsShorterThanCurrent() 
        external 
        whenContractIsNotPaused 
        whenLockIsPerpetual 
    {
        // First increase duration to 8 weeks
        vm.startPrank(users.alice);
        stakeWeight.updatePermanentLock(0, 8 weeks);
        vm.stopPrank();
        
        // Now try to decrease back to 4 weeks
        deal(address(l2wct), users.alice, ADDITIONAL_AMOUNT);
        vm.startPrank(users.alice);
        IERC20(address(l2wct)).approve(address(stakeWeight), ADDITIONAL_AMOUNT);
        
        // Try to set shorter duration (4 weeks < 8 weeks)
        vm.expectRevert(
            abi.encodeWithSelector(StakeWeight.InvalidDuration.selector, INITIAL_DURATION)
        );
        stakeWeight.updatePermanentLock(ADDITIONAL_AMOUNT, INITIAL_DURATION);
        vm.stopPrank();
    }

    modifier whenNewDurationIsValid() {
        // The test will use valid durations >= current duration
        _;
    }

    function test_WhenOnlyAddingAmount() 
        external 
        whenContractIsNotPaused 
        whenLockIsPerpetual
        whenNewDurationIsValid
    {
        // Get initial lock state
        StakeWeight.LockedBalance memory lockBefore = stakeWeight.locks(users.alice);
        uint256 balanceBefore = stakeWeight.balanceOf(users.alice);
        
        assertEq(stakeWeight.permanentBaseWeeks(users.alice) * 1 weeks, INITIAL_DURATION, "Initial duration should be 4 weeks");
        assertEq(uint256(int256(lockBefore.amount)), INITIAL_AMOUNT, "Initial amount should match");
        
        // Prepare additional tokens
        deal(address(l2wct), users.alice, ADDITIONAL_AMOUNT);
        vm.startPrank(users.alice);
        IERC20(address(l2wct)).approve(address(stakeWeight), ADDITIONAL_AMOUNT);
        
        // Update lock with same duration (only adding amount)
        uint256 expectedNewAmount = INITIAL_AMOUNT + ADDITIONAL_AMOUNT;
        uint256 expectedNewWeight = _calculatePermanentBias(expectedNewAmount, INITIAL_DURATION);
        
        stakeWeight.updatePermanentLock(ADDITIONAL_AMOUNT, INITIAL_DURATION);
        
        // Verify lock was updated
        StakeWeight.LockedBalance memory lockAfter = stakeWeight.locks(users.alice);
        assertEq(stakeWeight.permanentBaseWeeks(users.alice) * 1 weeks, INITIAL_DURATION, "Duration should remain unchanged");
        assertEq(uint256(int256(lockAfter.amount)), expectedNewAmount, "Amount should be sum of old and new");
        assertEq(lockAfter.end, 0, "Should still be permanent (end = 0)");
        
        // Check that balance reflects the new weight
        uint256 balanceAfter = stakeWeight.balanceOf(users.alice);
        assertEq(balanceAfter, expectedNewWeight, "Balance should reflect new weight");
        assertGt(balanceAfter, balanceBefore, "Balance should increase after adding amount");
        
        vm.stopPrank();
    }

    function test_WhenOnlyIncreasingDuration() 
        external 
        whenContractIsNotPaused 
        whenLockIsPerpetual
        whenNewDurationIsValid
    {
        // Get initial lock state
        StakeWeight.LockedBalance memory lockBefore = stakeWeight.locks(users.alice);
        uint256 balanceBefore = stakeWeight.balanceOf(users.alice);
        
        vm.startPrank(users.alice);
        
        uint256 newDuration = 52 weeks;
        // Update lock with 0 additional amount (only increasing duration)
        uint256 expectedNewWeight = _calculatePermanentBias(INITIAL_AMOUNT, newDuration);
        
        // Expect DurationIncreased event
        vm.expectEmit(true, true, true, true);
        emit DurationIncreased(users.alice, newDuration, block.timestamp);
        
        stakeWeight.updatePermanentLock(0, newDuration);
        
        // Verify lock was updated
        StakeWeight.LockedBalance memory lockAfter = stakeWeight.locks(users.alice);
        assertEq(stakeWeight.permanentBaseWeeks(users.alice) * 1 weeks, newDuration, "Duration should be updated to 52 weeks");
        assertEq(uint256(int256(lockAfter.amount)), INITIAL_AMOUNT, "Amount should remain unchanged");
        assertEq(lockAfter.end, 0, "Should still be permanent (end = 0)");
        
        // Check that balance reflects the new weight
        uint256 balanceAfter = stakeWeight.balanceOf(users.alice);
        assertEq(balanceAfter, expectedNewWeight, "Balance should reflect new weight");
        assertGt(balanceAfter, balanceBefore, "Balance should increase after extending duration");
        
        vm.stopPrank();
    }

    function test_WhenBothAddingAmountAndIncreasingDuration() 
        external 
        whenContractIsNotPaused 
        whenLockIsPerpetual
        whenNewDurationIsValid
    {
        // Get initial lock state
        StakeWeight.LockedBalance memory lockBefore = stakeWeight.locks(users.alice);
        uint256 balanceBefore = stakeWeight.balanceOf(users.alice);
        uint256 supplyBefore = stakeWeight.supply();
        
        // Record state before update
        
        // Prepare additional tokens
        deal(address(l2wct), users.alice, ADDITIONAL_AMOUNT);
        vm.startPrank(users.alice);
        IERC20(address(l2wct)).approve(address(stakeWeight), ADDITIONAL_AMOUNT);
        
        uint256 newDuration = 26 weeks;
        uint256 expectedNewAmount = INITIAL_AMOUNT + ADDITIONAL_AMOUNT;
        uint256 expectedNewWeight = _calculatePermanentBias(expectedNewAmount, newDuration);
        
        // Expect DurationIncreased event (since duration is changing)
        vm.expectEmit(true, true, true, true);
        emit DurationIncreased(users.alice, newDuration, block.timestamp);
        
        // Update both amount and duration
        stakeWeight.updatePermanentLock(ADDITIONAL_AMOUNT, newDuration);
        
        // Verify lock was updated
        StakeWeight.LockedBalance memory lockAfter = stakeWeight.locks(users.alice);
        assertEq(stakeWeight.permanentBaseWeeks(users.alice) * 1 weeks, newDuration, "Duration should be updated to 26 weeks");
        assertEq(uint256(int256(lockAfter.amount)), expectedNewAmount, "Amount should be sum of old and new");
        assertEq(lockAfter.end, 0, "Should still be permanent (end = 0)");
        
        // Check that balance reflects the new weight
        uint256 balanceAfter = stakeWeight.balanceOf(users.alice);
        assertEq(balanceAfter, expectedNewWeight, "Balance should reflect new weight");
        assertGt(balanceAfter, balanceBefore, "Balance should increase significantly");
        
        // Verify balance remains constant over time (permanent characteristic)
        _mineBlocks(10 weeks / defaults.SECONDS_PER_BLOCK());
        assertEq(stakeWeight.balanceOf(users.alice), balanceAfter, "Balance should remain constant");
        
        // Verify total supply increased by the additional amount
        assertEq(stakeWeight.supply(), supplyBefore + ADDITIONAL_AMOUNT, "Supply should increase by additional amount");
        
        vm.stopPrank();
    }

    function test_MultipleUpdates() 
        external 
        whenContractIsNotPaused 
        whenLockIsPerpetual
        whenNewDurationIsValid
    {
        vm.startPrank(users.alice);
        
        // First update: Add 200 ether, keep duration at 4 weeks
        deal(address(l2wct), users.alice, 200 ether);
        IERC20(address(l2wct)).approve(address(stakeWeight), 200 ether);
        stakeWeight.updatePermanentLock(200 ether, INITIAL_DURATION);
        
        StakeWeight.LockedBalance memory lock1 = stakeWeight.locks(users.alice);
        assertEq(uint256(int256(lock1.amount)), 1200 ether, "Amount should be 1200 ether");
        assertEq(stakeWeight.permanentBaseWeeks(users.alice) * 1 weeks, INITIAL_DURATION, "Duration should still be 4 weeks");
        
        // Second update: Add 300 ether and increase duration to 8 weeks
        deal(address(l2wct), users.alice, 300 ether);
        IERC20(address(l2wct)).approve(address(stakeWeight), 300 ether);
        stakeWeight.updatePermanentLock(300 ether, 8 weeks);
        
        StakeWeight.LockedBalance memory lock2 = stakeWeight.locks(users.alice);
        assertEq(uint256(int256(lock2.amount)), 1500 ether, "Amount should be 1500 ether");
        assertEq(stakeWeight.permanentBaseWeeks(users.alice) * 1 weeks, 8 weeks, "Duration should be 8 weeks");
        
        // Third update: No additional amount, increase duration to 52 weeks
        stakeWeight.updatePermanentLock(0, 52 weeks);
        
        StakeWeight.LockedBalance memory lock3 = stakeWeight.locks(users.alice);
        assertEq(uint256(int256(lock3.amount)), 1500 ether, "Amount should remain 1500 ether");
        assertEq(stakeWeight.permanentBaseWeeks(users.alice) * 1 weeks, 52 weeks, "Duration should be 52 weeks");
        
        // Verify final balance
        uint256 expectedFinalWeight = _calculatePermanentBias(1500 ether, 52 weeks);
        assertEq(stakeWeight.balanceOf(users.alice), expectedFinalWeight, "Final balance should match expected");
        
        vm.stopPrank();
    }
}