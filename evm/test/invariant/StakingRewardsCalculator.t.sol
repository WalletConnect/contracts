// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Invariant_Test } from "./Invariant.t.sol";

import { StakingRewardsCalculator } from "src/StakingRewardsCalculator.sol";
import { StakingRewardsCalculatorHandler } from "./handlers/StakingRewardsCalculatorHandler.sol";
import { StakingRewardsCalculatorStore } from "./stores/StakingRewardsCalculatorStore.sol";
import { console2 } from "forge-std/console2.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract StakingRewardsCalculator_Invariant_Test is Invariant_Test {
    StakingRewardsCalculator public calculator;
    StakingRewardsCalculatorHandler public handler;
    StakingRewardsCalculatorStore public store;

    // Constants from the contract for validation
    int256 private constant SCALED_SLOPE = (-6464 * 1e13); // -0.06464 scaled to 1e18
    int256 private constant INTERCEPT = 120_808 * 1e14; // 12.0808 scaled to 1e18
    uint256 private constant PRECISION = 1e18;
    uint256 private constant MILLION = 1e6;
    uint256 private constant MAX_SUPPLY = 1e9; // 1 billion tokens
    uint256 private constant WEEKS_IN_YEAR = 52;

    function setUp() public override {
        super.setUp();

        calculator = new StakingRewardsCalculator();
        store = new StakingRewardsCalculatorStore();
        handler = new StakingRewardsCalculatorHandler(calculator, store, wct, l2wct, walletConnectConfig);

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = handler.calculateTargetApy.selector;
        selectors[1] = handler.calculateWeeklyRewards.selector;
        selectors[2] = handler.previewRewards.selector;

        targetSelector(FuzzSelector(address(handler), selectors));
    }

    function invariant_APY_Bounds() public view {
        // APY should never be negative
        assertGe(store.minRecordedApy(), 0, "APY should never be negative");

        // APY should never exceed base rate (INTERCEPT)
        assertLe(store.maxRecordedApy(), INTERCEPT, "APY should never exceed base rate");

        // For zero stake weight, APY should equal INTERCEPT
        assertEq(calculator.calculateTargetApy(0), INTERCEPT, "APY for zero stake weight should equal base rate");
    }

    function invariant_APY_LinearDecrease() public view {
        // Get two consecutive stake weights from store
        (uint256 lowerStake, uint256 higherStake) = store.getConsecutiveStakeWeights();
        // Skip test if we don't have valid weights to compare
        if (lowerStake == 0 && higherStake == 0) return;

        if (lowerStake < higherStake) {
            int256 lowerApy = calculator.calculateTargetApy(lowerStake);
            int256 higherApy = calculator.calculateTargetApy(higherStake);

            // APY should decrease as stake weight increases
            assertGe(lowerApy, higherApy, "APY should decrease as stake weight increases");

            // Calculate raw APY values (before zero bound)
            int256 expectedLowerApy = (
                SCALED_SLOPE * SafeCast.toInt256(lowerStake / MILLION) + INTERCEPT * SafeCast.toInt256(PRECISION)
            ) / SafeCast.toInt256(PRECISION);
            int256 expectedHigherApy = (
                SCALED_SLOPE * SafeCast.toInt256(higherStake / MILLION) + INTERCEPT * SafeCast.toInt256(PRECISION)
            ) / SafeCast.toInt256(PRECISION);

            // Handle zero APY cases for both stakes
            if (expectedLowerApy <= 0) {
                assertEq(lowerApy, 0, "Lower APY should be zero when raw calculation is negative");
            } else {
                assertApproxEqAbs(lowerApy, expectedLowerApy, 2, "Lower APY should match expected");
            }

            if (expectedHigherApy <= 0) {
                assertEq(higherApy, 0, "Higher APY should be zero when raw calculation is negative");
            } else {
                assertApproxEqAbs(higherApy, expectedHigherApy, 2, "Higher APY should match expected");
            }

            // Additional verification: if lower stake gives zero APY, higher stake must also give zero APY
            if (lowerApy == 0) {
                assertEq(higherApy, 0, "If lower stake has zero APY, higher stake must also have zero APY");
            }
        }
    }

    function invariant_WeeklyRewards_Bounds() public view {
        // Weekly rewards should never exceed annual rewards
        // The calculateWeeklyRewards function uses the formula:
        // weeklyRewards = (stakeWeight * 4 * apy) / (PRECISION * 100 * WEEKS_IN_YEAR)
        uint256 maxStakeWeight = store.maxRecordedStakeWeight();
        if (maxStakeWeight > 0) {
            uint256 maxWeeklyRewards = calculator.calculateWeeklyRewards(maxStakeWeight, INTERCEPT);

            // Calculate the annual rewards using the same formula but without dividing by WEEKS_IN_YEAR
            uint256 maxAnnualRewards = (maxStakeWeight * 4 * uint256(INTERCEPT)) / (PRECISION * 100);

            assertLe(
                maxWeeklyRewards * WEEKS_IN_YEAR,
                maxAnnualRewards,
                "Weekly rewards * 52 should not exceed annual rewards"
            );
        }
    }

    function invariant_WeeklyRewards_Proportional() public view {
        // Get two stake weights from store
        (uint256 smallerStake, uint256 largerStake) = store.getConsecutiveStakeWeights();
        // Skip test if we don't have valid weights to compare
        if (smallerStake == 0 && largerStake == 0) return;

        // Only test if:
        // 1. Stakes are meaningfully different (at least 1M tokens apart)
        // 2. Larger stake is within max supply
        // 3. Stakes are not too close together (at least 2x difference)
        if (
            smallerStake > 0 && largerStake > smallerStake && largerStake <= MAX_SUPPLY * PRECISION
                && largerStake - smallerStake >= MILLION * PRECISION && largerStake >= smallerStake * 2
        ) {
            // Use actual APY instead of max APY to test real scenarios
            int256 smallerApy = calculator.calculateTargetApy(smallerStake);
            int256 largerApy = calculator.calculateTargetApy(largerStake);

            // Calculate raw APY to check if we're in the zero APY region
            int256 rawLargerApy = (
                SCALED_SLOPE * SafeCast.toInt256(largerStake / MILLION) + INTERCEPT * SafeCast.toInt256(PRECISION)
            ) / SafeCast.toInt256(PRECISION);

            if (rawLargerApy <= 0) {
                // If we're in the zero APY region (stake weight too high)
                assertEq(largerApy, 0, "APY should be zero when raw calculation is negative");
                // Skip further proportionality checks as they don't apply in zero APY region
                return;
            }

            // Both APYs should be positive since we're not in zero APY region
            assertGt(smallerApy, 0, "Smaller stake should have positive APY");
            assertGt(largerApy, 0, "Larger stake should have positive APY");

            uint256 smallerRewards = calculator.calculateWeeklyRewards(smallerStake, smallerApy);
            uint256 largerRewards = calculator.calculateWeeklyRewards(largerStake, largerApy);

            // Calculate the ratio of stakes and APYs
            // Note: The multiplication by 4 in calculateWeeklyRewards applies equally to both rewards,
            // so it doesn't affect the ratio calculation
            uint256 stakeRatio = (largerStake * PRECISION) / smallerStake;
            uint256 apyRatio = (uint256(largerApy) * PRECISION) / uint256(smallerApy);

            // The rewards ratio should be approximately equal to stake_ratio * apy_ratio
            uint256 rewardsRatio = (largerRewards * PRECISION) / smallerRewards;
            uint256 expectedRatio = (stakeRatio * apyRatio) / PRECISION;

            // Allow for small rounding differences (1%)
            assertApproxEqRel(
                rewardsRatio, expectedRatio, 0.01e18, "Rewards ratio should match stake_ratio * apy_ratio"
            );
        }
    }

    function invariant_ZeroConditions() public view {
        // Zero stake weight should always yield zero rewards regardless of APY
        assertEq(calculator.calculateWeeklyRewards(0, INTERCEPT), 0, "Zero stake weight should yield zero rewards");

        // Zero APY should always yield zero rewards regardless of stake weight
        uint256 maxStake = store.maxRecordedStakeWeight();
        assertEq(calculator.calculateWeeklyRewards(maxStake, 0), 0, "Zero APY should yield zero rewards");
    }

    function invariant_CallSummary() public view {
        console2.log("Total calls made during invariant test:", handler.totalCalls());
        console2.log("calculateTargetApy calls:", handler.calls("calculateTargetApy"));
        console2.log("calculateWeeklyRewards calls:", handler.calls("calculateWeeklyRewards"));
    }

    function invariant_PreviewRewards_MatchesCalculation() public view {
        // Get two consecutive timestamps from store
        (uint256 timestamp1, uint256 timestamp2) = store.getConsecutiveTimestamps();
        // Skip test if we don't have valid timestamps to compare
        if (timestamp1 == 0 && timestamp2 == 0) return;

        // For each timestamp, verify that preview amount matches what we'd calculate
        uint256[] memory timestamps = new uint256[](2);
        timestamps[0] = timestamp1;
        timestamps[1] = timestamp2;

        for (uint256 i = 0; i < timestamps.length; i++) {
            uint256 timestamp = timestamps[i];
            uint256 previewAmount = store.previewAmounts(timestamp);
            int256 previewApy = store.previewApys(timestamp);

            // Get the stake weight from the distributor
            uint256 stakeWeight = stakingRewardDistributor.totalSupplyAt(timestamp);
            if (stakeWeight == 0) continue;

            // Calculate expected rewards
            uint256 expectedRewards = calculator.calculateWeeklyRewards(stakeWeight, previewApy);

            // Preview amount should match calculated rewards
            assertEq(previewAmount, expectedRewards, "Preview amount should match calculated rewards");

            // Preview APY should match what we'd calculate
            assertEq(previewApy, calculator.calculateTargetApy(stakeWeight), "Preview APY should match calculated APY");
        }
    }
}
