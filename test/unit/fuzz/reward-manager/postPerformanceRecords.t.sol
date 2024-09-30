// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { RewardManager } from "src/RewardManager.sol";
import { Staking_Integration_Shared_Test } from "test/integration/shared/Staking.t.sol";

contract PostPerformanceRecords_RewardManager_Unit_Fuzz_Test is Staking_Integration_Shared_Test {
    modifier whenCallerOwner() {
        vm.startPrank(users.admin);
        _;
    }

    modifier whenReportingEpochIsGTLastUpdatedEpoch() {
        _;
    }

    modifier whenInputArraysMatchInLength() {
        _;
    }

    function testFuzz_postPerformanceRecords(uint256[] memory performance)
        external
        whenCallerOwner
        whenReportingEpochIsGTLastUpdatedEpoch
        whenInputArraysMatchInLength
    {
        // Set a min and max number of nodes for the fuzz
        vm.assume(performance.length > 0 && performance.length < defaults.MAX_NODES());
        // Prepare the input arrays
        address[] memory nodes = new address[](performance.length);
        uint256 totalPerformance = 0;
        for (uint8 i = 0; i < performance.length; i++) {
            nodes[i] = createUser(string(abi.encodePacked("node", i)));
            performance[i] = bound(performance[i], 0, 100);
            totalPerformance += performance[i];
            stakeFrom(nodes[i], defaults.MIN_STAKE());
        }
        vm.assume(totalPerformance > 0);
        // Run the test
        vm.startPrank(users.admin);
        rewardManager.postPerformanceRecords(
            RewardManager.PerformanceData({
                nodes: nodes,
                performance: performance,
                reportingEpoch: defaults.FIRST_EPOCH()
            })
        );
        vm.stopPrank();
    }
}
