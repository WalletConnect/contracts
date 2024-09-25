// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Base_Test } from "test/Base.t.sol";
import { Staking } from "src/Staking.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract UpdateRewardRate_Staking_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    modifier whenCallerNotOwner() {
        vm.startPrank(users.alice);
        _;
    }

    modifier whenCallerOwner() {
        vm.startPrank(users.admin);
        _;
    }

    modifier withSufficientBalance() {
        uint256 initialBalance = defaults.STAKING_REWARD_BUDGET();
        deal(address(l2cnkt), address(staking), initialBalance);
        _;
    }

    function test_RevertWhen_CallerNotOwner() external whenCallerNotOwner {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.alice));
        staking.updateRewardRate(100);
    }

    function test_RevertWhen_SameRate() external whenCallerOwner {
        // Change from zero to any non-zero rate to prevent getting InvalidRewardRate
        uint256 newRate = 1;
        deal(address(l2cnkt), address(staking), newRate * defaults.STAKING_REWARD_DURATION());
        staking.updateRewardRate(newRate);
        // Actual test
        assertEq(staking.rewardRate(), newRate, "Reward rate should be updated");
        vm.expectRevert(Staking.NoChange.selector);
        staking.updateRewardRate(newRate);
    }

    function test_RevertWhen_ZeroRate() external whenCallerOwner {
        vm.expectRevert(Staking.InvalidRewardRate.selector);
        staking.updateRewardRate(0);
    }

    function test_RevertWhen_InsufficientBalance() external whenCallerOwner {
        uint256 newRate = 1_000_000 ether; // Very high rate to ensure insufficient balance
        vm.expectRevert(Staking.InsufficientRewardBalance.selector);
        staking.updateRewardRate(newRate);
    }

    function test_GivenFinishAtNotInFuture() external whenCallerOwner withSufficientBalance {
        uint256 newRate = 100 ether;
        uint256 oldRate = staking.rewardRate();

        // Ensure finishAt is not in the future
        vm.warp(staking.finishAt() + 1);

        uint256 expectedFinishAt = block.timestamp + staking.duration();

        vm.expectEmit(true, true, true, true);
        emit RewardRateUpdated(oldRate, newRate);
        staking.updateRewardRate(newRate);

        assertEq(staking.rewardRate(), newRate, "Reward rate should be updated");
        assertEq(staking.updatedAt(), block.timestamp, "updatedAt should be updated");
        assertEq(staking.finishAt(), expectedFinishAt, "finishAt should be set to current time + duration");

        // Additional check for correct reward amount calculation
        uint256 expectedRewardAmount = newRate * staking.duration();
        assertEq(
            staking.rewardRate() * (staking.finishAt() - staking.updatedAt()),
            expectedRewardAmount,
            "New reward amount should be calculated correctly"
        );
    }

    function test_GivenFinishAtInFuture() external whenCallerOwner withSufficientBalance {
        uint256 newRate = 100 ether;
        uint256 oldRate = staking.rewardRate();

        // Ensure finishAt is in the future
        uint256 currentFinishAt = block.timestamp + staking.duration() + 1 days;
        vm.mockCall(address(staking), abi.encodeWithSelector(staking.finishAt.selector), abi.encode(currentFinishAt));

        vm.expectEmit(true, true, true, true);
        emit RewardRateUpdated(oldRate, newRate);
        staking.updateRewardRate(newRate);

        assertEq(staking.rewardRate(), newRate, "Reward rate should be updated");
        assertEq(staking.updatedAt(), block.timestamp, "updatedAt should be updated");
        assertEq(staking.finishAt(), currentFinishAt, "finishAt should not change");

        // Additional check for correct reward amount calculation
        uint256 expectedRewardAmount = newRate * (currentFinishAt - block.timestamp);
        assertEq(
            staking.rewardRate() * (staking.finishAt() - staking.updatedAt()),
            expectedRewardAmount,
            "New reward amount should be calculated correctly"
        );
    }
}
