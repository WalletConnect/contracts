// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { StakeWeight_Integration_Shared_Test } from "../../../shared/StakeWeight.t.sol";
import { console2 } from "forge-std/console2.sol";

contract MixedPositions_StakingRewardDistributor_Integration_Concrete_Test is
    StakeWeight_Integration_Shared_Test
{
    uint256 constant WEEKS_IN_YEAR = 52;
    uint256 weeklyAmount;

    function setUp() public override {
        super.setUp();
        disableTransferRestrictions();
        weeklyAmount = defaults.STAKING_REWARD_BUDGET() / WEEKS_IN_YEAR;
        
        // Start at a clean week boundary
        vm.warp(_timestampToFloorWeek(block.timestamp + 1 weeks));
        _distributeAnnualBudget();
    }

    function _distributeAnnualBudget() internal {
        uint256 currentWeek = _timestampToFloorWeek(block.timestamp);

        deal(address(l2wct), users.admin, defaults.STAKING_REWARD_BUDGET());
        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), defaults.STAKING_REWARD_BUDGET());

        for (uint256 i = 0; i < WEEKS_IN_YEAR; i++) {
            uint256 weekTimestamp = currentWeek + (i * 1 weeks);
            stakingRewardDistributor.injectReward({ timestamp: weekTimestamp, amount: weeklyAmount });
        }

        vm.stopPrank();
    }

    function test_MixedPositions_PermanentEarnsMore() external {
        uint256 amount = 1000 ether;
        
        // Alice creates permanent lock
        deal(address(l2wct), users.alice, amount);
        vm.startPrank(users.alice);
        l2wct.approve(address(stakeWeight), amount);
        stakeWeight.createPermanentLock(amount, 52 weeks);
        vm.stopPrank();
        
        // Bob creates decaying lock
        deal(address(l2wct), users.bob, amount);
        vm.startPrank(users.bob);
        l2wct.approve(address(stakeWeight), amount);
        stakeWeight.createLock(amount, block.timestamp + 52 weeks);
        vm.stopPrank();
        
        // Both should have similar initial weights
        uint256 aliceInitialWeight = stakeWeight.balanceOf(users.alice);
        uint256 bobInitialWeight = stakeWeight.balanceOf(users.bob);
        assertApproxEqAbs(aliceInitialWeight, bobInitialWeight, 1e15, "Initial weights should be similar");
        
        // Move forward 26 weeks (half the lock period)
        vm.warp(block.timestamp + 26 weeks);
        
        // Alice's permanent weight should remain constant
        uint256 aliceWeightLater = stakeWeight.balanceOf(users.alice);
        assertEq(aliceWeightLater, aliceInitialWeight, "Permanent lock should not decay");
        
        // Bob's weight should have decayed
        uint256 bobWeightLater = stakeWeight.balanceOf(users.bob);
        assertLt(bobWeightLater, bobInitialWeight, "Decaying lock should have decayed");
        assertApproxEqRel(bobWeightLater, bobInitialWeight / 2, 0.01e18, "Should decay by ~50%");
        
        // Claim rewards
        vm.prank(users.alice);
        uint256 aliceRewards = stakingRewardDistributor.claim(users.alice);
        
        vm.prank(users.bob);
        uint256 bobRewards = stakingRewardDistributor.claim(users.bob);
        
        // Alice should get more rewards due to constant weight
        assertGt(aliceRewards, bobRewards, "Permanent lock should earn more rewards");
        console2.log("Alice (permanent) rewards:", aliceRewards);
        console2.log("Bob (decaying) rewards:", bobRewards);
        console2.log("Ratio:", (aliceRewards * 100) / bobRewards);
    }

    function test_MixedPositions_ConversionScenarios() external {
        uint256 amount = 1000 ether;
        uint256 weekStart = block.timestamp;
        
        // Three users with same amount
        address payable[3] memory users_ = [users.alice, users.bob, users.carol];
        
        for (uint256 i = 0; i < 3; i++) {
            deal(address(l2wct), users_[i], amount);
            vm.startPrank(users_[i]);
            l2wct.approve(address(stakeWeight), amount);
            stakeWeight.createLock(amount, block.timestamp + 52 weeks);
            vm.stopPrank();
        }
        
        // Week 1: Alice converts to permanent
        vm.warp(weekStart + 1 weeks);
        vm.prank(users.alice);
        stakeWeight.convertToPermanent(52 weeks);
        
        // Week 2: Bob converts to permanent
        vm.warp(weekStart + 2 weeks);
        vm.prank(users.bob);
        stakeWeight.convertToPermanent(52 weeks);
        
        // Week 3: Carol stays decaying
        vm.warp(weekStart + 3 weeks);
        
        // All claim rewards
        vm.prank(users.alice);
        uint256 aliceRewards = stakingRewardDistributor.claim(users.alice);
        
        vm.prank(users.bob);
        uint256 bobRewards = stakingRewardDistributor.claim(users.bob);
        
        vm.prank(users.carol);
        uint256 carolRewards = stakingRewardDistributor.claim(users.carol);
        
        console2.log("Alice (early convert) rewards:", aliceRewards);
        console2.log("Bob (late convert) rewards:", bobRewards);
        console2.log("Carol (never convert) rewards:", carolRewards);
        
        // Alice should have most rewards (permanent longest)
        // Bob should have middle rewards (permanent for part of time)
        // Carol should have least rewards (always decaying)
        assertGt(aliceRewards, bobRewards, "Earlier conversion should yield more rewards");
        assertGt(bobRewards, carolRewards, "Partial permanent should beat full decay");
    }

    function test_MixedPositions_RapidConversions() external {
        uint256 amount = 1000 ether;
        
        // Create 5 users with decaying locks
        address payable[5] memory users_ = [users.alice, users.bob, users.carol, payable(makeAddr("user4")), payable(makeAddr("user5"))];
        
        for (uint256 i = 0; i < 5; i++) {
            deal(address(l2wct), users_[i], amount);
            vm.startPrank(users_[i]);
            l2wct.approve(address(stakeWeight), amount);
            stakeWeight.createLock(amount, block.timestamp + 52 weeks);
            vm.stopPrank();
        }
        
        // All convert to permanent in the same block
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(users_[i]);
            stakeWeight.convertToPermanent(52 weeks);
        }
        
        // Move forward and claim
        vm.warp(block.timestamp + 4 weeks);
        
        uint256 totalClaimed;
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(users_[i]);
            uint256 rewards = stakingRewardDistributor.claim(users_[i]);
            totalClaimed += rewards;
            
            // Each user should get approximately 1/5 of rewards
            assertApproxEqRel(
                rewards,
                weeklyAmount * 4 / 5,
                0.01e18,
                "Should get ~1/5 of 4 weeks rewards"
            );
        }
        
        // Total claimed should be approximately 4 weeks of rewards
        assertApproxEqRel(
            totalClaimed,
            weeklyAmount * 4,
            0.01e18,
            "Total claimed should be ~4 weeks of rewards"
        );
    }

    function test_MixedPositions_UnlockAndRelock() external {
        uint256 amount = 1000 ether;
        
        // Alice creates permanent lock
        deal(address(l2wct), users.alice, amount);
        vm.startPrank(users.alice);
        l2wct.approve(address(stakeWeight), amount);
        stakeWeight.createPermanentLock(amount, 52 weeks);
        vm.stopPrank();
        
        // Move forward 10 weeks
        vm.warp(block.timestamp + 10 weeks);
        
        // Alice triggers unlock (converts to decaying)
        vm.prank(users.alice);
        stakeWeight.triggerUnlock();
        
        // Check it's now decaying
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(users.alice);
        assertGt(lock.end, block.timestamp, "Should have an end time");
        assertEq(stakeWeight.permanentBaseWeeks(users.alice), 0, "Should not be permanent");
        
        // Move forward 5 more weeks
        vm.warp(block.timestamp + 5 weeks);
        
        // Convert back to permanent
        vm.prank(users.alice);
        stakeWeight.convertToPermanent(52 weeks);
        
        // Claim rewards
        vm.prank(users.alice);
        uint256 rewards = stakingRewardDistributor.claim(users.alice);
        
        console2.log("Rewards after unlock/relock cycle:", rewards);
        assertGt(rewards, 0, "Should have earned rewards throughout");
    }
}