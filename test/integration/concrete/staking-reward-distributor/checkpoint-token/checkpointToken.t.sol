// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { StakeWeight_Integration_Shared_Test } from "../../../shared/StakeWeight.t.sol";

contract CheckpointToken_StakingRewardDistributor_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    function setUp() public override {
        super.setUp();
    }

    function test_NoNewTokensToDistribute() external {
        uint256 initialLastTokenBalance = stakingRewardDistributor.lastTokenBalance();
        uint256 initialTotalDistributed = stakingRewardDistributor.totalDistributed();
        uint256 initialTokensPerWeek = stakingRewardDistributor.tokensPerWeek(_timestampToFloorWeek(block.timestamp));

        vm.expectEmit(true, true, true, true);
        emit TokenCheckpointed(block.timestamp, 0);
        stakingRewardDistributor.checkpointToken();

        assertEq(
            stakingRewardDistributor.lastTokenBalance(), initialLastTokenBalance, "lastTokenBalance should not change"
        );
        assertEq(
            stakingRewardDistributor.totalDistributed(), initialTotalDistributed, "totalDistributed should not change"
        );
        assertEq(
            stakingRewardDistributor.tokensPerWeek(_timestampToFloorWeek(block.timestamp)),
            initialTokensPerWeek,
            "tokensPerWeek should not update"
        );
    }

    function test_NewTokensToDistribute() external {
        uint256 distributionAmount = 1000 ether;
        deal(address(l2wct), address(stakingRewardDistributor), distributionAmount);

        uint256 initialLastTokenBalance = stakingRewardDistributor.lastTokenBalance();
        uint256 initialTotalDistributed = stakingRewardDistributor.totalDistributed();

        vm.expectEmit(true, true, true, true);
        emit TokenCheckpointed(block.timestamp, distributionAmount);
        stakingRewardDistributor.checkpointToken();

        assertEq(
            stakingRewardDistributor.lastTokenBalance(),
            initialLastTokenBalance + distributionAmount,
            "lastTokenBalance should update"
        );
        assertEq(
            stakingRewardDistributor.totalDistributed(),
            initialTotalDistributed + distributionAmount,
            "totalDistributed should increase"
        );
    }

    function test_TimeSinceLastCheckpointIsZero() external {
        uint256 distributionAmount = 1000 ether;
        deal(address(l2wct), address(stakingRewardDistributor), distributionAmount);

        // First checkpoint
        stakingRewardDistributor.checkpointToken();
        uint256 initialTokensPerWeek = stakingRewardDistributor.tokensPerWeek(_timestampToFloorWeek(block.timestamp));

        deal(address(l2wct), address(stakingRewardDistributor), distributionAmount * 2);
        stakingRewardDistributor.checkpointToken();

        assertEq(
            stakingRewardDistributor.tokensPerWeek(_timestampToFloorWeek(block.timestamp)),
            initialTokensPerWeek + distributionAmount,
            "All tokens should be added to the current week"
        );
    }

    function test_TimeSinceLastCheckpointSpansMultipleWeeks() external {
        uint256 firstTimeStamp = _timestampToFloorWeek(block.timestamp);
        // First checkpoint
        stakingRewardDistributor.checkpointToken();

        uint256 distributionAmount = 1000 ether;
        deal(address(l2wct), address(stakingRewardDistributor), distributionAmount);

        // Move time forward by 3 weeks
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS() * 3);

        // Second checkpoint
        stakingRewardDistributor.checkpointToken();

        uint256 week1 = stakingRewardDistributor.tokensPerWeek(firstTimeStamp + 0 weeks);
        uint256 week2 = stakingRewardDistributor.tokensPerWeek(firstTimeStamp + 1 weeks);
        uint256 week3 = stakingRewardDistributor.tokensPerWeek(firstTimeStamp + 2 weeks);
        uint256 week4 = stakingRewardDistributor.tokensPerWeek(firstTimeStamp + 3 weeks);

        assertGt(week1, 0, "Week 1 should have tokens distributed");
        assertGt(week2, 0, "Week 2 should have tokens distributed");
        assertGt(week3, 0, "Week 3 should have tokens distributed");
        assertGt(week4, 0, "Week 4 should have tokens distributed");

        assertApproxEqRel(
            week1 + week2 + week3 + week4,
            distributionAmount,
            1,
            "Total distributed should approximately equal the distribution amount"
        );
    }

    function test_UpdateLastTokenTimestamp() external {
        vm.warp(block.timestamp + 1 weeks);
        stakingRewardDistributor.checkpointToken();
        assertEq(
            stakingRewardDistributor.lastTokenTimestamp(),
            block.timestamp,
            "lastTokenTimestamp should update to block.timestamp"
        );
    }
}
