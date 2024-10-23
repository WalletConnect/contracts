// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { LockedTokenStaker_Integration_Shared_Test } from "test/integration/shared/LockedTokenStaker.t.sol";
import { LockedTokenStaker } from "src/LockedTokenStaker.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract IncreaseLockAmountFor_LockedTokenStaker_Integration_Concrete_Test is
    LockedTokenStaker_Integration_Shared_Test
{
    uint256 constant INITIAL_LOCK_AMOUNT = 100 ether;
    uint256 constant INCREASE_AMOUNT = 50 ether;
    bytes decodableArgs;
    bytes32[] proof;

    function test_RevertGiven_ContractIsPaused() external {
        _pause();

        (decodableArgs, proof) = _createAllocation(users.alice, INITIAL_LOCK_AMOUNT + INCREASE_AMOUNT);

        vm.expectRevert(LockedTokenStaker.Paused.selector);
        vm.prank(users.alice);
        lockedTokenStaker.increaseLockAmountFor(users.alice, INCREASE_AMOUNT, 0, decodableArgs, proof);
    }

    modifier whenContractIsNotPaused() {
        _;
    }

    function test_RevertGiven_CallerIsNotTheOriginalBeneficiary() external whenContractIsNotPaused {
        (decodableArgs, proof) = _createAllocation(users.alice, INITIAL_LOCK_AMOUNT + INCREASE_AMOUNT);

        vm.expectRevert(LockedTokenStaker.InvalidCaller.selector);
        vm.prank(users.bob);
        lockedTokenStaker.increaseLockAmountFor(users.alice, INCREASE_AMOUNT, 0, decodableArgs, proof);
    }

    modifier givenCallerIsTheOriginalBeneficiary() {
        _;
    }

    function test_RevertGiven_UserHasNoExistingLock()
        external
        whenContractIsNotPaused
        givenCallerIsTheOriginalBeneficiary
    {
        (decodableArgs, proof) = _createAllocation(users.alice, INITIAL_LOCK_AMOUNT + INCREASE_AMOUNT);

        vm.expectRevert(StakeWeight.NonExistentLock.selector);
        vm.prank(users.alice);
        lockedTokenStaker.increaseLockAmountFor(users.alice, INCREASE_AMOUNT, 0, decodableArgs, proof);
    }

    modifier givenUserHasExistingLock() {
        uint256 unlockTime = _timestampToFloorWeek(block.timestamp + 52 weeks);
        (decodableArgs, proof) = _createAllocation(users.alice, INITIAL_LOCK_AMOUNT + INCREASE_AMOUNT);
        _createLockForUser(users.alice, INITIAL_LOCK_AMOUNT, unlockTime, decodableArgs, proof);
        _;
    }

    function test_RevertGiven_LockHasExpired()
        external
        whenContractIsNotPaused
        givenCallerIsTheOriginalBeneficiary
        givenUserHasExistingLock
    {
        vm.warp(block.timestamp + 53 weeks);

        StakeWeight.LockedBalance memory lock = stakeWeight.locks(users.alice);

        vm.expectRevert(abi.encodeWithSelector(StakeWeight.ExpiredLock.selector, block.timestamp, lock.end));
        vm.prank(users.alice);
        lockedTokenStaker.increaseLockAmountFor(users.alice, INCREASE_AMOUNT, 0, decodableArgs, proof);
    }

    function test_RevertWhen_AmountIsZero()
        external
        whenContractIsNotPaused
        givenCallerIsTheOriginalBeneficiary
        givenUserHasExistingLock
    {
        (decodableArgs, proof) = _createAllocation(users.alice, INITIAL_LOCK_AMOUNT + INCREASE_AMOUNT);

        vm.expectRevert(abi.encodeWithSelector(StakeWeight.InvalidAmount.selector, 0));
        vm.prank(users.alice);
        lockedTokenStaker.increaseLockAmountFor(users.alice, 0, 0, decodableArgs, proof);
    }

    function test_RevertWhen_NewTotalAmountExceedsAllocation()
        external
        whenContractIsNotPaused
        givenCallerIsTheOriginalBeneficiary
        givenUserHasExistingLock
    {
        vm.expectRevert(LockedTokenStaker.InsufficientAllocation.selector);
        vm.prank(users.alice);
        lockedTokenStaker.increaseLockAmountFor(users.alice, INCREASE_AMOUNT + 1 ether, 0, decodableArgs, proof);
    }

    function test_WhenValidParameters()
        external
        whenContractIsNotPaused
        givenCallerIsTheOriginalBeneficiary
        givenUserHasExistingLock
    {
        uint256 initialSupply = stakeWeight.supply();
        uint256 initialBalance = l2wct.balanceOf(users.alice);

        (decodableArgs, proof) = _createAllocation(users.alice, INITIAL_LOCK_AMOUNT + INCREASE_AMOUNT);

        StakeWeight.LockedBalance memory initialLock = stakeWeight.locks(users.alice);

        vm.startPrank(users.alice);

        vm.expectEmit(true, true, true, true);
        emit Deposit(
            users.alice, INCREASE_AMOUNT, initialLock.end, stakeWeight.ACTION_INCREASE_LOCK_AMOUNT(), block.timestamp
        );

        vm.expectEmit(true, true, true, true);
        emit Supply(initialSupply, initialSupply + INCREASE_AMOUNT);

        lockedTokenStaker.increaseLockAmountFor(users.alice, INCREASE_AMOUNT, 0, decodableArgs, proof);

        StakeWeight.LockedBalance memory finalLock = stakeWeight.locks(users.alice);
        assertEq(
            uint256(int256(finalLock.amount)), INITIAL_LOCK_AMOUNT + INCREASE_AMOUNT, "Lock amount should be increased"
        );
        assertEq(stakeWeight.supply(), initialSupply + INCREASE_AMOUNT, "Total supply should be updated");
        assertEq(l2wct.balanceOf(users.alice), initialBalance, "User's token balance should not change");
        assertEq(l2wct.balanceOf(address(stakeWeight)), 0, "Staking contract's token balance should not change");

        vm.stopPrank();
    }
}
