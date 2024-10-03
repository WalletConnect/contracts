// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { StakeWeight } from "src/StakeWeight.sol";
import { StakeWeight_Integration_Shared_Test } from "test/integration/shared/StakeWeight.t.sol";

contract IncreaseUnlockTime_StakeWeight_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    uint256 constant INITIAL_LOCK_AMOUNT = 100e18;
    uint256 constant INITIAL_LOCK_DURATION = 4 weeks;

    function setUp() public override {
        super.setUp();
        _createLockForUser(users.alice, INITIAL_LOCK_AMOUNT, block.timestamp + INITIAL_LOCK_DURATION);
    }

    function test_RevertWhen_ContractIsPaused() external {
        _pause();
        vm.expectRevert(StakeWeight.Paused.selector);
        vm.prank(users.alice);
        stakeWeight.increaseUnlockTime(block.timestamp + 8 weeks);
    }

    function test_RevertWhen_UserHasNoExistingLock() external {
        vm.prank(users.bob);
        vm.expectRevert(StakeWeight.InvalidLockState.selector);
        stakeWeight.increaseUnlockTime(block.timestamp + 8 weeks);
    }

    function test_RevertWhen_UserHasExpiredLock() external {
        vm.warp(block.timestamp + INITIAL_LOCK_DURATION + 1);
        (, uint256 lockEnd) = stakeWeight.locks(users.alice);
        vm.expectRevert(abi.encodeWithSelector(StakeWeight.ExpiredLock.selector, block.timestamp, lockEnd));
        vm.prank(users.alice);
        stakeWeight.increaseUnlockTime(block.timestamp + 8 weeks);
    }

    function test_RevertWhen_NewUnlockTimeLessThanOrEqualToCurrentLockEnd() external {
        vm.prank(users.alice);
        vm.expectRevert(StakeWeight.CanOnlyIncreaseLockDuration.selector);
        stakeWeight.increaseUnlockTime(block.timestamp + INITIAL_LOCK_DURATION);
    }

    function test_RevertWhen_NewUnlockTimeExceedsMaxLock() external {
        uint256 maxLock = stakeWeight.MAX_LOCK();
        vm.startPrank(users.alice);
        vm.expectRevert(StakeWeight.VotingLockMaxExceeded.selector);
        stakeWeight.increaseUnlockTime(block.timestamp + maxLock + 1);
    }

    function test_WhenNewUnlockTimeIsValid() external {
        uint256 newUnlockTime = block.timestamp + 8 weeks;
        uint256 newUnlockTimeFloored = _timestampToFloorWeek(newUnlockTime);
        uint256 initialSupply = stakeWeight.supply();
        uint256 initialTotalSupply = stakeWeight.totalSupply();
        uint256 initialStakeWeight = stakeWeight.balanceOf(users.alice);

        vm.expectEmit(true, true, true, true);
        emit Deposit(users.alice, 0, newUnlockTimeFloored, stakeWeight.ACTION_INCREASE_UNLOCK_TIME(), block.timestamp);

        vm.expectEmit(true, true, true, true);
        emit Supply(initialSupply, stakeWeight.supply());

        vm.prank(users.alice);
        stakeWeight.increaseUnlockTime(newUnlockTime);

        (, uint256 lockEnd) = stakeWeight.locks(users.alice);
        assertEq(lockEnd, newUnlockTimeFloored, "Lock end time should be updated");
        assertEq(stakeWeight.supply(), initialSupply, "Supply should remain the same");
        assertGt(stakeWeight.balanceOf(users.alice), initialStakeWeight, "Stake weight should increase");
        assertGt(stakeWeight.totalSupply(), initialTotalSupply, "Total supply should increase");
    }
}
