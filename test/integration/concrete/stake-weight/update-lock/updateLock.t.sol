// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { StakeWeight } from "src/StakeWeight.sol";
import { StakeWeight_Integration_Shared_Test } from "test/integration/shared/StakeWeight.t.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UpdateLock_StakeWeight_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    uint256 constant INITIAL_LOCK_AMOUNT = 100e18;
    uint256 constant INITIAL_LOCK_DURATION = 4 weeks;
    uint256 constant INCREASE_AMOUNT = 50e18;
    uint256 constant NEW_LOCK_DURATION = 8 weeks;

    function setUp() public override {
        super.setUp();
        _createLockForUser(users.alice, INITIAL_LOCK_AMOUNT, block.timestamp + INITIAL_LOCK_DURATION);
    }

    function test_RevertWhen_ContractIsPaused() external {
        _pause();
        vm.expectRevert(StakeWeight.Paused.selector);
        vm.prank(users.alice);
        stakeWeight.updateLock(INCREASE_AMOUNT, block.timestamp + NEW_LOCK_DURATION);
    }

    function test_RevertWhen_UserHasNoExistingLock() external {
        vm.prank(users.bob);
        vm.expectRevert(StakeWeight.NonExistentLock.selector);
        stakeWeight.updateLock(INCREASE_AMOUNT, block.timestamp + NEW_LOCK_DURATION);
    }

    function test_RevertWhen_UserHasExpiredLock() external {
        vm.warp(block.timestamp + INITIAL_LOCK_DURATION + 1);
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(users.alice);

        vm.expectRevert(abi.encodeWithSelector(StakeWeight.ExpiredLock.selector, block.timestamp, lock.end));
        vm.prank(users.alice);
        stakeWeight.updateLock(INCREASE_AMOUNT, block.timestamp + NEW_LOCK_DURATION);
    }

    function test_RevertWhen_AmountIsZero() external {
        vm.prank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(StakeWeight.InvalidAmount.selector, 0));
        stakeWeight.updateLock(0, block.timestamp + NEW_LOCK_DURATION);
    }

    function test_RevertWhen_NewUnlockTimeLessThanOrEqualToCurrentLockEnd() external {
        vm.prank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                StakeWeight.LockTimeNotIncreased.selector,
                _timestampToFloorWeek(block.timestamp + INITIAL_LOCK_DURATION),
                _timestampToFloorWeek(block.timestamp + INITIAL_LOCK_DURATION)
            )
        );
        stakeWeight.updateLock(INCREASE_AMOUNT, block.timestamp + INITIAL_LOCK_DURATION);
    }

    function test_RevertWhen_NewUnlockTimeExceedsMaxLock() external {
        uint256 maxLock = stakeWeight.maxLock();
        vm.startPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                StakeWeight.LockMaxDurationExceeded.selector,
                _timestampToFloorWeek(block.timestamp + maxLock + 1 weeks),
                _timestampToFloorWeek(block.timestamp + maxLock)
            )
        );
        stakeWeight.updateLock(INCREASE_AMOUNT, block.timestamp + maxLock + 1 weeks);
    }

    function test_RevertWhen_AmountExceedsBalance() external {
        uint256 newUnlockTime = block.timestamp + NEW_LOCK_DURATION;
        uint256 excessiveAmount = l2wct.balanceOf(users.alice) + 1;

        vm.startPrank(users.alice);
        IERC20(address(l2wct)).approve(address(stakeWeight), excessiveAmount);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                users.alice,
                l2wct.balanceOf(users.alice),
                excessiveAmount
            )
        );
        stakeWeight.updateLock(excessiveAmount, newUnlockTime);
        vm.stopPrank();
    }

    function test_WhenParametersAreValid() external {
        uint256 newUnlockTime = block.timestamp + NEW_LOCK_DURATION;
        uint256 newUnlockTimeFloored = _timestampToFloorWeek(newUnlockTime);
        uint256 initialSupply = stakeWeight.supply();
        uint256 initialTotalSupply = stakeWeight.totalSupply();
        uint256 initialStakeWeight = stakeWeight.balanceOf(users.alice);

        deal(address(l2wct), users.alice, INCREASE_AMOUNT);
        uint256 initialBalance = l2wct.balanceOf(users.alice);

        vm.startPrank(users.alice);
        IERC20(address(l2wct)).approve(address(stakeWeight), INCREASE_AMOUNT);

        // Expect events in correct order
        vm.expectEmit(true, true, true, true);
        emit Deposit(
            users.alice,
            INCREASE_AMOUNT,
            newUnlockTimeFloored,
            stakeWeight.ACTION_UPDATE_LOCK(),
            INCREASE_AMOUNT,
            block.timestamp
        );

        vm.expectEmit(true, true, true, true);
        emit Supply(initialSupply, initialSupply + INCREASE_AMOUNT);

        stakeWeight.updateLock(INCREASE_AMOUNT, newUnlockTime);
        vm.stopPrank();

        // Verify state changes
        StakeWeight.LockedBalance memory finalLock = stakeWeight.locks(users.alice);
        assertEq(finalLock.end, newUnlockTimeFloored, "Lock end time should be updated");
        assertEq(
            uint256(int256(finalLock.amount)), INITIAL_LOCK_AMOUNT + INCREASE_AMOUNT, "Lock amount should be increased"
        );
        assertGt(stakeWeight.balanceOf(users.alice), initialStakeWeight, "Stake weight should increase");
        assertGt(stakeWeight.totalSupply(), initialTotalSupply, "Total supply should increase");
        assertEq(
            l2wct.balanceOf(users.alice), initialBalance - INCREASE_AMOUNT, "Tokens should be transferred from user"
        );
    }
}
