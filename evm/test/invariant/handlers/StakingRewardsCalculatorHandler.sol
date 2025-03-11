// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakingRewardsCalculator } from "src/StakingRewardsCalculator.sol";
import { WCT } from "src/WCT.sol";
import { L2WCT } from "src/L2WCT.sol";
import { BaseHandler } from "./BaseHandler.sol";
import { StakingRewardsCalculatorStore } from "../stores/StakingRewardsCalculatorStore.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";

contract StakingRewardsCalculatorHandler is BaseHandler {
    StakingRewardsCalculator public calculator;
    StakingRewardsCalculatorStore public store;
    WalletConnectConfig public config;

    // Constants for bounds checking
    uint256 private constant MAX_SUPPLY = 1e9; // 1 billion tokens (max token supply)
    uint256 private constant PRECISION = 1e18;
    uint256 private constant MILLION = 1e6;
    int256 private constant INTERCEPT = 120_808 * 1e14; // 12.0808 scaled to 1e18

    constructor(
        StakingRewardsCalculator _calculator,
        StakingRewardsCalculatorStore _store,
        WCT _wct,
        L2WCT _l2wct,
        WalletConnectConfig _config
    )
        BaseHandler(_wct, _l2wct)
    {
        calculator = _calculator;
        store = _store;
        config = _config;

        // Record some initial stake weights to ensure we have enough data for comparisons
        _recordInitialStakeWeights();
    }

    function _recordInitialStakeWeights() internal {
        // Record zero stake weight
        _calculateAndRecordApy(0);

        // Record 1M stake weight
        _calculateAndRecordApy(MILLION * PRECISION);

        // Record half max supply
        _calculateAndRecordApy((MAX_SUPPLY / 2) * PRECISION);

        // Record max supply
        _calculateAndRecordApy(MAX_SUPPLY * PRECISION);
    }

    function _calculateAndRecordApy(uint256 stakeWeight) internal {
        // Ensure stake weight never exceeds max supply
        require(stakeWeight <= MAX_SUPPLY * PRECISION, "Stake weight exceeds max supply");

        int256 apy = calculator.calculateTargetApy(stakeWeight);
        store.recordApy(apy);
        store.recordStakeWeight(stakeWeight);
    }

    function calculateTargetApy(uint256 stakeWeight) public {
        // Bound stake weight to max supply and ensure it's a multiple of PRECISION
        stakeWeight = bound(stakeWeight, 0, MAX_SUPPLY * PRECISION);
        stakeWeight = (stakeWeight / PRECISION) * PRECISION;

        _calculateAndRecordApy(stakeWeight);

        calls["calculateTargetApy"]++;
        totalCalls++;
    }

    function calculateWeeklyRewards(uint256 stakeWeight, int256 apy) public {
        // Bound stake weight to max supply and ensure it's a multiple of PRECISION
        stakeWeight = bound(stakeWeight, 0, MAX_SUPPLY * PRECISION);
        stakeWeight = (stakeWeight / PRECISION) * PRECISION;

        // Calculate actual APY for this stake weight to ensure realistic APY values
        apy = calculator.calculateTargetApy(stakeWeight);

        uint256 rewards = calculator.calculateWeeklyRewards(stakeWeight, apy);
        store.recordWeeklyRewards(rewards);
        store.recordStakeWeight(stakeWeight);

        calls["calculateWeeklyRewards"]++;
        totalCalls++;
    }

    function previewRewards(uint256 timestamp) public {
        // Use current block timestamp as base to ensure we don't test future timestamps
        uint256 currentThursday = _timestampToFloorWeek(block.timestamp);
        timestamp = bound(timestamp, 0, currentThursday);
        timestamp = _timestampToFloorWeek(timestamp);

        // Preview rewards and record results
        (uint256 amount, int256 targetApy) = calculator.previewRewards(address(config), timestamp);
        store.recordPreviewResults(timestamp, amount, targetApy);

        calls["previewRewards"]++;
        totalCalls++;
    }
}
