// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";
import { UtilLib } from "src/library/UtilLib.sol";
import { Staking } from "src/Staking.sol";

contract RewardManager is Initializable, OwnableUpgradeable {
    event PerformanceUpdated(uint256 reportingEpoch, uint256 rewardsPerEpoch);

    error PerformanceDataAlreadyUpdated();
    error MismatchedDataLengths();
    error TotalPerformanceZero();

    WalletConnectConfig public bakersSyndicateConfig;
    uint256 public maxRewardsPerEpoch; // tokens to be distributed per epoch
    uint256 public lastUpdatedEpoch; // Last epoch for which rewards were updated

    struct PerformanceData {
        address[] nodes;
        uint256[] performance;
        uint256 reportingEpoch;
    }

    mapping(address => uint256) public performance; // Performance scores

    /// @notice Configuration for contract initialization.
    struct Init {
        address owner;
        uint256 maxRewardsPerEpoch;
        WalletConnectConfig bakersSyndicateConfig;
    }

    /// @notice Initializes the contract.
    /// @dev MUST be called during the contract upgrade to set up the proxies state.
    function initialize(Init memory init) external initializer {
        __Ownable_init(init.owner);
        UtilLib.checkNonZeroAddress(address(init.bakersSyndicateConfig));
        bakersSyndicateConfig = init.bakersSyndicateConfig;
        maxRewardsPerEpoch = init.maxRewardsPerEpoch;
        bakersSyndicateConfig = init.bakersSyndicateConfig;
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

        // Update the last updated epoch
        lastUpdatedEpoch = data.reportingEpoch;

        emit PerformanceUpdated(data.reportingEpoch, maxRewardsPerEpoch);

        // Distribute rewards based on performance
        for (uint256 i = 0; i < data.nodes.length; i++) {
            if (data.performance[i] > 0) {
                address node = data.nodes[i];
                uint256 nodePerformance = data.performance[i];
                uint256 nodeReward = (maxRewardsPerEpoch * nodePerformance) / totalPerformance;
                updateRewards(node, nodeReward, data.reportingEpoch);
            }
        }
    }

    function updateRewards(address node, uint256 nodeReward, uint256 reportingEpoch) internal {
        // TODO: Implement
    }
}
