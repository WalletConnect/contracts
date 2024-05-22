// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { BakersSyndicateConfig } from "./BakersSyndicateConfig.sol";
import { UtilLib } from "./library/UtilLib.sol";
import { Staking } from "./Staking.sol";

contract RewardManager is Ownable {
    event PerformanceUpdated(uint256 reportingEpoch, uint256 rewardsPerEpoch);

    error PerformanceDataAlreadyUpdated();
    error MismatchedDataLengths();
    error TotalPerformanceZero();

    uint256 constant PERFORMANCE_SCALE = 1e18;
    BakersSyndicateConfig public bakersSyndicateConfig;
    uint256 public maxRewardsPerEpoch; // tokens to be distributed per epoch
    uint256 public lastUpdatedEpoch; // Last epoch for which rewards were updated

    struct PerformanceData {
        address[] nodes;
        uint256[] performance;
        uint256 reportingEpoch;
    }

    mapping(address => uint256) public performance; // Performance scores

    constructor(
        address initialOwner,
        uint256 initialMaxRewardsPerEpoch,
        BakersSyndicateConfig bakersSyndicateConfig_
    )
        Ownable(initialOwner)
    {
        UtilLib.checkNonZeroAddress(address(bakersSyndicateConfig_));

        bakersSyndicateConfig = bakersSyndicateConfig_;
        maxRewardsPerEpoch = initialMaxRewardsPerEpoch;
    }

    // Function for the Oracle to update performance data and calculate rewards
    function postPerformanceRecords(PerformanceData calldata data) external onlyOwner {
        if (data.reportingEpoch <= lastUpdatedEpoch) {
            revert PerformanceDataAlreadyUpdated();
        }

        if (data.nodes.length != data.performance.length) {
            revert MismatchedDataLengths();
        }

        uint256 totalPerformance = 0;

        // Calculate total performance of eligible users
        for (uint256 i = 0; i < data.nodes.length; i++) {
            if (data.performance[i] > 0) {
                totalPerformance += data.performance[i];
            }
        }

        if (totalPerformance == 0) {
            revert TotalPerformanceZero();
        }

        Staking staking = Staking(bakersSyndicateConfig.getStaking());
        // Distribute rewards based on performance
        for (uint256 i = 0; i < data.nodes.length; i++) {
            if (data.performance[i] > 0) {
                address node = data.nodes[i];
                if (staking.stakes(node) < staking.minStakeAmount()) {
                    continue;
                }
                uint256 nodePerformance = data.performance[i];
                uint256 nodeReward = (maxRewardsPerEpoch * nodePerformance) / totalPerformance;
                staking.updateRewards(node, nodeReward, data.reportingEpoch);
            }
        }

        // Update the last updated epoch
        lastUpdatedEpoch = data.reportingEpoch;

        emit PerformanceUpdated(data.reportingEpoch, maxRewardsPerEpoch);
    }
}
