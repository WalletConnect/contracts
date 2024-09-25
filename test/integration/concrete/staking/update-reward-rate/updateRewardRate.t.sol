// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Staking_Integration_Shared_Test } from "test/integration/shared/Staking.t.sol";
import { Staking } from "src/Staking.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract UpdateRewardRate_Staking_Integration_Concrete_Test is Staking_Integration_Shared_Test {
    uint256 constant OLD_REWARD_RATE = 100; // Example value
    uint256 constant NEW_REWARD_RATE = 200; // Example value

    function setUp() public override {
        super.setUp();
        // Mint rewards to the staking contract
        vm.startPrank(address(mockBridge));
        l2wct.mint(address(staking), NEW_REWARD_RATE * defaults.STAKING_REWARD_DURATION());
        // Update the reward rate
        resetPrank(users.admin);
        staking.updateRewardRate(OLD_REWARD_RATE);
        resetPrank(users.manager);
        l2wct.setAllowedTo(address(staking), true);
        l2wct.setAllowedFrom(address(staking), true);
        vm.stopPrank();
    }

    function test_RevertWhen_CallerIsNotOwner() external {
        vm.prank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, users.alice));
        staking.updateRewardRate(NEW_REWARD_RATE);
    }

    modifier whenCallerIsOwner() {
        _;
    }

    function test_RevertWhen_NewRateIsSameAsOld() external whenCallerIsOwner {
        vm.expectRevert(Staking.NoChange.selector);
        vm.prank(users.admin);
        staking.updateRewardRate(OLD_REWARD_RATE);
    }

    function test_UpdateRateWhenNoStakers() external whenCallerIsOwner {
        vm.expectEmit(true, true, true, true);
        emit RewardRateUpdated(OLD_REWARD_RATE, NEW_REWARD_RATE);
        vm.prank(users.admin);
        staking.updateRewardRate(NEW_REWARD_RATE);

        assertEq(staking.rewardRate(), NEW_REWARD_RATE, "Reward rate should be updated");
    }

    function test_UpdateRateWithExistingStakers() external whenCallerIsOwner {
        uint256 stakeAmount = 1000e18;
        stakeFrom(users.alice, stakeAmount);

        skip(1 days);

        vm.expectEmit(true, true, true, true);
        emit RewardRateUpdated(OLD_REWARD_RATE, NEW_REWARD_RATE);
        vm.prank(users.admin);
        staking.updateRewardRate(NEW_REWARD_RATE);

        assertEq(staking.rewardRate(), NEW_REWARD_RATE, "Reward rate should be updated");
    }

    function test_RewardsAfterRateChangeForExistingStakers() external whenCallerIsOwner {
        uint256 stakeAmount = 1000e18;
        stakeFrom(users.alice, stakeAmount);

        skip(1 days);

        uint256 rewardsBefore = staking.earned(users.alice);
        vm.prank(users.admin);
        staking.updateRewardRate(NEW_REWARD_RATE);

        skip(1 days);

        uint256 rewardsAfter = staking.earned(users.alice);
        assertGt(rewardsAfter, rewardsBefore, "Rewards should increase after rate change");
        assertEq(rewardsAfter - rewardsBefore, NEW_REWARD_RATE * 1 days, "Rewards should be calculated with new rate");
    }

    function test_RewardsAfterRateChangeForNewStaker() external whenCallerIsOwner {
        vm.prank(users.admin);
        staking.updateRewardRate(NEW_REWARD_RATE);

        uint256 stakeAmount = 1000e18;
        stakeFrom(users.bob, stakeAmount);

        skip(1 days);

        uint256 rewards = staking.earned(users.bob);
        assertEq(rewards, NEW_REWARD_RATE * 1 days, "Rewards should be calculated with new rate for new staker");
    }
}
