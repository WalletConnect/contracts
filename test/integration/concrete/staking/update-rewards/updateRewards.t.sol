// SPDX-License-Identifier: UNLICENSED

import { Staking_Integration_Shared_Test } from "test/integration/shared/Staking.t.sol";

import { Staking } from "src/Staking.sol";
import { RewardManager } from "src/RewardManager.sol";
import { UtilLib } from "src/library/UtilLib.sol";

pragma solidity >=0.8.25 <0.9.0;

contract UpdateRewards_Staking_Integration_Concrete_Test is Staking_Integration_Shared_Test {
    address[] public nodes;
    uint256[] public performance;

    function setUp() public override {
        super.setUp();

        // Default values for nodes and performance
        nodes = new address[](1);
        performance = new uint256[](1);
        nodes[0] = users.permissionedNode;
        performance[0] = 1;
    }

    function test_RevertWhen_CallerIsNotRewardManager() external {
        uint256 firstEpoch = defaults.FIRST_EPOCH();
        vm.prank(users.attacker);
        vm.expectRevert(UtilLib.CallerNotBakersSyndicateContract.selector);
        staking.updateRewards(users.attacker, UINT256_MAX, firstEpoch);
    }

    modifier whenCallerIsRewardManager() {
        _;
    }

    function test_GivenNodeHasNotStakedMinAmount() external whenCallerIsRewardManager {
        uint256 initialPendingRewards = staking.pendingRewards(users.permissionedNode);
        uint256 firstEpoch = defaults.FIRST_EPOCH();
        RewardManager.PerformanceData memory data =
            RewardManager.PerformanceData({ nodes: nodes, performance: performance, reportingEpoch: firstEpoch });
        vm.prank(users.admin);
        rewardManager.postPerformanceRecords(data);
        assertEq(initialPendingRewards, staking.pendingRewards(users.permissionedNode));
    }

    modifier givenNodeHasStakedMinAmount() {
        stakeFrom(users.permissionedNode, defaults.MIN_STAKE());
        _;
    }

    function test_RevertGiven_StakingIsPaused() external whenCallerIsRewardManager givenNodeHasStakedMinAmount {
        vm.prank(users.admin);
        pauser.setIsStakingPaused(true);
        vm.startPrank(users.admin);

        uint256 firstEpoch = defaults.FIRST_EPOCH();
        RewardManager.PerformanceData memory data =
            RewardManager.PerformanceData({ nodes: nodes, performance: performance, reportingEpoch: firstEpoch });

        vm.expectRevert(Staking.Paused.selector);
        rewardManager.postPerformanceRecords(data);
    }

    function test_GivenStakingIsNotPaused() external whenCallerIsRewardManager givenNodeHasStakedMinAmount {
        uint256 firstEpoch = defaults.FIRST_EPOCH();
        RewardManager.PerformanceData memory data =
            RewardManager.PerformanceData({ nodes: nodes, performance: performance, reportingEpoch: firstEpoch });

        uint256 initialPendingRewards = staking.pendingRewards(users.permissionedNode);
        vm.expectEmit({ emitter: address(staking) });
        emit RewardsUpdated({
            node: users.permissionedNode,
            reportingEpoch: firstEpoch,
            newRewards: defaults.EPOCH_REWARD_EMISSION()
        });

        vm.prank(users.admin);
        rewardManager.postPerformanceRecords(data);

        assertEq(
            staking.pendingRewards(users.permissionedNode), initialPendingRewards + defaults.EPOCH_REWARD_EMISSION()
        );
    }
}
