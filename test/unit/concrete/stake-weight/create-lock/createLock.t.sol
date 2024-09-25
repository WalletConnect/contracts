// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Base_Test } from "test/Base.t.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CreateLock_StakeWeight_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
        disableTransferRestrictions();
    }

    function test_RevertWhen_ValueIsZero() external {
        vm.expectRevert(abi.encodeWithSelector(StakeWeight.InvalidAmount.selector, 0));
        stakeWeight.createLock(0, block.timestamp + 1 weeks);
    }

    function test_RevertWhen_UnlockTimeInPast() external {
        uint256 lockTime = _timestampToFloorWeek(block.timestamp - 1);
        vm.expectRevert(abi.encodeWithSelector(StakeWeight.InvalidUnlockTime.selector, lockTime));
        stakeWeight.createLock(1 ether, lockTime);
    }

    function test_RevertWhen_UnlockTimeTooFarInFuture() external {
        uint256 maxLock = stakeWeight.MAX_LOCK();
        vm.expectRevert(abi.encodeWithSelector(StakeWeight.VotingLockMaxExceeded.selector));
        stakeWeight.createLock(1 ether, block.timestamp + maxLock + 2 weeks);
    }

    function test_WhenValidParameters() external {
        uint256 amount = 100 ether;
        uint256 unlockTime = _timestampToFloorWeek(block.timestamp + 52 weeks);

        // Deal tokens to Alice and start pranking as Alice
        deal(address(l2cnkt), users.alice, amount);
        vm.startPrank(users.alice);

        // Approve tokens for locking
        IERC20(address(l2cnkt)).approve(address(stakeWeight), amount);

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
        (,, uint256 timestamp, uint256 blockNumber) = stakeWeight.pointHistory(currentEpoch);
        assertEq(timestamp, block.timestamp, "Last point timestamp should match current timestamp");
        assertEq(blockNumber, block.number, "Last point block number should match current block number");

        // Check user point history
        uint256 userEpoch = stakeWeight.userPointEpoch(users.alice);
        (,, uint256 userTimestamp, uint256 userBlockNumber) = stakeWeight.userPointHistory(users.alice, userEpoch);
        assertEq(userTimestamp, block.timestamp, "User point timestamp should match current timestamp");
        assertEq(userBlockNumber, block.number, "User point block number should match current block number");

        // Check slope changes
        int128 slopeChange = stakeWeight.slopeChanges(lockEnd);
        assertLt(slopeChange, 0, "Slope change at unlock time should be negative");

        // Check balanceOf
        uint256 balance = stakeWeight.balanceOf(users.alice);
        assertGt(balance, 0, "Balance should be greater than zero after locking");

        vm.stopPrank();
    }
}
