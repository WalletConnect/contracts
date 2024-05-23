// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { RewardManager } from "src/RewardManager.sol";
import { BaseScript, Deployments } from "./Base.s.sol";

contract NodeOperatorsSetup is BaseScript {
    /**
     * @dev This script mints BRR tokens for the node operators. It is useful for setting up
     *      without the need to manually interact with the contract.
     */
    function run() external {
        Deployments memory deployments = readDeployments();
        vm.startBroadcast(broadcaster);
        address[] memory nodeOperators = new address[](1);
        nodeOperators[0] = 0xe30E17148b96a0D562EC79747b555B508BD65b4f;
        uint256[] memory performance = new uint256[](1);
        performance[0] = 1;
        deployments.rewardManager.postPerformanceRecords(
            RewardManager.PerformanceData({ nodes: nodeOperators, performance: performance, reportingEpoch: 1 })
        );
        vm.stopBroadcast();
    }
}
