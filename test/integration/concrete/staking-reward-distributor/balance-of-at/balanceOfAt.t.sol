// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { StakeWeight_Integration_Shared_Test } from "../../../shared/StakeWeight.t.sol";

contract BalanceOfAt_StakingRewardDistributor_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    function test_WhenUserHasNoEpochs() external view {
        uint256 balance = stakingRewardDistributor.balanceOfAt(users.alice, block.timestamp);
        assertEq(balance, 0, "Balance should be 0 when user has no epochs");
    }

    function test_WhenTimestampIsBeforeFirstEpoch() external {
        // Create a lock for the user
        uint256 amount = 1000 ether;
        uint256 lockTime = block.timestamp + 4 weeks;
        _createLockForUser(users.alice, amount, lockTime);

        // Check balance before the lock was created
        uint256 balance = stakingRewardDistributor.balanceOfAt(users.alice, block.timestamp - 1 days);
        assertEq(balance, 0, "Balance should be 0 when timestamp is before the first epoch");
    }

    function test_WhenTimestampIsWithinUserEpochRange() external {
        // Create a lock for the user
        uint256 amount = 1000 ether;
        uint256 lockTime = block.timestamp + 4 weeks;
        _createLockForUser(users.alice, amount, lockTime);

        // Check balance within the lock period
        uint256 balance = stakingRewardDistributor.balanceOfAt(users.alice, block.timestamp + 2 weeks);
        assertGt(balance, 0, "Balance should be positive when timestamp is within user's epoch range");
    }

    function test_WhenCalculatedBiasIsNegative() external {
        // Create a lock for the user
        uint256 amount = 1000 ether;
        uint256 lockTime = block.timestamp + 1 weeks;
        _createLockForUser(users.alice, amount, lockTime);

        // Move time forward to after the lock expiration
        vm.warp(block.timestamp + 2 weeks);

        // Check balance after lock expiration
        uint256 balance = stakingRewardDistributor.balanceOfAt(users.alice, block.timestamp);
        assertEq(balance, 0, "Balance should be 0 when calculated bias is negative");
    }

    function test_WhenCalculatedBiasIsPositive() external {
        // Create a lock for the user
        uint256 amount = 1000 ether;
        uint256 lockTime = block.timestamp + 4 weeks;
        _createLockForUser(users.alice, amount, lockTime);

        // Check balance during the lock period
        uint256 balance = stakingRewardDistributor.balanceOfAt(users.alice, block.timestamp + 1 weeks);
        assertGt(balance, 0, "Balance should be positive when calculated bias is positive");
        assertLe(balance, amount, "Balance should not exceed the locked amount");
    }

    function test_WhenTimestampIsAfterLastEpoch() external {
        // Create a lock for the user
        uint256 amount = 1000 ether;
        uint256 lockTime = block.timestamp + 4 weeks;
        _createLockForUser(users.alice, amount, lockTime);

        // Move time forward to after the lock expiration
        vm.warp(block.timestamp + 5 weeks);

        // Check balance after lock expiration
        uint256 balance = stakingRewardDistributor.balanceOfAt(users.alice, block.timestamp);
        assertEq(balance, 0, "Balance should be 0 when timestamp is after the last epoch");
    }

    function test_BalanceDecreaseOverTime() external {
        // Create a lock for the user
        uint256 amount = 1000 ether;
        uint256 lockTime = block.timestamp + 4 weeks;
        _createLockForUser(users.alice, amount, lockTime);

        uint256 balanceStart = stakingRewardDistributor.balanceOfAt(users.alice, block.timestamp);
        uint256 balanceMiddle = stakingRewardDistributor.balanceOfAt(users.alice, block.timestamp + 2 weeks);
        uint256 balanceEnd = stakingRewardDistributor.balanceOfAt(users.alice, block.timestamp + 4 weeks);

        assertGt(balanceStart, balanceMiddle, "Balance should decrease over time");
        assertGt(balanceMiddle, balanceEnd, "Balance should decrease over time");
        assertEq(balanceEnd, 0, "Balance should be 0 at the end of the lock period");
    }

    function test_BalanceIncreasesWithLockAmount() external {
        uint256 amount1 = 1000 ether;
        uint256 amount2 = 2000 ether;
        uint256 lockTime = block.timestamp + 4 weeks;

        _createLockForUser(users.alice, amount1, lockTime);
        uint256 balance1 = stakingRewardDistributor.balanceOfAt(users.alice, block.timestamp);

        _createLockForUser(users.bob, amount2, lockTime);
        uint256 balance2 = stakingRewardDistributor.balanceOfAt(users.bob, block.timestamp);

        assertGt(balance2, balance1, "Balance should be higher for larger lock amounts");
    }

    function test_BalanceIncreasesWithLockDuration() external {
        uint256 amount = 1000 ether;
        uint256 lockTime1 = block.timestamp + 4 weeks;
        uint256 lockTime2 = block.timestamp + 8 weeks;

        _createLockForUser(users.alice, amount, lockTime1);
        uint256 balance1 = stakingRewardDistributor.balanceOfAt(users.alice, block.timestamp);

        _createLockForUser(users.bob, amount, lockTime2);
        uint256 balance2 = stakingRewardDistributor.balanceOfAt(users.bob, block.timestamp);

        assertGt(balance2, balance1, "Balance should be higher for longer lock durations");
    }
}
