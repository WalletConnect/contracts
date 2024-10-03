// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Base_Test } from "test/Base.t.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BalanceOfAt_StakeWeight_Integration_Concrete_Test is Base_Test {
    uint256 constant LOCK_AMOUNT = 100 ether;
    uint256 lockTime;
    uint256 lockBlock;

    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
        disableTransferRestrictions();
    }

    function test_BalanceForUserWithoutLock() external view {
        uint256 balanceWithoutLock = stakeWeight.balanceOfAt(users.bob, block.number);
        assertEq(balanceWithoutLock, 0, "Balance for user without lock should be zero");
    }

    modifier givenUserHasLockedTokensForMaxLock() {
        lockTime = block.timestamp + stakeWeight.MAX_LOCK();
        _createLockForAlice();
        _;
    }

    function test_BalanceAtBeforeLock_MaxLock() external givenUserHasLockedTokensForMaxLock {
        uint256 balanceBefore = stakeWeight.balanceOfAt(users.alice, lockBlock - 1);
        assertEq(balanceBefore, 0, "Balance before lock should be zero");
    }

    function test_BalanceAtLockBlock_MaxLock() external givenUserHasLockedTokensForMaxLock {
        uint256 balanceAtLock = stakeWeight.balanceOfAt(users.alice, lockBlock);
        assertGe(
            balanceAtLock, LOCK_AMOUNT * 990 / 1000, "Balance at lock block should be at least 99% of locked amount"
        );
        assertLe(balanceAtLock, LOCK_AMOUNT, "Balance at lock block should not exceed locked amount");
    }

    function test_BalanceShortlyAfterLock_MaxLock() external givenUserHasLockedTokensForMaxLock {
        vm.warp(lockTime - (stakeWeight.MAX_LOCK() * 9 / 10));
        vm.roll(lockBlock + 100);
        uint256 balanceAfterLock = stakeWeight.balanceOfAt(users.alice, block.number);
        assertGe(balanceAfterLock, LOCK_AMOUNT * 875 / 1000, "Balance should be at least 87.5% of locked amount");
        assertLe(balanceAfterLock, LOCK_AMOUNT * 925 / 1000, "Balance should be at most 92.5% of locked amount");
    }

    function test_BalanceMidwayThroughLockPeriod_MaxLock() external givenUserHasLockedTokensForMaxLock {
        vm.warp(lockTime - (stakeWeight.MAX_LOCK() / 2));
        vm.roll(lockBlock + 5000);
        uint256 balanceMidway = stakeWeight.balanceOfAt(users.alice, block.number);
        assertGe(balanceMidway, LOCK_AMOUNT * 450 / 1000, "Balance should be at least 45% of locked amount");
        assertLe(balanceMidway, LOCK_AMOUNT * 550 / 1000, "Balance should be at most 55% of locked amount");
    }

    function test_BalanceNearEndOfLockPeriod_MaxLock() external givenUserHasLockedTokensForMaxLock {
        vm.warp(lockTime - (stakeWeight.MAX_LOCK() / 10));
        vm.roll(lockBlock + 9000);
        uint256 balanceNearEnd = stakeWeight.balanceOfAt(users.alice, block.number);
        assertGe(balanceNearEnd, LOCK_AMOUNT * 50 / 1000, "Balance should be at least 5% of locked amount");
        assertLe(balanceNearEnd, LOCK_AMOUNT * 150 / 1000, "Balance should be at most 15% of locked amount");
    }

    function test_BalanceAfterExpiry_MaxLock() external givenUserHasLockedTokensForMaxLock {
        vm.warp(lockTime + 1 weeks);
        vm.roll(lockBlock + 10_000);
        uint256 balanceAfterExpiry = stakeWeight.balanceOfAt(users.alice, block.number);
        assertEq(balanceAfterExpiry, 0, "Balance after expiry should be zero");
    }

    modifier givenUserHasLockedTokensForHalfMaxLock() {
        lockTime = _timestampToFloorWeek(block.timestamp) + stakeWeight.MAX_LOCK() / 2;
        _createLockForAlice();
        _;
    }

    function test_BalanceAtBeforeLock_HalfMaxLock() external givenUserHasLockedTokensForHalfMaxLock {
        uint256 balanceBefore = stakeWeight.balanceOfAt(users.alice, lockBlock - 1);
        assertEq(balanceBefore, 0, "Balance before lock should be zero");
    }

    function test_BalanceAtLockBlock_HalfMaxLock() external givenUserHasLockedTokensForHalfMaxLock {
        uint256 balanceAtLock = stakeWeight.balanceOfAt(users.alice, lockBlock);
        assertGe(balanceAtLock, LOCK_AMOUNT * 475 / 1000, "Balance should be at least 47.5% of locked amount");
        assertLe(balanceAtLock, LOCK_AMOUNT * 500 / 1000, "Balance should be at most 50% of locked amount");
    }

    function test_BalanceShortlyAfterLock_HalfMaxLock() external givenUserHasLockedTokensForHalfMaxLock {
        vm.warp(lockTime - ((lockTime - block.timestamp) * 9 / 10));
        vm.roll(lockBlock + 100);
        uint256 balanceAfterLock = stakeWeight.balanceOfAt(users.alice, block.number);
        assertGe(balanceAfterLock, LOCK_AMOUNT * 425 / 1000, "Balance should be at least 42.5% of locked amount");
        assertLe(balanceAfterLock, LOCK_AMOUNT * 475 / 1000, "Balance should be at most 47.5% of locked amount");
    }

    function test_BalanceMidwayThroughLockPeriod_HalfMaxLock() external givenUserHasLockedTokensForHalfMaxLock {
        vm.warp(lockTime - ((lockTime - block.timestamp) / 2));
        vm.roll(lockBlock + 5000);
        uint256 balanceMidway = stakeWeight.balanceOfAt(users.alice, block.number);
        assertGe(balanceMidway, LOCK_AMOUNT * 225 / 1000, "Balance should be at least 22.5% of locked amount");
        assertLe(balanceMidway, LOCK_AMOUNT * 275 / 1000, "Balance should be at most 27.5% of locked amount");
    }

    function test_BalanceNearEndOfLockPeriod_HalfMaxLock() external givenUserHasLockedTokensForHalfMaxLock {
        vm.warp(lockTime - ((lockTime - block.timestamp) / 10));
        vm.roll(lockBlock + 9000);
        uint256 balanceNearEnd = stakeWeight.balanceOfAt(users.alice, block.number);
        assertGe(balanceNearEnd, LOCK_AMOUNT * 25 / 1000, "Balance should be at least 2.5% of locked amount");
        assertLe(balanceNearEnd, LOCK_AMOUNT * 75 / 1000, "Balance should be at most 7.5% of locked amount");
    }

    function test_BalanceAfterExpiry_HalfMaxLock() external givenUserHasLockedTokensForHalfMaxLock {
        vm.warp(lockTime + 1 weeks);
        vm.roll(lockBlock + 10_000);
        uint256 balanceAfterExpiry = stakeWeight.balanceOfAt(users.alice, block.number);
        assertEq(balanceAfterExpiry, 0, "Balance after expiry should be zero");
    }

    function _createLockForAlice() internal {
        deal(address(l2wct), users.alice, LOCK_AMOUNT);
        vm.startPrank(users.alice);
        IERC20(address(l2wct)).approve(address(stakeWeight), LOCK_AMOUNT);
        stakeWeight.createLock(LOCK_AMOUNT, lockTime);
        lockBlock = block.number;
        vm.stopPrank();
    }
}
