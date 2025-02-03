// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { WalletConnectConfig } from "./WalletConnectConfig.sol";
import { StakingRewardDistributor } from "./StakingRewardDistributor.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @title StakingRewardsCalculator
 * @author WalletConnect
 * @notice This contract calculates and injects weekly staking rewards based on Thursday 00:00 UTC snapshots
 * @dev Designed to be delegateCalled from a multisig to execute reward calculations and injections
 *
 * The contract implements a dynamic APY model that adjusts based on total stake weight:
 * - APY = (SCALED_SLOPE * totalStakeWeightInMillions + INTERCEPT)
 * - Example: At 10M total stake, APY ≈ 11.43%
 * - Bounded by MIN_APY floor (0%)
 *
 * Key features:
 * - Weekly reward snapshots taken every Thursday at 00:00 UTC
 * - Rewards calculated using linear APY model based on total stake weight
 * - Prevents duplicate reward injections for same week
 * - Prevents future week reward injections
 * - Uses checkpointing for accurate historical stake weight
 *
 * Security considerations:
 * - Must be delegateCalled from authorized multisig
 * - Requires sufficient token approval for reward distribution
 * - Relies on accurate stake weight checkpointing
 */
contract StakingRewardsCalculator {
    // Constants for reward calculation
    /// @dev Number of weeks in a year for weekly reward calculation
    uint256 private constant WEEKS_IN_YEAR = 52;
    /// @dev Precision factor for decimal calculations (1e18)
    uint256 private constant PRECISION = 1e18;
    /// @dev Divisor to convert stake weight to millions for APY calculation
    uint256 private constant MILLION = 1e6;

    // APY formula coefficients (multiplied by 1e18)
    /// @dev Slope of APY linear function: -0.06464 (scaled to 1e18)
    /// @dev For each 1M increase in stake weight, APY decreases by 0.06464%
    int256 private constant SCALED_SLOPE = (-6464 * 1e13);
    /// @dev Y-intercept of APY linear function: 12.0808% (scaled to 1e18)
    /// @dev Base APY when total stake weight is 0
    int256 private constant INTERCEPT = 120_808 * 1e14;
    /// @dev Minimum APY floor (0%), preventing negative APY
    int256 private constant MIN_APY = 0;

    /*//////////////////////////////////////////////////////////////////////////
                                    ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when timestamp isn't a Thursday 00:00 UTC
    /// @dev Used to enforce weekly reward schedule alignment
    error NotThursday();

    /// @notice Thrown when trying to inject for a future week
    /// @dev Prevents premature reward injections
    /// @param requestedTimestamp The requested week's timestamp
    /// @param latestPossible The current week's Thursday timestamp (latest possible)
    error FutureWeek(uint256 requestedTimestamp, uint256 latestPossible);

    /// @notice Thrown when rewards already exist for week
    /// @dev Prevents double-injection of rewards
    /// @param weekTimestamp The week's timestamp
    /// @param existingAmount The amount already injected
    error RewardsAlreadyInjected(uint256 weekTimestamp, uint256 existingAmount);

    /// @notice Thrown when token approval fails
    /// @dev Indicates insufficient allowance or token transfer issues
    error ApprovalFailed();

    /// @notice Thrown when no stake weight exists
    /// @dev Prevents reward calculation with zero stake weight
    error NoStakeWeight();

    /*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Calculate and inject rewards for a specific week
    /// @dev Main entry point for reward distribution
    /// @dev Process:
    /// @dev 1. Validates Thursday timestamp and prevents future/duplicate injections
    /// @dev 2. Checkpoints total supply for accurate historical data
    /// @dev 3. Calculates dynamic APY based on total stake weight
    /// @dev 4. Calculates weekly rewards and handles token approvals
    /// @dev 5. Injects rewards into the distributor contract
    /// @param config The address of the WalletConnectConfig contract
    /// @param weekStartTimestamp The Thursday 00:00 UTC start of the week
    /// @return amount The amount of rewards injected in wei
    function injectRewardsForWeek(address config, uint256 weekStartTimestamp) external returns (uint256) {
        // Validate Thursday timestamp
        if (weekStartTimestamp != _timestampToFloorWeek(weekStartTimestamp)) revert NotThursday();

        // Get current Thursday and validate not future week
        uint256 currentThursday = _timestampToFloorWeek(block.timestamp);
        if (weekStartTimestamp > currentThursday) {
            revert FutureWeek(weekStartTimestamp, currentThursday);
        }

        // Get contracts and checkpoint
        WalletConnectConfig wcConfig = WalletConnectConfig(config);
        StakingRewardDistributor distributor = StakingRewardDistributor(wcConfig.getStakingRewardDistributor());
        distributor.checkpointTotalSupply();

        // Get cached total stake weight from distributor
        uint256 totalStakeWeight = distributor.totalSupplyAt(weekStartTimestamp);
        if (totalStakeWeight == 0) revert NoStakeWeight();

        // Calculate rewards
        int256 targetApy = calculateTargetApy(totalStakeWeight);
        uint256 amount = calculateWeeklyRewards(totalStakeWeight, targetApy);

        // Check for existing rewards
        uint256 existingRewards = distributor.tokensPerWeek(weekStartTimestamp);
        if (existingRewards > 0) {
            if (existingRewards >= amount) {
                revert RewardsAlreadyInjected(weekStartTimestamp, existingRewards);
            } else {
                // Inject rewards
                amount -= existingRewards;
            }
        }

        // Approve tokens for distributor
        IERC20 token = IERC20(wcConfig.getL2wct());
        bool success = token.approve(address(distributor), amount);
        if (!success) revert ApprovalFailed();

        // Inject rewards
        distributor.injectReward(weekStartTimestamp, amount);

        return amount;
    }

    /// @notice Preview rewards for a given week without injecting
    /// @dev Useful for off-chain calculations and verification
    /// @dev Uses the same calculation logic as injectRewardsForWeek but without state changes
    /// @dev Returns both the reward amount and target APY for transparency
    /// @param config The address of the WalletConnectConfig contract
    /// @param weekStartTimestamp The Thursday 00:00 UTC to preview
    /// @return amount The amount that would be injected in wei
    /// @return targetApy The APY that would be used (scaled by 1e18)
    function previewRewards(
        address config,
        uint256 weekStartTimestamp
    )
        external
        returns (uint256 amount, int256 targetApy)
    {
        // Validate Thursday timestamp
        if (weekStartTimestamp != _timestampToFloorWeek(weekStartTimestamp)) revert NotThursday();

        // Get contracts and checkpoint
        WalletConnectConfig wcConfig = WalletConnectConfig(config);
        StakingRewardDistributor distributor = StakingRewardDistributor(wcConfig.getStakingRewardDistributor());
        distributor.checkpointTotalSupply();

        // Get cached total stake weight from distributor
        uint256 totalStakeWeight = distributor.totalSupplyAt(weekStartTimestamp);
        if (totalStakeWeight == 0) revert NoStakeWeight();

        // Calculate rewards
        targetApy = calculateTargetApy(totalStakeWeight);
        amount = calculateWeeklyRewards(totalStakeWeight, targetApy);

        return (amount, targetApy);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Calculate target APY based on total stake weight
    /// @dev Implements linear APY model: APY = slope * totalStakeWeightInMillions + intercept
    /// @dev Result is bounded by MIN_APY (0%) floor
    /// @param totalStakeWeight Total stake weight considering lock periods (in wei)
    /// @return Target APY percentage scaled by 1e18 (e.g., 12% = 12e18)
    function calculateTargetApy(uint256 totalStakeWeight) public pure returns (int256) {
        // totalStakeWeight needs to be divided by MILLION first to get to millions unit
        int256 targetApy = (
            (SCALED_SLOPE * SafeCast.toInt256(totalStakeWeight / MILLION)) + INTERCEPT * SafeCast.toInt256(PRECISION)
        ) / SafeCast.toInt256(PRECISION);

        return targetApy > MIN_APY ? targetApy : MIN_APY;
    }

    /// @dev Calculate weekly rewards based on total stake weight and APY
    /// @dev Formula: weeklyRewards = (totalStakeWeight * targetApy) / (52 * 1e18 * 100)
    /// @dev The division by 100 converts percentage to decimal
    /// @param actualTotalStakeWeight Current total stake weight considering lock periods (in wei)
    /// @param targetApy Target APY calculated from stake weight curve (in wei, e.g., 12% = 12e18)
    /// @return weeklyRewards Amount of tokens to distribute for the week in wei
    function calculateWeeklyRewards(
        uint256 actualTotalStakeWeight,
        int256 targetApy
    )
        public
        pure
        returns (uint256 weeklyRewards)
    {
        uint256 annualRewardsWithPrecision = (actualTotalStakeWeight * uint256(targetApy));

        // Step 4: Convert annual rewards to weekly rewards
        weeklyRewards = annualRewardsWithPrecision / (PRECISION * 100 * WEEKS_IN_YEAR);

        return weeklyRewards;
    }

    /// @dev Round off random timestamp to week boundary (Thursday 00:00 UTC)
    /// @param timestamp The timestamp to be rounded off
    /// @return The Thursday 00:00 UTC timestamp for the given week
    function _timestampToFloorWeek(uint256 timestamp) internal pure returns (uint256) {
        return (timestamp / 1 weeks) * 1 weeks;
    }
}
