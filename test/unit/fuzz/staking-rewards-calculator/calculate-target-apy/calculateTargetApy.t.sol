// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Test } from "forge-std/Test.sol";
import { StakingRewardsCalculator } from "src/StakingRewardsCalculator.sol";

contract CalculateWeeklyRewards_StakingRewardsCalculator_Unit_Fuzz_Test is Test {
    StakingRewardsCalculator public calculator;

    // Constants from the contract for validation
    int256 private constant SCALED_SLOPE = (-6464 * 1e13); // -0.06464 scaled to 1e18
    int256 private constant INTERCEPT = 120_808 * 1e14; // 12.0808 scaled to 1e18
    uint256 private constant PRECISION = 1e18;
    uint256 private constant MILLION = 1e6;
    uint256 private constant MAX_SUPPLY = 1e9; // 1 billion tokens

    function setUp() public {
        calculator = new StakingRewardsCalculator();
    }

    /// @dev Test APY calculation with zero stake weight
    function testFuzz_ZeroStakeWeight() public view {
        int256 apy = calculator.calculateTargetApy(0);
        assertEq(apy, INTERCEPT, "APY should equal base rate for zero stake");
    }

    /// @dev Test APY calculation with stake weight less than 1M
    function testFuzz_LessThanOneMillion(uint256 stakeWeight) public view {
        vm.assume(stakeWeight > 0 && stakeWeight < MILLION * PRECISION);

        int256 apy = calculator.calculateTargetApy(stakeWeight);

        // APY should be less than or equal to base APY
        assertLe(apy, INTERCEPT, "APY should not exceed base rate");
        // APY should be greater than 0
        assertGt(apy, 0, "APY should be positive");
    }

    /// @dev Test APY calculation with stake weight greater than 1M
    function testFuzz_GreaterThanOneMillion(uint256 stakeWeight) public view {
        // Bound stake weight between 1M and max supply to avoid overflows
        stakeWeight = bound(stakeWeight, MILLION * PRECISION, MAX_SUPPLY * PRECISION);

        int256 apy = calculator.calculateTargetApy(stakeWeight);
        int256 expectedApy =
            (SCALED_SLOPE * int256(stakeWeight / MILLION) + INTERCEPT * int256(PRECISION)) / int256(PRECISION);

        if (expectedApy <= 0) {
            assertEq(apy, 0, "APY should be zero when calculation results in negative value");
        } else {
            // Allow for small rounding differences
            int256 difference = apy - expectedApy;
            assertTrue(difference >= -1 && difference <= 1, "APY calculation mismatch");
        }
    }

    /// @dev Test minimum APY bound
    function testFuzz_MinimumBound(uint256 stakeWeight) public view {
        // Bound to max possible stake weight
        stakeWeight = bound(stakeWeight, 0, MAX_SUPPLY * PRECISION);

        int256 apy = calculator.calculateTargetApy(stakeWeight);
        assertGe(apy, 0, "APY should never be negative");
    }
}
