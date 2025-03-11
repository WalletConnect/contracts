// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { StakingRewardsCalculator } from "src/StakingRewardsCalculator.sol";

contract CalculateTargetApy_StakingRewardsCalculator_Unit_Concrete_Test is Test {
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

    /// @dev Test raw APY calculation at max supply
    function test_RawApyCalculation() public pure {
        uint256 maxStakeWeight = MAX_SUPPLY * PRECISION;

        // Calculate raw APY (before zero bound)
        int256 rawApy =
            (SCALED_SLOPE * int256(maxStakeWeight / MILLION) + INTERCEPT * int256(PRECISION)) / int256(PRECISION);

        // At max supply (1B tokens), raw APY should be:
        // (-0.06464 * 1000 + 12.0808) = -52.5592
        assertEq(rawApy, -52_559_200_000_000_000_000, "Raw APY calculation at max supply is incorrect");

        console2.log("Raw APY at max supply:", uint256(uint256(rawApy)));
    }

    /// @dev Test final APY (after zero bound) at max supply
    function test_FinalApyIsZero() public view {
        uint256 maxStakeWeight = MAX_SUPPLY * PRECISION;
        int256 finalApy = calculator.calculateTargetApy(maxStakeWeight);

        // Final APY should be 0 since negative values are not allowed
        assertEq(finalApy, 0, "Final APY should be zero at max supply");

        console2.log("Final APY at max supply:", uint256(uint256(finalApy)));
    }
}
