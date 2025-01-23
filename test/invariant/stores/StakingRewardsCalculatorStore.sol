// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

contract StakingRewardsCalculatorStore {
    // Track APY bounds
    int256 public minRecordedApy = type(int256).max;
    int256 public maxRecordedApy = type(int256).min;

    // Track stake weights for comparison
    uint256[] public stakeWeights;
    mapping(uint256 => bool) public seenStakeWeight;

    // Track rewards
    uint256 public minRecordedRewards = type(uint256).max;
    uint256 public maxRecordedRewards;
    uint256 public maxRecordedStakeWeight;

    // Track preview results
    mapping(uint256 => uint256) public previewAmounts;
    mapping(uint256 => int256) public previewApys;
    uint256[] public previewTimestamps;

    function recordApy(int256 apy) public {
        if (apy < minRecordedApy) {
            minRecordedApy = apy;
        }
        if (apy > maxRecordedApy) {
            maxRecordedApy = apy;
        }
    }

    function recordStakeWeight(uint256 stakeWeight) public {
        if (!seenStakeWeight[stakeWeight]) {
            stakeWeights.push(stakeWeight);
            seenStakeWeight[stakeWeight] = true;
        }
        if (stakeWeight > maxRecordedStakeWeight) {
            maxRecordedStakeWeight = stakeWeight;
        }
    }

    function recordWeeklyRewards(uint256 rewards) public {
        if (rewards < minRecordedRewards) {
            minRecordedRewards = rewards;
        }
        if (rewards > maxRecordedRewards) {
            maxRecordedRewards = rewards;
        }
    }

    function recordPreviewResults(uint256 timestamp, uint256 amount, int256 apy) public {
        previewAmounts[timestamp] = amount;
        previewApys[timestamp] = apy;
        if (!seenStakeWeight[timestamp]) {
            previewTimestamps.push(timestamp);
            seenStakeWeight[timestamp] = true;
        }
    }

    function getConsecutiveStakeWeights() public view returns (uint256, uint256) {
        // If we don't have enough weights, return 0,0 to skip comparison
        if (stakeWeights.length < 2) {
            return (0, 0);
        }

        // Sort the array (bubble sort for simplicity since this is test code)
        uint256[] memory sorted = new uint256[](stakeWeights.length);
        for (uint256 i = 0; i < stakeWeights.length; i++) {
            sorted[i] = stakeWeights[i];
        }
        for (uint256 i = 0; i < sorted.length - 1; i++) {
            for (uint256 j = 0; j < sorted.length - i - 1; j++) {
                if (sorted[j] > sorted[j + 1]) {
                    (sorted[j], sorted[j + 1]) = (sorted[j + 1], sorted[j]);
                }
            }
        }

        // Return two consecutive values from the middle of the array
        uint256 mid = sorted.length / 2;
        return (sorted[mid - 1], sorted[mid]);
    }

    function getConsecutiveTimestamps() public view returns (uint256, uint256) {
        // If we don't have enough timestamps, return 0,0 to skip comparison
        if (previewTimestamps.length < 2) {
            return (0, 0);
        }

        // Sort the array (bubble sort for simplicity since this is test code)
        uint256[] memory sorted = new uint256[](previewTimestamps.length);
        for (uint256 i = 0; i < previewTimestamps.length; i++) {
            sorted[i] = previewTimestamps[i];
        }
        for (uint256 i = 0; i < sorted.length - 1; i++) {
            for (uint256 j = 0; j < sorted.length - i - 1; j++) {
                if (sorted[j] > sorted[j + 1]) {
                    (sorted[j], sorted[j + 1]) = (sorted[j + 1], sorted[j]);
                }
            }
        }

        // Return two consecutive values from the middle of the array
        uint256 mid = sorted.length / 2;
        return (sorted[mid - 1], sorted[mid]);
    }
}
