// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { LockedTokenStaker_Integration_Shared_Test } from "test/integration/shared/LockedTokenStaker.t.sol";
import { LockedTokenStaker } from "src/LockedTokenStaker.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CreateLockFor_LockedTokenStaker_Integration_Concrete_Test is LockedTokenStaker_Integration_Shared_Test {
    function test_RevertGiven_ContractIsPaused() external {
        _pause();

        (bytes memory decodableArgs, bytes32[] memory proof) = _createAllocation(users.alice, 100 ether);

        vm.expectRevert(LockedTokenStaker.Paused.selector);
        vm.prank(users.alice);
        lockedTokenStaker.createLockFor(users.alice, 100 ether, block.timestamp + 1 weeks, 0, decodableArgs, proof);
    }

    modifier whenContractIsNotPaused() {
        _;
    }

    function test_RevertGiven_UserIsNotTheOriginalBeneficiary() external whenContractIsNotPaused {
        (bytes memory decodableArgs, bytes32[] memory proof) = _createAllocation(users.alice, 100 ether);

        vm.expectRevert(LockedTokenStaker.InvalidCaller.selector);
        vm.prank(users.bob);
        lockedTokenStaker.createLockFor(users.alice, 100 ether, block.timestamp + 1 weeks, 0, decodableArgs, proof);
    }

    modifier givenUserIsTheOriginalBeneficiary() {
        _;
    }

    function test_RevertGiven_UserAlreadyHasLock() external whenContractIsNotPaused givenUserIsTheOriginalBeneficiary {
        uint256 amount = 100 ether;
        uint256 unlockTime = _timestampToFloorWeek(block.timestamp + 52 weeks);

        (bytes memory decodableArgs, bytes32[] memory proof) = _createAllocation(users.alice, amount * 2);

        // Create initial lock
        _createLockForUser(users.alice, amount, unlockTime, decodableArgs, proof);

        // Attempt to create another lock
        vm.expectRevert(StakeWeight.AlreadyCreatedLock.selector);
        vm.prank(users.alice);
        lockedTokenStaker.createLockFor(users.alice, amount, unlockTime, 0, decodableArgs, proof);
    }

    modifier givenUserDoesNotHaveALock() {
        _;
    }

    function test_RevertWhen_ValueIsZero()
        external
        whenContractIsNotPaused
        givenUserIsTheOriginalBeneficiary
        givenUserDoesNotHaveALock
    {
        (bytes memory decodableArgs, bytes32[] memory proof) = _createAllocation(users.alice, 100 ether);

        vm.expectRevert(abi.encodeWithSelector(StakeWeight.InvalidAmount.selector, 0));
        vm.prank(users.alice);
        lockedTokenStaker.createLockFor(users.alice, 0, block.timestamp + 1 weeks, 0, decodableArgs, proof);
    }

    function test_RevertWhen_ValueGreaterThanAllocation()
        external
        whenContractIsNotPaused
        givenUserIsTheOriginalBeneficiary
        givenUserDoesNotHaveALock
    {
        uint256 allocation = 100 ether;
        (bytes memory decodableArgs, bytes32[] memory proof) = _createAllocation(users.alice, allocation);

        vm.expectRevert(LockedTokenStaker.InsufficientAllocation.selector);
        vm.prank(users.alice);
        lockedTokenStaker.createLockFor(users.alice, allocation + 1, block.timestamp + 1 weeks, 0, decodableArgs, proof);
    }

    function test_RevertWhen_UnlockTimeInPast()
        external
        whenContractIsNotPaused
        givenUserIsTheOriginalBeneficiary
        givenUserDoesNotHaveALock
    {
        (bytes memory decodableArgs, bytes32[] memory proof) = _createAllocation(users.alice, 100 ether);

        uint256 lockTime = _timestampToFloorWeek(block.timestamp - 1);
        vm.expectRevert(abi.encodeWithSelector(StakeWeight.InvalidUnlockTime.selector, lockTime));
        vm.prank(users.alice);
        lockedTokenStaker.createLockFor(users.alice, 1 ether, lockTime, 0, decodableArgs, proof);
    }

    function test_RevertWhen_UnlockTimeTooFarInFuture()
        external
        whenContractIsNotPaused
        givenUserIsTheOriginalBeneficiary
        givenUserDoesNotHaveALock
    {
        (bytes memory decodableArgs, bytes32[] memory proof) = _createAllocation(users.alice, 100 ether);

        uint256 maxLock = stakeWeight.maxLock();
        vm.expectRevert(
            abi.encodeWithSelector(
                StakeWeight.LockMaxDurationExceeded.selector,
                _timestampToFloorWeek(block.timestamp + maxLock + 2 weeks),
                block.timestamp + maxLock
            )
        );
        vm.prank(users.alice);
        lockedTokenStaker.createLockFor(
            users.alice, 1 ether, block.timestamp + maxLock + 2 weeks, 0, decodableArgs, proof
        );
    }

    function test_WhenValidParameters()
        external
        whenContractIsNotPaused
        givenUserIsTheOriginalBeneficiary
        givenUserDoesNotHaveALock
    {
        uint256 initialBalance = l2wct.balanceOf(users.alice);
        uint256 amount = 100 ether;
        uint256 unlockTime = _timestampToFloorWeek(block.timestamp + 52 weeks);

        (bytes memory decodableArgs, bytes32[] memory proof) = _createAllocation(users.alice, amount);

        uint256 supplyBefore = stakeWeight.supply();

        vm.startPrank(users.alice);
        vm.expectEmit(true, true, true, true);
        emit Deposit(users.alice, amount, unlockTime, stakeWeight.ACTION_CREATE_LOCK(), 0, block.timestamp);
        lockedTokenStaker.createLockFor(users.alice, amount, unlockTime, 0, decodableArgs, proof);

        // Check lock creation
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(users.alice);
        assertEq(uint256(int256(lock.amount)), amount, "Locked amount should match");
        assertEq(lock.end, _timestampToFloorWeek(unlockTime), "Unlock time should match");

        // Check total supply update
        assertGt(stakeWeight.supply(), supplyBefore, "Total supply should increase");

        // Check user's token balance (should not change)
        assertEq(l2wct.balanceOf(users.alice), initialBalance, "User's token balance should not change");

        // Check staking contract's token balance (should not change)
        assertEq(l2wct.balanceOf(address(stakeWeight)), 0, "Staking contract's token balance should not change");

        vm.stopPrank();
    }
}
