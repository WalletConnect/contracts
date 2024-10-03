// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Base_Test } from "test/Base.t.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BalanceOfAtTime_StakeWeight_Integration_Concrete_Test is Base_Test {
    uint256 constant LOCK_AMOUNT = 100 ether;
    uint256 lockTime;
    uint256 unlockTime;

    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
        disableTransferRestrictions();
    }

    modifier givenUserHasLockedTokensForMaxLock() {
        lockTime = block.timestamp;
        unlockTime = lockTime + stakeWeight.MAX_LOCK();
        _createLockForAlice(unlockTime);
        _;
    }

    function test_BalanceBeforeLastCheckpoint_MaxLock() external givenUserHasLockedTokensForMaxLock {
        vm.expectRevert();
        stakeWeight.balanceOfAtTime(users.alice, lockTime - 1);
    }

    function test_BalanceAtLastCheckpoint_MaxLock() external givenUserHasLockedTokensForMaxLock {
        uint256 currentBalance = stakeWeight.balanceOf(users.alice);
        uint256 balanceAtLock = stakeWeight.balanceOfAtTime(users.alice, lockTime);
        assertEq(balanceAtLock, currentBalance, "Balance at last checkpoint should equal current balance");
    }

    function test_BalanceShortlyAfterLastCheckpoint_MaxLock() external givenUserHasLockedTokensForMaxLock {
        uint256 shortlyAfterLockTime = lockTime + 1 weeks;
        uint256 balanceAfterLock = stakeWeight.balanceOfAtTime(users.alice, shortlyAfterLockTime);
        assertGt(balanceAfterLock, 0, "Balance should be greater than 0");
        assertLt(balanceAfterLock, LOCK_AMOUNT, "Balance should be less than locked amount");
    }

    function test_BalanceMidwayThroughLockPeriod_MaxLock() external givenUserHasLockedTokensForMaxLock {
        uint256 midwayLockTime = lockTime + (stakeWeight.MAX_LOCK() / 2);
        uint256 balanceMidway = stakeWeight.balanceOfAtTime(users.alice, midwayLockTime);
        assertGt(balanceMidway, 0, "Balance should be greater than 0");
        assertLt(balanceMidway, LOCK_AMOUNT, "Balance should be less than locked amount");
    }

    function test_BalanceNearEndOfLockPeriod_MaxLock() external givenUserHasLockedTokensForMaxLock {
        uint256 nearEndLockTime = unlockTime - 1 weeks;
        uint256 balanceNearEnd = stakeWeight.balanceOfAtTime(users.alice, nearEndLockTime);
        assertGt(balanceNearEnd, 0, "Balance should be greater than 0");
        assertLt(balanceNearEnd, LOCK_AMOUNT, "Balance should be less than locked amount");
    }

    function test_BalanceAfterExpiry_MaxLock() external givenUserHasLockedTokensForMaxLock {
        uint256 balanceAfterExpiry = stakeWeight.balanceOfAtTime(users.alice, unlockTime + 1);
        assertEq(balanceAfterExpiry, 0, "Balance after expiry should be zero");
    }

    modifier givenUserHasLockedTokensForHalfMaxLock() {
        lockTime = block.timestamp;
        unlockTime = lockTime + (stakeWeight.MAX_LOCK() / 2);
        _createLockForAlice(unlockTime);
        _;
    }

    function test_BalanceBeforeLastCheckpoint_HalfMaxLock() external givenUserHasLockedTokensForHalfMaxLock {
        vm.expectRevert();
        stakeWeight.balanceOfAtTime(users.alice, lockTime - 1);
    }

    function test_BalanceAtLastCheckpoint_HalfMaxLock() external givenUserHasLockedTokensForHalfMaxLock {
        uint256 currentBalance = stakeWeight.balanceOf(users.alice);
        uint256 balanceAtLock = stakeWeight.balanceOfAtTime(users.alice, lockTime);
        assertEq(balanceAtLock, currentBalance, "Balance at last checkpoint should equal current balance");
    }

    function test_BalanceShortlyAfterLastCheckpoint_HalfMaxLock() external givenUserHasLockedTokensForHalfMaxLock {
        uint256 shortlyAfterLockTime = lockTime + 1 weeks;
        uint256 balanceAfterLock = stakeWeight.balanceOfAtTime(users.alice, shortlyAfterLockTime);
        assertGt(balanceAfterLock, 0, "Balance should be greater than 0");
        assertLt(balanceAfterLock, LOCK_AMOUNT, "Balance should be less than locked amount");
    }

    function test_BalanceMidwayThroughLockPeriod_HalfMaxLock() external givenUserHasLockedTokensForHalfMaxLock {
        uint256 midwayLockTime = lockTime + ((unlockTime - lockTime) / 2);
        uint256 balanceMidway = stakeWeight.balanceOfAtTime(users.alice, midwayLockTime);
        assertGt(balanceMidway, 0, "Balance should be greater than 0");
        assertLt(balanceMidway, LOCK_AMOUNT, "Balance should be less than locked amount");
    }

    function test_BalanceNearEndOfLockPeriod_HalfMaxLock() external givenUserHasLockedTokensForHalfMaxLock {
        uint256 nearEndLockTime = unlockTime - 1 weeks;
        uint256 balanceNearEnd = stakeWeight.balanceOfAtTime(users.alice, nearEndLockTime);
        assertGt(balanceNearEnd, 0, "Balance should be greater than 0");
        assertLt(balanceNearEnd, LOCK_AMOUNT, "Balance should be less than locked amount");
    }

    function test_BalanceAfterExpiry_HalfMaxLock() external givenUserHasLockedTokensForHalfMaxLock {
        uint256 balanceAfterExpiry = stakeWeight.balanceOfAtTime(users.alice, unlockTime + 1);
        assertEq(balanceAfterExpiry, 0, "Balance after expiry should be zero");
    }

    function test_BalanceForUserWithoutLock() external view {
        uint256 balanceWithoutLock = stakeWeight.balanceOfAtTime(users.bob, block.timestamp);
        assertEq(balanceWithoutLock, 0, "Balance for user without lock should be zero");
    }

    function _createLockForAlice(uint256 _unlockTime) internal {
        deal(address(l2wct), users.alice, LOCK_AMOUNT);
        vm.startPrank(users.alice);
        IERC20(address(l2wct)).approve(address(stakeWeight), LOCK_AMOUNT);
        stakeWeight.createLock(LOCK_AMOUNT, _unlockTime);
        vm.stopPrank();
    }
}
