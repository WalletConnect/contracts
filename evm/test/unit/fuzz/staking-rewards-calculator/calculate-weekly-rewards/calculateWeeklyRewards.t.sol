// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Test } from "forge-std/Test.sol";
import { StakingRewardsCalculator } from "src/StakingRewardsCalculator.sol";

contract CalculateWeeklyRewards_StakingRewardsCalculator_Unit_Fuzz_Test is Test {
    StakingRewardsCalculator public calculator;

    // Constants from the contract for validation
    int256 private constant INTERCEPT = 120_808 * 1e14; // 12.0808 scaled to 1e18
    uint256 private constant PRECISION = 1e18;
    uint256 private constant MILLION = 1e6;
    uint256 private constant WEEKS_IN_YEAR = 52;
    uint256 private constant MAX_SUPPLY = 1e9; // 1 billion tokens

    function setUp() public {
        calculator = new StakingRewardsCalculator();
    }

    /// @dev Test weekly rewards with zero stake weight
    function testFuzz_ZeroStakeWeight(int256 apy) public view {
        uint256 rewards = calculator.calculateWeeklyRewards(0, apy);
        assertEq(rewards, 0, "Zero stake should yield zero rewards");
    }

    /// @dev Test weekly rewards with zero APY
    function testFuzz_ZeroApy(uint256 stakeWeight) public view {
        // Bound to max possible stake weight
        stakeWeight = bound(stakeWeight, 0, MAX_SUPPLY * PRECISION);

        uint256 rewards = calculator.calculateWeeklyRewards(stakeWeight, 0);
        assertEq(rewards, 0, "Zero APY should yield zero rewards");
    }

    /// @dev Test weekly rewards calculation with positive values
    function testFuzz_PositiveValues(uint256 stakeWeight, uint256 rawApy) public view {
        // Bound inputs to realistic values to avoid overflows
        stakeWeight = bound(stakeWeight, 1, MAX_SUPPLY * PRECISION);
        rawApy = bound(rawApy, 1, uint256(INTERCEPT));

        uint256 rewards = calculator.calculateWeeklyRewards(stakeWeight, int256(rawApy));

        // Calculate expected rewards with 4x multiplier
        uint256 expectedAnnualRewards = (stakeWeight * 4 * rawApy);
        uint256 expectedWeeklyRewards = (expectedAnnualRewards / WEEKS_IN_YEAR) / (PRECISION * 100);

        assertEq(rewards, expectedWeeklyRewards, "Weekly rewards calculation mismatch");
    }

    /// @dev Test weekly rewards with maximum APY
    function testFuzz_MaximumApy(uint256 stakeWeight) public view {
        // Bound stake weight to max supply (start at 1e3 to avoid 0 rewards, which would be expected)
        stakeWeight = bound(stakeWeight, 1e3, MAX_SUPPLY * PRECISION);

        uint256 rewards = calculator.calculateWeeklyRewards(stakeWeight, INTERCEPT);

        // Verify no overflow occurred and rewards make sense
        assertTrue(rewards > 0, "Rewards should be positive for maximum APY");
        assertTrue(rewards < stakeWeight * 4, "Weekly rewards should be less than 4x total stake");

        // Calculate expected maximum rewards with 4x multiplier
        uint256 expectedAnnualRewards = (stakeWeight * 4 * uint256(INTERCEPT));
        uint256 expectedWeeklyRewards = (expectedAnnualRewards / WEEKS_IN_YEAR) / (PRECISION * 100);
        assertEq(rewards, expectedWeeklyRewards, "Maximum rewards calculation mismatch");
    }
}
