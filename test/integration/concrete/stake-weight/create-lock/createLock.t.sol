// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakeWeight_Integration_Shared_Test } from "test/integration/shared/StakeWeight.t.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CreateLock_StakeWeight_Unit_Concrete_Test is StakeWeight_Integration_Shared_Test {
    function test_RevertWhen_ContractIsPaused() external {
        _pause();

        vm.expectRevert(StakeWeight.Paused.selector);
        stakeWeight.createLock(100 ether, block.timestamp + 1 weeks);
    }

    modifier whenContractIsNotPaused() {
        _;
    }

    function test_RevertGiven_UserAlreadyHasLock() external whenContractIsNotPaused {
        uint256 amount = 100 ether;
        uint256 unlockTime = _timestampToFloorWeek(block.timestamp + 52 weeks);

        // Deal tokens to Alice and start pranking as Alice
        deal(address(l2wct), users.alice, amount * 2);
        vm.startPrank(users.alice);

        // Approve tokens for locking
        IERC20(address(l2wct)).approve(address(stakeWeight), amount * 2);

        // Create initial lock
        stakeWeight.createLock(amount, unlockTime);

        // Attempt to create another lock
        vm.expectRevert(StakeWeight.AlreadyCreatedLock.selector);
        stakeWeight.createLock(amount, unlockTime);

        vm.stopPrank();
    }

    modifier givenUserDoesNotHaveALock() {
        // Ensure the user doesn't have an existing lock
        (int128 lockAmount,) = stakeWeight.locks(users.alice);
        require(lockAmount == 0, "User already has a lock");
        _;
    }

    function test_RevertWhen_ValueIsZero() external whenContractIsNotPaused givenUserDoesNotHaveALock {
        vm.expectRevert(abi.encodeWithSelector(StakeWeight.InvalidAmount.selector, 0));
        stakeWeight.createLock(0, block.timestamp + 1 weeks);
    }

    function test_RevertWhen_UnlockTimeInPast() external whenContractIsNotPaused givenUserDoesNotHaveALock {
        uint256 lockTime = _timestampToFloorWeek(block.timestamp - 1);
        vm.expectRevert(abi.encodeWithSelector(StakeWeight.InvalidUnlockTime.selector, lockTime));
        stakeWeight.createLock(1 ether, lockTime);
    }

    function test_RevertWhen_UnlockTimeTooFarInFuture() external whenContractIsNotPaused givenUserDoesNotHaveALock {
        uint256 maxLock = stakeWeight.maxLock();
        // revert LockMaxDurationExceeded(unlockTime, block.timestamp + s.maxLock);
        vm.expectRevert(
            abi.encodeWithSelector(
                StakeWeight.LockMaxDurationExceeded.selector,
                _timestampToFloorWeek(block.timestamp + maxLock + 2 weeks),
                block.timestamp + maxLock
            )
        );
        stakeWeight.createLock(1 ether, block.timestamp + maxLock + 2 weeks);
    }

    function test_WhenValidParameters() external whenContractIsNotPaused givenUserDoesNotHaveALock {
        uint256 amount = 100 ether;
        uint256 unlockTime = _timestampToFloorWeek(block.timestamp + 52 weeks);

        // Deal tokens to Alice and start pranking as Alice
        deal(address(l2wct), users.alice, amount);
        vm.startPrank(users.alice);

        // Approve tokens for locking
        IERC20(address(l2wct)).approve(address(stakeWeight), amount);

        uint256 supplyBefore = stakeWeight.supply();

        vm.expectEmit(true, true, true, true);
        emit Deposit(users.alice, amount, unlockTime, stakeWeight.ACTION_CREATE_LOCK(), block.timestamp);
        stakeWeight.createLock(amount, unlockTime);

        // Check lock creation
        (int128 lockAmount, uint256 lockEnd) = stakeWeight.locks(users.alice);
        assertEq(uint256(int256(lockAmount)), amount, "Locked amount should match");
        assertEq(lockEnd, _timestampToFloorWeek(unlockTime), "Unlock time should match");

        // Check total supply update
        assertGt(stakeWeight.supply(), supplyBefore, "Total supply should increase");

        // Check point history
        uint256 currentEpoch = stakeWeight.epoch();
        StakeWeight.Point memory point = stakeWeight.pointHistory(currentEpoch);
        assertEq(point.timestamp, block.timestamp, "Last point timestamp should match current timestamp");
        assertEq(point.blockNumber, block.number, "Last point block number should match current block number");

        // Check user point history
        uint256 userEpoch = stakeWeight.userPointEpoch(users.alice);
        StakeWeight.Point memory userPoint = stakeWeight.userPointHistory(users.alice, userEpoch);
        assertEq(userPoint.timestamp, block.timestamp, "User point timestamp should match current timestamp");
        assertEq(userPoint.blockNumber, block.number, "User point block number should match current block number");

        // Check slope changes
        int128 slopeChange = stakeWeight.slopeChanges(lockEnd);
        assertLt(slopeChange, 0, "Slope change at unlock time should be negative");

        // Check balanceOf
        uint256 balance = stakeWeight.balanceOf(users.alice);
        assertGt(balance, 0, "Balance should be greater than zero after locking");

        vm.stopPrank();
    }

    function test_WhenValidParameters_And_MaxLock() external whenContractIsNotPaused givenUserDoesNotHaveALock {
        uint256 amount = 100 ether;
        uint256 unlockTime = block.timestamp + stakeWeight.maxLock();

        // Deal tokens to Alice and start pranking as Alice
        deal(address(l2wct), users.alice, amount);
        vm.startPrank(users.alice);

        // Approve tokens for locking
        IERC20(address(l2wct)).approve(address(stakeWeight), amount);

        vm.expectEmit(true, true, true, true);
        emit Deposit(
            users.alice, amount, _timestampToFloorWeek(unlockTime), stakeWeight.ACTION_CREATE_LOCK(), block.timestamp
        );
        stakeWeight.createLock(amount, unlockTime);
    }
}
