// SPDX-License-Identifier: MIT

import { StakeWeight } from "src/StakeWeight.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { StakeWeight_Integration_Shared_Test } from "test/integration/shared/StakeWeight.t.sol";

pragma solidity >=0.8.25 <0.9.0;

contract WithdrawAll_StakeWeight_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    uint256 constant LOCK_AMOUNT = 100e18;
    uint256 constant LOCK_DURATION = 1 weeks;

    function test_RevertWhen_ContractIsPaused() external {
        _pause();

        vm.expectRevert(StakeWeight.Paused.selector);
        stakeWeight.withdrawAll();
    }

    modifier whenContractIsNotPaused() {
        _;
    }

    function test_RevertWhen_UserHasNoLock() external whenContractIsNotPaused {
        vm.expectRevert(StakeWeight.NonExistentLock.selector);
        stakeWeight.withdrawAll();
    }

    modifier whenUserHasLock() {
        _createLockForUser(users.alice, LOCK_AMOUNT, block.timestamp + LOCK_DURATION);
        vm.startPrank(users.alice);
        _;
    }

    function test_RevertWhen_LockHasNotExpired() external whenContractIsNotPaused whenUserHasLock {
        vm.expectRevert(
            abi.encodeWithSelector(
                StakeWeight.LockStillActive.selector, _timestampToFloorWeek(block.timestamp + LOCK_DURATION)
            )
        );
        stakeWeight.withdrawAll();
    }

    function test_WithdrawAll() external whenContractIsNotPaused whenUserHasLock {
        // Fast forward to after lock expiration
        vm.warp(block.timestamp + LOCK_DURATION + 1);

        uint256 initialSupply = stakeWeight.supply();
        uint256 initialBalance = l2wct.balanceOf(users.alice);

        vm.expectEmit(true, true, true, true);
        emit Supply(initialSupply, initialSupply - LOCK_AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit Withdraw(users.alice, LOCK_AMOUNT, block.timestamp);

        stakeWeight.withdrawAll();

        (int128 lockAmount, uint256 lockEnd) = stakeWeight.locks(users.alice);
        assertEq(SafeCast.toUint256(lockAmount), 0, "Lock amount should be zero");
        assertEq(lockEnd, 0, "Lock end should be zero");
        assertEq(stakeWeight.supply(), initialSupply - LOCK_AMOUNT, "Total supply should be updated");
        assertEq(l2wct.balanceOf(users.alice), initialBalance + LOCK_AMOUNT, "Tokens should be transferred to the user");
    }
}
