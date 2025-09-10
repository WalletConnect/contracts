# P3 - WCT Staking Redesign

> “Perpetual Stake with User-Triggered Unlocking & Simplified Duration Options”

### Summary

We propose a redesign of the WCT staking mechanism to simplify usage, improve reward predictability, and provide greater
flexibility to users. This includes the introduction of **Perpetual Staking Positions with User-Triggered Unlocking
Periods**, a **set of discrete duration options for creating positions**, and **preserved support for the current
decaying model** as an optional path.

**Current Implementation**

---

![image.png](attachment:a4a4172a-c5ee-4df5-adaa-24e82190eda7:image.png)

**Chart Description:**

This chart visualizes the current staking mechanism, where two positions—Position A (12-month duration) and Position B
(6-month duration)—are created simultaneously at T₀. Upon creation, both positions immediately enter their respective
unstake periods. From that point forward, their stake weight begins to decrease gradually each week until it reaches
zero, at which time the position becomes unlocked.

The unlock timing is determined solely by the duration set at creation: Position B unlocks at T₀ + 6 months, while
Position A unlocks at T₀ + 12 months. As shown in the chart, Position B maintains a consistently lower stake weight than
Position A throughout its lifecycle, reflecting the shorter commitment period.

**Proposed Improvement**

---

![image.png](attachment:4b74a4ba-cee6-40ce-8058-113aea91642f:image.png)

**_Chart Description:_**

_The chart compares two staking positions initiated simultaneously: one with a 6-month unlock period and the other with
a 12-month unlock period. Both positions are unstaked at the same time. Throughout the staking lifecycle, the chart
illustrates that the stake weight of the 6-month position remains consistently lower than that of the 12-month position.
Additionally, it highlights that the 6-month position becomes fully unlocked 6 months earlier than the 12-month
position, emphasizing the trade-off between shorter commitment and reduced stake weight._

---

### Current Issues with WCT Staking

The current WCT staking model presents several pain points:

- **Stakeweight Decay from Day One**: Stakeweight starts decaying immediately after a position is created, reducing user
  incentives over time.
- **Maintenance Overhead**: To maintain maximum stakeweight, users must frequently update staking positions.
- **Reward Complexity**: Decay-based rewards make it difficult to calculate expected yields without specialized tools or
  knowledge.
- **Over-flexible Duration Input**: Users currently must select a precise duration between 1–104 weeks, which
  complicates the staking decision-making process.

---

### Proposed Improvements

### 1. **Perpetual Staking Positions**

- Users can stake WCT into **perpetual positions** that do **not decay over time**, maintaining **full stakeweight**
  until the user chooses to unstake.
- These positions remain active and productive indefinitely, offering a "set-and-forget" staking experience.

### 2. **User-Triggered Unlocking Period**

- Users can initiate an **unlocking period** whenever they decide to exit their position.
- Upon triggering, the stakeweight will **decay linearly over the selected unlocking duration**, at the end of which the
  position becomes fully withdrawable.

### 3. **Discrete Duration Options**

To simplify both position creation and exit logic, we propose replacing the flexible duration model (any value between
1–104 weeks) with a curated set of predefined options:

- **4 weeks** (≈ 1 month)
- **8 weeks** (≈ 2 months)
- **12 weeks** (≈ 3 months)
- **26 weeks** (6 months)
- **52 weeks** (12 months)
- **78 weeks** (18 months)
- **104 weeks** (24 months)

These discrete values provide consistency and clarity, enabling users to better understand the impact of their staking
choices and compare rewards across options.

### 4. **Preserving Optionality**

While the new model simplifies and enhances staking for the majority, we recognize that some users may prefer the
original behavior (i.e. decay starting from position creation). To respect this:

- Users will still be able to **immediately initiate the unlocking period upon staking**, mimicking the existing flow.
- This ensures full **backward compatibility** and **user choice**, making the staking system more inclusive and
  customizable.

### 5. **Migration Path**

In order to ensure that this staking redesign does not impact existing staking positions we will be treating these
staking positions as already unlocking therefore they will not be become perpetual as the staking contract is updated.
This way there isn't any requirements from stakers to manage or update their positions so tokens will be unlocked as
soon as the decay completes.

If any staker wishes to turn their staking position to perpetual staking then they have the possibility to re-stake
after the contract is updated which will cancel their current unlocking period. Afterwards they will need to initiate
the new unlocking period that will begin decaying again.

### 6. **Institutional Integration (BitGo/Magna)**

Our largest stakers use institutional custody solutions through BitGo and vesting contracts through Magna. These
integrations remain **fully compatible** with the P3 redesign:

#### Current Institutional Flow (Unchanged)

1. **Vested tokens** are managed by MerkleVester (Magna)
2. **Staking without transfer** via LockedTokenStaker
3. Creates **traditional decaying positions** (veCRV-style)

#### New Perpetual Option for Institutions

Institutional stakers can access perpetual positions through a two-step process:

1. **Step 1**: Use existing LockedTokenStaker (creates decaying position)
2. **Step 2**: Call `convertToPerpetual(duration)` to convert to perpetual

This approach:

- ✅ **Zero breaking changes** to existing integrations
- ✅ **No modifications** to audited LockedTokenStaker contract
- ✅ **Optional migration** - institutions can stay with decaying if preferred
- ✅ **Maintains security** - tokens remain locked throughout

#### Example: Institutional Whale Migration

```
Current: 1M WCT vested, weekly renewal for max weight
Step 1: LockedTokenStaker creates decaying position (existing flow)
Step 2: convertToPerpetual(104 weeks) → 1M weight perpetual
Result: No more weekly renewals, constant maximum weight
```

This design ensures our largest stakeholders can migrate smoothly without any changes to their existing custody or
vesting infrastructure.

### 7. **Reward Distribution Continuity**

The P3 redesign ensures **complete reward continuity** for all users, regardless of when or how they interact with the
system.

#### Seamless Reward Flow

Users converting to perpetual maintain full reward continuity through our hybrid claim system:

- **Historical rewards (pre-conversion)**: All unclaimed rewards from decaying periods remain fully claimable using
  checkpoint-based calculations
- **Conversion week**: Time-weighted proportional rewards based on exact conversion timestamp
- **Future rewards (post-conversion)**: Perpetual weight applied consistently for all future distributions

#### Critical: The 50-Week Unclaimed Scenario

For users with extensive unclaimed history:

```
Scenario: User with 50 weeks unclaimed rewards converts to perpetual
- Weeks 1-50: Calculated using historical decay formulas (preserved)
- Week 51 (conversion): Pro-rated based on conversion timestamp
  - Monday-Wednesday (decay): 500 weight × 2.5/7 days
  - Wednesday-Sunday (perpetual): 1000 weight × 4.5/7 days
- Week 52+: Full perpetual weight (1000) for rewards

Result: 100% of entitled rewards claimable, zero loss
```

#### Technical Implementation

The StakingRewardDistributor uses a dual-path system:

1. **Total Supply Tracking**: Combines decaying supply (from checkpoints) + perpetual supply (from snapshots)
2. **Smart Claim Routing**: Detects user type and routes to appropriate calculation
3. **Hybrid Claims**: Handles users who converted with three-phase approach
4. **Mid-Week Precision**: Time-weighted calculations for conversion weeks

#### Key Guarantees

- ✅ **No reward loss** during conversion
- ✅ **Historical preservation** of all unclaimed rewards
- ✅ **Accurate pro-rating** for partial weeks
- ✅ **Gas-efficient** claiming (same iteration limits)

---

### Benefits

- 🧠 **Simplified UX**: Clearer options and no forced updates reduce friction for less experienced users.
- ⏳ **Constant Stakeweight**: Eliminates unnecessary reward decay until users are ready to exit.
- 🔓 **Flexible Exits**: Unlocking periods remain customizable with fixed durations and predictable timelines.
- ✅ **Optional Legacy Behavior**: Advanced users retain access to current decaying mechanics if preferred.

---

### Implementation Considerations

- **Smart Contract Updates**:
  - Enable creation of perpetual positions.
  - Introduce user-triggered unlocking with fixed duration choices.
  - Maintain support for initiating the unlock period at the time of staking.
- **Frontend Enhancements**:
  - Update UI to clearly present perpetual vs. unlocking state.
  - Add dropdown selectors for the predefined durations.
  - Visualize estimated rewards and unlocking timelines.

---

### Next Steps

1. Protocol team to review and scope smart contract changes.
2. UX team to design updated staking flows with dual-mode support.
3. Initiate on-chain vote and communication campaign.

---

### Vote Options

- ✅ **YES** – Adopt the proposed staking improvements with perpetual positions, user-triggered unlocking, and discrete
  duration options while preserving support for legacy decay behavior.
- ❌ **NO** – Maintain the current staking mechanism as-is.
