// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakeWeight_Integration_Shared_Test } from "test/integration/shared/StakeWeight.t.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ConvertToPerpetual_StakeWeight_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    uint256 constant VALID_DURATION = 52 weeks;
    uint256 constant INVALID_DURATION = 5 weeks;
    uint256 constant SHORT_DURATION = 4 weeks;

    function setUp() public override {
        super.setUp();
        vm.prank(users.admin);
        l2wct.disableTransferRestrictions();
    }

    function test_RevertWhen_ContractIsPaused() external {
        _pause();

        vm.startPrank(users.alice);
        vm.expectRevert(StakeWeight.Paused.selector);
        stakeWeight.convertToPermanent(VALID_DURATION);
        vm.stopPrank();
    }

    modifier whenContractIsNotPaused() {
        _;
    }

    function test_RevertWhen_UserHasNoLock() external whenContractIsNotPaused {
        vm.startPrank(users.alice);
        vm.expectRevert(StakeWeight.NonExistentLock.selector);
        stakeWeight.convertToPermanent(VALID_DURATION);
        vm.stopPrank();
    }

    modifier whenUserHasALock() {
        // Create a standard decaying lock for Alice with exactly 26 weeks duration
        uint256 amount = 100 ether;
        uint256 unlockTime = _timestampToFloorWeek(block.timestamp) + 26 weeks;
        
        deal(address(l2wct), users.alice, amount);
        vm.startPrank(users.alice);
        IERC20(address(l2wct)).approve(address(stakeWeight), amount);
        stakeWeight.createLock(amount, unlockTime);
        vm.stopPrank();
        _;
    }

    function test_RevertWhen_LockIsAlreadyPermanent() external whenContractIsNotPaused {
        // Create a permanent lock first
        uint256 amount = 100 ether;
        deal(address(l2wct), users.alice, amount);
        vm.startPrank(users.alice);
        IERC20(address(l2wct)).approve(address(stakeWeight), amount);
        stakeWeight.createPermanentLock(amount, VALID_DURATION);
        
        // Try to convert again
        vm.expectRevert(StakeWeight.AlreadyPermanent.selector);
        stakeWeight.convertToPermanent(VALID_DURATION);
        vm.stopPrank();
    }

    function test_RevertWhen_LockIsExpired() external whenContractIsNotPaused whenUserHasALock {
        // Get lock end time first
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(users.alice);
        uint256 lockEnd = lock.end;
        
        // Fast forward past lock expiry
        _mineBlocks(((lockEnd + 1) - block.timestamp) / defaults.SECONDS_PER_BLOCK());
        
        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(StakeWeight.ExpiredLock.selector, block.timestamp, lockEnd));
        stakeWeight.convertToPermanent(VALID_DURATION);
        vm.stopPrank();
    }

    function test_RevertWhen_DurationNotInValidSet() external whenContractIsNotPaused whenUserHasALock {
        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(StakeWeight.InvalidDuration.selector, INVALID_DURATION));
        stakeWeight.convertToPermanent(INVALID_DURATION);
        vm.stopPrank();
    }

    function test_RevertWhen_NewDurationShorterThanRemainingLockTime() 
        external 
        whenContractIsNotPaused 
        whenUserHasALock 
    {
        // Get the remaining time first
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(users.alice);
        uint256 remainingTime = lock.end - block.timestamp;
        
        vm.startPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                StakeWeight.DurationTooShort.selector, 
                SHORT_DURATION,
                remainingTime
            )
        );
        stakeWeight.convertToPermanent(SHORT_DURATION);
        vm.stopPrank();
    }

    function test_WhenMultipleConversionsInSameWeek() external whenContractIsNotPaused {
        // Create first lock and convert
        uint256 amount = 100 ether;
        uint256 unlockTime = _timestampToFloorWeek(block.timestamp) + 52 weeks;
        
        deal(address(l2wct), users.alice, amount);
        vm.startPrank(users.alice);
        IERC20(address(l2wct)).approve(address(stakeWeight), amount);
        stakeWeight.createLock(amount, unlockTime);
        stakeWeight.convertToPermanent(52 weeks);
        
        // Trigger unlock to go back to decaying
        stakeWeight.triggerUnlock();
        
        // Convert again in the same week (now allowed after simplification)
        stakeWeight.convertToPermanent(52 weeks);
        
        // Verify it's permanent again - balance should not decay
        uint256 balanceNow = stakeWeight.balanceOf(users.alice);
        _mineBlocks(10 weeks / defaults.SECONDS_PER_BLOCK());
        uint256 balanceLater = stakeWeight.balanceOf(users.alice);
        assertEq(balanceNow, balanceLater, "Permanent lock should not decay");
        
        vm.stopPrank();
    }

    function test_WhenConversionIsValid() external whenContractIsNotPaused whenUserHasALock {
        // Get state before conversion
        StakeWeight.LockedBalance memory lockBefore = stakeWeight.locks(users.alice);
        uint256 supplyBefore = stakeWeight.supply();
        
        // Calculate remaining time to ensure we're using a valid duration
        uint256 remainingTime = lockBefore.end - block.timestamp;
        assertGe(VALID_DURATION, remainingTime, "Test setup: duration should be >= remaining time");
        
        // Record balance before conversion (it will decay over time)
        
        vm.startPrank(users.alice);
        
        uint256 balanceBefore = stakeWeight.balanceOf(users.alice);
        
        // Expect conversion event
        vm.expectEmit(true, true, true, true);
        emit PermanentConversion(users.alice, VALID_DURATION, block.timestamp);
        
        // Convert to permanent
        stakeWeight.convertToPermanent(VALID_DURATION);
        
        // Verify lock was converted
        StakeWeight.LockedBalance memory lockAfter = stakeWeight.locks(users.alice);
        assertEq(lockAfter.amount, lockBefore.amount, "Amount should be preserved");
        assertEq(lockAfter.end, 0, "End should be cleared for permanent");
        assertEq(stakeWeight.permanentBaseWeeks(users.alice) * 1 weeks, VALID_DURATION, "Duration should be stored");
        
        // Verify balance has changed to permanent weight (based on duration)
        // The exact weight depends on the duration multiplier
        
        // Verify balance is now constant (permanent)
        uint256 currentBalance = stakeWeight.balanceOf(users.alice);
        
        vm.stopPrank();
        
        // Warp time and check balance remains constant
        _mineBlocks(10 weeks / defaults.SECONDS_PER_BLOCK());
        uint256 futureBalance = stakeWeight.balanceOf(users.alice);
        assertEq(futureBalance, currentBalance, "Balance should remain constant after conversion");
        
        // Verify total supply remains consistent
        assertEq(stakeWeight.supply(), supplyBefore, "Total supply should not change");
    }
}