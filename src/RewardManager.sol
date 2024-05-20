// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { WalletConnectConfig } from "./WalletConnectConfig.sol";
import { UtilLib } from "./library/UtilLib.sol";

contract RewardManager is Ownable {
    event PerformanceUpdated(uint256 reportingEpoch, uint256 rewardsPerEpoch);
    event RewardsClaimed(address indexed user, uint256 reward);

    error PerformanceDataAlreadyUpdated();
    error MismatchedDataLengths();
    error TotalPerformanceZero();
    error NoRewardsToClaim();

    uint256 constant PERFORMANCE_SCALE = 1e18;
    WalletConnectConfig public walletConnectConfig;
    uint256 public rewardsPerEpoch; // tokens to be distributed per epoch
    uint256 public lastUpdatedEpoch; // Last epoch for which rewards were updated

    struct PerformanceData {
        address[] users;
        uint256[] performance;
        uint256 reportingEpoch;
    }

    mapping(address => uint256) public performance; // Performance scores
    mapping(address => uint256) public pendingRewards; // Pending rewards to be claimed

    constructor(
        address initialOwner,
        uint256 initialRewardsPerEpoch,
        WalletConnectConfig walletConnectConfig_
    )
        Ownable(initialOwner)
    {
        UtilLib.checkNonZeroAddress(address(walletConnectConfig_));

        walletConnectConfig = walletConnectConfig_;
        rewardsPerEpoch = initialRewardsPerEpoch;
    }

    // Function for the Oracle to update performance data and calculate rewards
    function postPerformanceRecords(PerformanceData calldata data) external onlyOwner {
        if (data.reportingEpoch <= lastUpdatedEpoch) {
            revert PerformanceDataAlreadyUpdated();
        }
        if (data.users.length != data.performance.length) {
            revert MismatchedDataLengths();
        }

        uint256 totalPerformance = 0;

        // Calculate total performance of eligible users
        for (uint256 i = 0; i < data.users.length; i++) {
            if (data.performance[i] > 0) {
                totalPerformance += data.performance[i];
            }
        }

        if (totalPerformance == 0) {
            revert TotalPerformanceZero();
        }

        // Distribute rewards based on performance
        for (uint256 i = 0; i < data.users.length; i++) {
            if (data.performance[i] > 0) {
                address user = data.users[i];
                uint256 userPerformance = data.performance[i];
                uint256 userReward = (rewardsPerEpoch * userPerformance) / totalPerformance;
                pendingRewards[user] += userReward;
            }
        }

        // Update the last updated epoch
        lastUpdatedEpoch = data.reportingEpoch;

        emit PerformanceUpdated(data.reportingEpoch, rewardsPerEpoch);
    }

    // Function for users to claim rewards
    function claimRewards() external {
        uint256 reward = pendingRewards[msg.sender];

        if (reward == 0) {
            revert NoRewardsToClaim();
        }

        // Reset the user's pending reward balance
        pendingRewards[msg.sender] = 0;

        emit RewardsClaimed(msg.sender, reward);

        // Transfer the rewards
        IERC20(walletConnectConfig.getCnct()).transfer(msg.sender, reward);
    }
}
