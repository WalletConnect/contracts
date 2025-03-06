# StakingRewardsCalculator Contract Documentation

## Overview

The `StakingRewardsCalculator` contract implements a dynamic APY model for calculating and injecting weekly staking
rewards. It uses Thursday 00:00 UTC snapshots and a linear APY model that adjusts based on total stake weight, ensuring
fair distribution while incentivizing longer staking periods.

## Core Mechanisms

### 1. Weekly Cycle Management

- All operations align to Thursday 00:00 UTC boundaries
- Uses `_timestampToFloorWeek` for consistent timestamp alignment
- Prevents manipulation through fixed weekly boundaries
- Maintains strict ordering: no future weeks, allows historical weeks

### 2. Dynamic APY System

```solidity
// Core formula (all values scaled by 1e18)
APY = max(SCALED_SLOPE * (totalStakeWeight / MILLION) + INTERCEPT, 0)

where:
SCALED_SLOPE = -6464 * 1e13  // -0.06464
INTERCEPT    = 120_808 * 1e14 // 12.0808%
```

Key properties:

- Linear decrease: -0.06464% per 1M increase in stake weight
- Base rate: 12.0808% at 0 stake
- Floor: 0% minimum APY
- Example: At 10M stake → APY ≈ 11.43%

### 3. Weekly Rewards Calculation

```solidity
weeklyRewards = (totalStakeWeight * 4 * targetApy) / (52 * 1e18 * 100)

where:
totalStakeWeight = current total stake weight with lock periods
4              = multiplier to convert stake weight to equivalent annual staked tokens
targetApy      = APY calculated from linear model (e.g., 12% = 12e18)
52             = weeks in year
100            = percentage to decimal conversion
1e18          = precision scaling factor
```

Key properties:

- Stake weight is multiplied by 4 to convert to equivalent annual staked tokens
- This ensures full APY distribution (e.g., 12% APY means exactly 12% annual rewards)
- Weekly distribution is 1/52 of the annual rewards
- Precision maintained through calculations using 1e18 scaling

## Verified Mathematical Invariants

### APY Guarantees

1. **Value Bounds**

   - Never negative: `APY >= 0`
   - Upper bound: `APY <= INTERCEPT`
   - Zero stake: `APY == INTERCEPT`

2. **Linear Properties**
   - Monotonic decrease: `APY(stake1) >= APY(stake2)` when `stake1 < stake2`
   - Linear slope: `(APY1 - APY2) = SCALED_SLOPE * (stake2 - stake1) / MILLION`

### Rewards Guarantees

1. **Value Bounds**

   - Annual limit: `weeklyRewards * 52 <= (stakeWeight * APY) / (100 * PRECISION)`
   - Zero conditions:
     ```solidity
     calculateWeeklyRewards(0, anyAPY) == 0
     calculateWeeklyRewards(anyStake, 0) == 0
     ```

2. **Proportionality**
   - Monotonic: Larger stake → larger rewards
   - Ratio preservation: `rewards1/rewards2 ≈ stake1/stake2` (within rounding)

### Preview Consistency

`previewRewards` guarantees:

1. Identical results to `calculateWeeklyRewards`
2. Same APY calculation as `calculateTargetApy`
3. Matches `injectRewardsForWeek` behavior (without state changes)

## Security Properties

### Access Control

1. **Execution Context**

   - Must be delegateCalled from authorized multisig -> hence no storage variables
   - Validates config contract address
   - Requires explicit token approvals

2. **State Protection**
   - Prevents duplicate full injections
   - Allows partial top-ups if new amount > existing
   - Enforces chronological order

### Arithmetic Safety

1. **Supply Constraints**

   - Maximum token supply: 1 billion (1e9) tokens
   - Maximum stake weight: `MAX_SUPPLY * PRECISION` (1e27)
   - All calculations bounded by these limits
   - Prevents overflow in stake weight calculations

2. **Precision Management**

   - All calculations scaled by 1e18 (PRECISION)
   - Safe type conversions via SafeCast
   - Order of operations optimized for precision
   - Handles division rounding consistently
   - Stake weights always multiples of PRECISION

3. **Overflow Protection**
   - Stake weights strictly bounded by `MAX_SUPPLY * PRECISION`
   - Safe mathematical operations
   - Validated intermediate calculations

### Timing Guarantees

1. **Timestamp Validation**

   ```solidity
   require(timestamp == _timestampToFloorWeek(timestamp), "NotThursday");
   require(timestamp <= currentThursday, "FutureWeek");
   ```

2. **Historical Accuracy**
   - Uses checkpointing for stake weights
   - Maintains accurate historical data
   - Prevents retroactive manipulation

## Error Conditions

### Revert Cases

```solidity
error NotThursday();                    // Timestamp not aligned to Thursday 00:00 UTC
error FutureWeek(uint256 requested,     // Attempted injection for future week
                 uint256 latest);
error RewardsAlreadyInjected(           // Higher/equal rewards exist
    uint256 week,
    uint256 amount
);
error NoStakeWeight();                  // No stakes exist for week
error ApprovalFailed();                 // Token approval failed
```

### Edge Cases

1. **Partial Injections**

   ```solidity
   if (existingRewards > 0) {
       if (existingRewards >= amount) {
           revert RewardsAlreadyInjected(weekStartTimestamp, existingRewards);
       }
       amount -= existingRewards;  // Top-up case
   }
   ```

2. **Zero Conditions**
   - Zero stake weight → maximum APY
   - Zero APY → zero rewards
   - Zero existing rewards → full injection

## Integration Points

### Contract Dependencies

1. **WalletConnectConfig**

   - Source of contract addresses
   - Validates configuration
   - Must be active and correct

2. **StakingRewardDistributor**
   - Receives injected rewards
   - Maintains stake weight history
   - Handles reward distribution

### Token Interactions

1. **Approvals**

   ```solidity
   IERC20(config.getL2wct()).approve(distributor, amount)
   ```

2. **Transfers**
   - Requires sufficient balance
   - Validates successful approvals
   - Handles partial amounts

## Testing Coverage

1. **Unit Tests**

   - Individual function behavior
   - Error conditions
   - Edge cases

2. **Integration Tests**

   - Full reward calculation flow
   - Injection scenarios
   - Contract interactions

3. **Invariant Tests**

   - Mathematical properties
   - State consistency
   - Timing constraints

4. **Fuzz Tests**
   - Input ranges
   - State transitions
   - Property-based assertions

## Usage Examples

### Reward Calculation Flow

```solidity
// 1. Preview rewards for next Thursday (stake weight must be <= MAX_SUPPLY * PRECISION)
uint256 nextThursday = _timestampToFloorWeek(block.timestamp + 1 weeks);
require(totalStakeWeight <= MAX_SUPPLY * PRECISION, "Exceeds max supply");

(uint256 previewAmount, int256 previewApy) = calculator.previewRewards(
    config,
    nextThursday
);

// 2. Verify APY calculation
int256 expectedApy = calculator.calculateTargetApy(totalStakeWeight);
assert(previewApy == expectedApy);

// 3. Verify reward calculation
uint256 expectedRewards = calculator.calculateWeeklyRewards(
    totalStakeWeight,
    expectedApy
);
assert(previewAmount == expectedRewards);

// 4. Inject rewards if calculations look correct
uint256 injectedAmount = calculator.injectRewardsForWeek(
    config,
    nextThursday
);
assert(injectedAmount == previewAmount);
```
