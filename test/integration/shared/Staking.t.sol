// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

import { Integration_Test } from "../Integration.t.sol";
import { RewardManager } from "src/RewardManager.sol";

contract Staking_Integration_Shared_Test is Integration_Test {
    function stakeFromAndReward(address staker, uint256 amount) internal {
        _stakeFrom(staker, amount);
        _grantRewards(staker);
    }

    function stakeFrom(address staker, uint256 amount) internal {
        _stakeFrom(staker, amount);
    }

    function _stakeFrom(address staker, uint256 amount) private {
        vm.startPrank(users.admin);
        cnct.mint(staker, amount);
        permissionedNodeRegistry.whitelistNode(staker);
        vm.stopPrank();
        vm.startPrank(staker);
        cnct.approve(address(staking), amount);
        staking.stake(amount);
        vm.stopPrank();
    }

    function _grantRewards(address staker) private {
        address[] memory nodes = new address[](1);
        nodes[0] = staker;
        uint256[] memory performance = new uint256[](1);
        performance[0] = 1;
        vm.startPrank(users.admin);
        rewardManager.postPerformanceRecords(
            RewardManager.PerformanceData({ nodes: nodes, performance: performance, reportingEpoch: 1 })
        );
        vm.stopPrank();
    }
}
