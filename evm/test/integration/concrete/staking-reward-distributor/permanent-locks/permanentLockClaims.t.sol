// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { StakeWeight_Integration_Shared_Test } from "test/integration/shared/StakeWeight.t.sol";
import { console2 } from "forge-std/console2.sol";

contract ClaimWithPermanentLocks_Test is StakeWeight_Integration_Shared_Test {
    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public virtual override {
        super.setUp();

        // Disable transfer restrictions for testing
        vm.prank(users.admin);
        l2wct.disableTransferRestrictions();

        // Give users some tokens
        deal(address(l2wct), alice, 10_000e18);
        deal(address(l2wct), bob, 10_000e18);
    }

    function test_WhenPermanentLockHolderClaimsRewards() public {
        // First create the permanent lock
        uint256 lockAmount = 1000e18;
        uint256 duration = 52 weeks; // 1 year permanent lock

        vm.startPrank(alice);
        l2wct.approve(address(stakeWeight), lockAmount);
        stakeWeight.createPermanentLock(lockAmount, duration);
        vm.stopPrank();

        // Checkpoint to establish supply
        stakingRewardDistributor.checkpointTotalSupply();

        // Move forward to next week boundary
        uint256 nextWeek = ((block.timestamp / 1 weeks) + 1) * 1 weeks;
        uint256 blocksToMine = (nextWeek - block.timestamp) / defaults.SECONDS_PER_BLOCK();
        _mineBlocks(blocksToMine);

        // Inject rewards directly for the current week
        uint256 rewardAmount = 100e18;
        uint256 currentWeek = (block.timestamp / 1 weeks) * 1 weeks;

        // Give admin tokens for reward injection
        deal(address(l2wct), users.admin, rewardAmount);

        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), rewardAmount);
        stakingRewardDistributor.injectReward(currentWeek, rewardAmount);
        vm.stopPrank();

        // Checkpoint total supply for this week
        stakingRewardDistributor.checkpointTotalSupply();

        // Move forward one full week to make rewards claimable
        _mineBlocks(1 weeks / defaults.SECONDS_PER_BLOCK());

        // Final checkpoint
        stakingRewardDistributor.checkpointTotalSupply();

        // Check balances and supplies
        uint256 aliceBalance = stakeWeight.balanceOf(alice);
        uint256 totalSupply = stakeWeight.totalSupply();
        uint256 permanentSupply = stakeWeight.permanentSupply();

        // Debug: Check user epoch and permanent weight storage
        uint256 userEpoch = stakeWeight.userPointEpoch(alice);
        uint256 permanentAt = stakeWeight.userPermanentAt(alice, userEpoch);

        console2.log("Alice balance:", aliceBalance);
        console2.log("Total supply:", totalSupply);
        console2.log("Permanent supply:", permanentSupply);
        console2.log("User epoch:", userEpoch);
        console2.log("Permanent at epoch:", permanentAt);

        // Check balanceOfAt from StakingRewardDistributor's perspective
        uint256 weekTimestamp = (block.timestamp / 1 weeks) * 1 weeks;
        uint256 balanceFromDistributor = stakingRewardDistributor.balanceOfAt(alice, weekTimestamp);
        console2.log("Balance from distributor at week:", balanceFromDistributor);

        // Debug: Check tokens per week for multiple weeks
        console2.log("Current week timestamp:", weekTimestamp);
        for (uint256 i = 0; i < 3; i++) {
            uint256 week = weekTimestamp - (i * 1 weeks);
            uint256 tokens = stakingRewardDistributor.tokensPerWeek(week);
            console2.log("  Week", week, "tokens:", tokens);
        }
        uint256 totalSupplyAtWeek = stakingRewardDistributor.totalSupplyAt(currentWeek);
        console2.log("Total supply at week:", totalSupplyAtWeek);

        // Alice should have 100% of the supply
        assertEq(aliceBalance, totalSupply, "Alice should have 100% of supply");
        assertEq(permanentSupply, totalSupply, "All supply should be permanent");

        // Debug: Check user's week cursor
        uint256 userWeekCursor = stakingRewardDistributor.weekCursorOf(alice);
        console2.log("User week cursor before claim:", userWeekCursor);

        // Claim rewards
        vm.startPrank(alice);
        uint256 claimedAmount = stakingRewardDistributor.claim(alice);
        vm.stopPrank();

        console2.log("Claimed amount:", claimedAmount);
        console2.log("Expected amount (approx):", rewardAmount);

        uint256 userWeekCursorAfter = stakingRewardDistributor.weekCursorOf(alice);
        console2.log("User week cursor after claim:", userWeekCursorAfter);

        // Alice should receive close to 100% of rewards (minus rounding)
        assertGt(claimedAmount, (rewardAmount * 95) / 100, "Should receive at least 95% of rewards");
    }

    function test_WhenMixedPermanentAndRegularLocks() public {
        // Alice creates a permanent lock
        uint256 aliceLockAmount = 1000e18;
        uint256 aliceDuration = 52 weeks;

        vm.startPrank(alice);
        l2wct.approve(address(stakeWeight), aliceLockAmount);
        stakeWeight.createPermanentLock(aliceLockAmount, aliceDuration);
        vm.stopPrank();

        // Bob creates a regular lock
        uint256 bobLockAmount = 1000e18;
        uint256 bobUnlockTime = block.timestamp + 52 weeks;

        vm.startPrank(bob);
        l2wct.approve(address(stakeWeight), bobLockAmount);
        stakeWeight.createLock(bobLockAmount, bobUnlockTime);
        vm.stopPrank();

        // Checkpoint to establish supply
        stakingRewardDistributor.checkpointTotalSupply();

        // Move forward to next week boundary
        uint256 nextWeek = ((block.timestamp / 1 weeks) + 1) * 1 weeks;
        uint256 blocksToMine = (nextWeek - block.timestamp) / defaults.SECONDS_PER_BLOCK();
        _mineBlocks(blocksToMine);

        // Inject rewards for the current week
        uint256 rewardAmount = 100e18;
        uint256 currentWeek = (block.timestamp / 1 weeks) * 1 weeks;

        // Give admin tokens for reward injection
        deal(address(l2wct), users.admin, rewardAmount);

        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), rewardAmount);
        stakingRewardDistributor.injectReward(currentWeek, rewardAmount);
        vm.stopPrank();

        // Checkpoint total supply for this week
        stakingRewardDistributor.checkpointTotalSupply();

        // Move forward one full week to make rewards claimable
        _mineBlocks(1 weeks / defaults.SECONDS_PER_BLOCK());

        // Final checkpoint
        stakingRewardDistributor.checkpointTotalSupply();

        // Check weights
        uint256 aliceBalance = stakeWeight.balanceOf(alice);
        uint256 bobBalance = stakeWeight.balanceOf(bob);
        uint256 totalSupply = stakeWeight.totalSupply();

        console2.log("Alice balance (permanent):", aliceBalance);
        console2.log("Bob balance (regular):", bobBalance);
        console2.log("Total supply:", totalSupply);

        // Claim rewards
        vm.startPrank(alice);
        uint256 aliceClaimed = stakingRewardDistributor.claim(alice);
        vm.stopPrank();

        vm.startPrank(bob);
        uint256 bobClaimed = stakingRewardDistributor.claim(bob);
        vm.stopPrank();

        console2.log("Alice claimed:", aliceClaimed);
        console2.log("Bob claimed:", bobClaimed);

        // Both should receive proportional rewards
        uint256 aliceShare = (aliceBalance * 1e18) / totalSupply;
        uint256 expectedAliceReward = (rewardAmount * aliceShare) / 1e18;

        console2.log("Alice expected reward:", expectedAliceReward);

        // Allow 10% tolerance for rounding
        assertApproxEqRel(aliceClaimed, expectedAliceReward, 0.1e18, "Alice should receive proportional rewards");
    }
}
