// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakeWeight } from "src/StakeWeight.sol";
import { StakeWeight_Integration_Shared_Test } from "test/integration/shared/StakeWeight.t.sol";

contract BalanceOf_StakeWeight_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    uint256 constant LOCK_AMOUNT = 100 ether;
    uint256 lockTime;

    function setUp() public override {
        super.setUp();
        // make max lock the cap
        uint256 newMaxLock = stakeWeight.MAX_LOCK_CAP();
        vm.startPrank(users.admin);
        stakeWeight.setMaxLock(newMaxLock);
        l2wct.disableTransferRestrictions();
        vm.stopPrank();
    }

    function test_BalanceForUserWithoutLock() external view {
        uint256 balanceWithoutLock = stakeWeight.balanceOf(users.bob);
        assertEq(balanceWithoutLock, 0, "Balance for user without lock should be zero");
    }

    modifier givenUserHasLockedTokens() {
        lockTime = block.timestamp + stakeWeight.maxLock();
        _createLockForAlice();
        _;
    }

    function test_BalanceJustAfterLock() external givenUserHasLockedTokens {
        uint256 balanceJustAfterLock = stakeWeight.balanceOf(users.alice);
        assertGe(
            balanceJustAfterLock,
            LOCK_AMOUNT * 990 / 1000,
            "Balance just after lock should be at least 99% of locked amount"
        );
        assertLe(balanceJustAfterLock, LOCK_AMOUNT, "Balance just after lock should not exceed locked amount");
    }

    function test_BalanceSomeTimeAfterLock() external givenUserHasLockedTokens {
        vm.warp(block.timestamp + stakeWeight.maxLock() / 2);
        uint256 balanceSomeTimeAfter = stakeWeight.balanceOf(users.alice);
        assertLt(
            balanceSomeTimeAfter, LOCK_AMOUNT, "Balance some time after lock should be less than the locked amount"
        );
        assertGt(balanceSomeTimeAfter, 0, "Balance some time after lock should be more than zero");
    }

    function test_BalanceCloseToExpiry() external givenUserHasLockedTokens {
        vm.warp(lockTime - 1 weeks);
        uint256 balanceCloseToExpiry = stakeWeight.balanceOf(users.alice);
        assertLt(
            balanceCloseToExpiry,
            LOCK_AMOUNT * 10 / 100,
            "Balance close to expiry should be a small fraction of the locked amount"
        );
        assertGt(balanceCloseToExpiry, 0, "Balance close to expiry should be more than zero");
    }

    function test_BalanceAfterExpiry() external givenUserHasLockedTokens {
        vm.warp(lockTime + 1 weeks);
        uint256 balanceAfterExpiry = stakeWeight.balanceOf(users.alice);
        assertEq(balanceAfterExpiry, 0, "Balance after expiry should be zero");
    }

    function test_BalanceComparisonForDifferentDurations() external {
        uint256 shortLockTime = block.timestamp + stakeWeight.maxLock() / 2;
        uint256 longLockTime = block.timestamp + stakeWeight.maxLock();

        _createLockForUser(users.alice, LOCK_AMOUNT, shortLockTime);
        _createLockForUser(users.bob, LOCK_AMOUNT, longLockTime);

        uint256 shortLockBalance = stakeWeight.balanceOf(users.alice);
        uint256 longLockBalance = stakeWeight.balanceOf(users.bob);

        assertLt(
            shortLockBalance,
            longLockBalance,
            "Balance for shorter lock should be lower than longer lock of the same amount"
        );
        assertGt(
            longLockBalance,
            shortLockBalance,
            "Balance for longer lock should be higher than shorter lock of the same amount"
        );
    }

    function _createLockForAlice() internal {
        _createLockForUser(users.alice, LOCK_AMOUNT, lockTime);
    }
}
