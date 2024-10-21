// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakeWeight } from "src/StakeWeight.sol";
import { StakeWeight_Integration_Shared_Test } from "test/integration/shared/StakeWeight.t.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract IncreaseLockAmount_StakeWeight_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    uint256 constant INITIAL_LOCK_AMOUNT = 100 ether;
    uint256 constant INCREASE_AMOUNT = 50 ether;

    function test_RevertWhen_ContractIsPaused() external {
        _pause();

        vm.expectRevert(StakeWeight.Paused.selector);
        stakeWeight.increaseLockAmount(INCREASE_AMOUNT);
    }

    modifier whenContractIsNotPaused() {
        _;
    }

    function test_RevertWhen_UserHasNoExistingLock() external whenContractIsNotPaused {
        vm.expectRevert(StakeWeight.NonExistentLock.selector);
        stakeWeight.increaseLockAmount(INCREASE_AMOUNT);
    }

    modifier whenUserHasExistingLock() {
        _createLockForUser(users.alice, INITIAL_LOCK_AMOUNT, block.timestamp + 1 weeks);
        vm.startPrank(users.alice);
        _;
    }

    function test_RevertWhen_LockHasExpired() external whenContractIsNotPaused whenUserHasExistingLock {
        vm.warp(block.timestamp + 2 weeks);

        (, uint256 lockEnd) = stakeWeight.locks(users.alice);

        vm.expectRevert(abi.encodeWithSelector(StakeWeight.ExpiredLock.selector, block.timestamp, lockEnd));
        stakeWeight.increaseLockAmount(INCREASE_AMOUNT);
    }

    function test_RevertWhen_AmountIsZero() external whenContractIsNotPaused whenUserHasExistingLock {
        vm.expectRevert(abi.encodeWithSelector(StakeWeight.InvalidAmount.selector, 0));
        stakeWeight.increaseLockAmount(0);
    }

    function test_WhenAmountIsGreaterThanZero() external whenContractIsNotPaused whenUserHasExistingLock {
        uint256 initialSupply = stakeWeight.supply();
        deal(address(l2wct), users.alice, INCREASE_AMOUNT);
        uint256 initialBalance = l2wct.balanceOf(address(users.alice));

        (, uint256 lockEnd) = stakeWeight.locks(users.alice);
        IERC20(address(l2wct)).approve(address(stakeWeight), INCREASE_AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit Deposit(users.alice, INCREASE_AMOUNT, lockEnd, stakeWeight.ACTION_INCREASE_LOCK_AMOUNT(), block.timestamp);

        vm.expectEmit(true, true, true, true);
        emit Supply(initialSupply, initialSupply + INCREASE_AMOUNT);

        stakeWeight.increaseLockAmount(INCREASE_AMOUNT);

        (int128 lockAmount,) = stakeWeight.locks(users.alice);
        assertEq(uint256(int256(lockAmount)), INITIAL_LOCK_AMOUNT + INCREASE_AMOUNT, "Lock amount should be increased");
        assertEq(stakeWeight.supply(), initialSupply + INCREASE_AMOUNT, "Total supply should be updated");
        assertEq(
            l2wct.balanceOf(address(users.alice)),
            initialBalance - INCREASE_AMOUNT,
            "Tokens should be transferred from user"
        );
    }
}
