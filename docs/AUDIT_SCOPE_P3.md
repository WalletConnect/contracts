# P3 Staking Redesign – Comprehensive Audit Scope & Security Requirements

## Document Purpose

This document serves as the primary technical specification for auditing the P3 staking redesign. It defines security
requirements, threat models, invariants, and testing priorities for `StakeWeight.sol`, `StakingRewardDistributor.sol`,
and `LockedTokenStaker.sol`. This document accompanies `P3_STAKING_REDESIGN.md` (product specification) and should be
the primary reference for security auditors.

## Executive Summary

The P3 redesign introduces permanent (non-decaying) staking positions to the existing ve-style staking system. This is a
high-risk upgrade to production contracts managing user funds with complex interconnected state machines. The system
must maintain backward compatibility while preventing critical vulnerabilities.

### Primary Security Concerns (Must Address)

1. **Early Withdrawal Prevention** – Users must not be able to withdraw locked funds before maturity
2. **Reward System Integrity** – No gaming/exploitation of weekly reward distribution
3. **Data Corruption Prevention** – Historical checkpoints must remain consistent across all operations
4. **Storage Layout Safety** – Proxy upgrades must not corrupt existing user positions
5. **Fund Recovery Guarantees** – No scenarios where user funds become permanently locked

### Audit Deliverables Required

- [ ] Storage layout analysis with slot-by-slot comparison
- [ ] Formal verification of critical invariants
- [ ] Attack vector analysis with proof-of-concepts
- [ ] Gas optimization recommendations
- [ ] Operational security runbook

## System Architecture Overview

### Contract Interactions

```
User → StakeWeight ← StakingRewardDistributor
         ↑                    ↓
    LockedTokenStaker    L2WCT Token
         ↑
    MerkleVester (Magna)
```

### State Machine Complexity

- **3 lock types**: Decaying, Permanent, Vesting-originated
- **4 transition paths**: Create → Lock → Convert → Unlock → Withdraw
- **2 reward paths**: Decaying bias calculation, Permanent weight lookup
- **3 admin operations**: Force withdraw, Kill distributor, Pause system

## Critical Security Requirements

### 1. Early Withdrawal Prevention

**Requirement**: Users MUST NOT withdraw before lock expiry except via admin intervention.

**Enforcement Points**:

- `withdrawAll()`: Checks `lock.end > block.timestamp` → reverts with `LockStillActive`
- `withdrawAllFor()`: Additional check for permanent locks → reverts if `isPermanent[user]`
- Permanent locks: Cannot withdraw until `triggerUnlock()` + wait period

**Audit Focus**:

```solidity
// These conditions MUST hold:
assert(lock.end == 0 || lock.end > block.timestamp || amount == 0);
assert(!isPermanent[user] || admin_called);
```

**Attack Vectors to Test**:

- Timestamp manipulation near week boundaries
- Reentrancy during state transitions
- Integer overflow/underflow in end time calculations
- Race conditions between convert/unlock/withdraw

### 2. Reward Gaming Prevention

**Requirement**: Users MUST NOT manipulate their share of weekly rewards unfairly.

**Critical Properties**:

- Week alignment: All operations floor to week boundary
- No retroactive rewards: Cannot claim for weeks before first lock
- Conservation: `Σ(user_claims) ≤ tokensPerWeek[week]`
- Conversion fairness: Mid-week conversions properly split rewards

**Audit Focus**:

```solidity
// Invariants that MUST hold:
assert(claimable_week >= first_lock_week);
assert(user_balance_at_week / total_supply_at_week <= 1);
assert(permanent_weight + decaying_weight == user_total_weight);
```

**Attack Vectors to Test**:

- Flash loan attacks at week boundaries
- Sandwich attacks around reward injection
- Double-claiming via convert/unconvert in same week
- Precision loss accumulation over many claims

### 3. Data Integrity & Checkpoint Consistency

**Requirement**: Historical data MUST remain accurate and queryable after any state change.

**Checkpoint Rules**:

- Two-phase for conversions: Zero then restore
- Parallel histories: Permanent snapshots align with epochs
- Slope changes: Only for non-permanent endpoints
- Array bounds: Max 255 iterations (5 years)

**Audit Focus**:

```solidity
// Critical invariants:
assert(pointHistory[epoch].timestamp <= block.timestamp);
assert(userPointHistory[user][epoch].bias >= 0);
assert(permanentSupply == Σ(user_permanent_weights));
```

**Corruption Scenarios to Test**:

- Checkpoint during max iterations
- Parallel updates to same epoch
- Historical queries during conversion
- Admin force withdraw mid-checkpoint

### 4. Storage Layout & Upgrade Safety

**Requirement**: Proxy upgrades MUST NOT corrupt existing storage.

**Storage Architecture**:

```solidity
struct StakeWeightStorage { // ERC-7201 namespaced
    // Existing fields (DO NOT MODIFY)
    WalletConnectConfig config;
    uint256 supply;
    mapping(address => LockedBalance) locks;
    // ... other original fields ...

    // ─── NEW FIELDS ONLY BELOW THIS LINE ───
    mapping(address => bool) isPermanent;
    mapping(address => uint256) permanentBaseWeeks;
    mapping(address => uint256) permanentStakeWeight;
    uint256 permanentTotalSupply;
    // ... other permanent fields ...
}
```

**Upgrade Checklist**:

- [ ] No reordering of existing fields
- [ ] No type changes to existing fields
- [ ] New fields only appended at end
- [ ] Initializer not re-callable
- [ ] No storage gaps consumed incorrectly

**Tools Required**:

- Storage layout differ (Foundry/Hardhat)
- Slot calculator for collision detection
- Upgrade simulation on forked mainnet

### 5. Fund Locking Prevention

**Requirement**: User funds MUST always be recoverable (by user after expiry or admin in emergency).

**Recovery Paths**:

1. **Normal**: Lock expires → `withdrawAll()` → funds returned
2. **Permanent**: `triggerUnlock()` → wait → `withdrawAll()`
3. **Emergency**: Admin `forceWithdrawAll()` → funds returned
4. **Vesting**: Allocation claimed → lock created → normal path
5. **Killed Distributor**: `kill()` → remaining rewards to `emergencyReturn`

**Stuck Fund Scenarios to Test**:

- Permanent lock with lost private key (admin recoverable?)
- Contract paused indefinitely
- Distributor killed mid-claim
- Integer overflow making withdrawal impossible
- Reentrancy locking funds in contract

## Invariants for Formal Verification

### Global Invariants

```solidity
// G1: Supply Conservation
invariant totalSupply == Σ(user_locked_amounts)

// G2: Reward Conservation
invariant totalDistributed <= Σ(tokensPerWeek)

// G3: Time Monotonicity
invariant ∀ epoch: pointHistory[epoch].timestamp <= pointHistory[epoch+1].timestamp

// G4: Weight Bounds
invariant ∀ user: balanceOf(user) <= locked[user].amount
```

### State Transition Invariants

```solidity
// S1: Lock Creation
pre: locks[user].amount == 0
post: locks[user].amount > 0 && supply_increased

// S2: Permanent Conversion
pre: !isPermanent[user] && lock.end > 0
post: isPermanent[user] && lock.end == 0 && weight_preserved

// S3: Force Withdraw
pre: any_state
post: locks[user].amount == 0 && transferredAmount_returned
```

## Attack Surface Analysis

### External Entry Points (Highest Risk)

1. `createLock()` / `createPermanentLock()`
2. `convertToPermanent()` / `triggerUnlock()`
3. `claim()` / `claimTo()`
4. `forceWithdrawAll()` (admin)

### Cross-Contract Attack Vectors

- StakeWeight ↔ StakingRewardDistributor state sync
- LockedTokenStaker ↔ MerkleVester allocation tracking
- L2WCT transfer restrictions bypass

### Time-Based Vulnerabilities

- Week boundary manipulation
- Checkpoint gap attacks (>52 weeks)
- Block timestamp dependence

## Test Scenarios (Priority Order)

### Critical Path Tests

```solidity
// Test 1: Permanent lock full lifecycle
createPermanentLock(1M tokens, 52 weeks)
→ updatePermanentLock(+1M tokens)
→ triggerUnlock()
→ wait(52 weeks)
→ withdrawAll()
✓ Verify: All funds returned, histories cleared

// Test 2: Mid-week conversion with rewards
createLock(Wednesday)
→ wait to next Monday
→ convertToPermanent(Tuesday)
→ claim(Friday)
✓ Verify: Correct reward split between decaying/permanent

// Test 3: Admin force withdraw on permanent
createPermanentLock(10M tokens)
→ forceWithdrawAll(user)
✓ Verify: Supply reduced, histories cleared, funds returned
```

### Edge Cases (Must Test)

- Create lock at `block.timestamp == week_boundary - 1`
- Convert at max lock duration (104 weeks)
- Claim after 53 weeks gap (exceeds iteration limit)
- Force withdraw with 0 transferredAmount (vesting locks)
- Trigger unlock → reconvert in same block

### Fuzzing Targets

```solidity
// Fuzz all timing parameters
fuzz_createLock(amount: uint128, unlockTime: uint40)
fuzz_convertToPermanent(duration: uint8)
fuzz_claim(weeks_to_claim: uint8[])

// Invariant: No combination breaks conservation laws
```

## Gas & DoS Considerations

### Iteration Limits

- `_checkpoint`: 255 weeks max (~5 years)
- `_checkpointToken`: 52 weeks max (~1 year)
- `claim`: Unbounded weeks (DoS risk?)

### Recommended Limits

```solidity
require(block.timestamp - lastCheckpoint < 52 weeks, "Checkpoint gap too large");
require(weeksToCllaim.length <= 52, "Too many weeks in single claim");
```

## Operational Security Requirements

### Admin Key Management

- Multisig requirement: ≥3/5 signers
- Timelock: 48-hour delay minimum
- Emergency pause: 2/5 fast-track

### Monitoring & Alerts

- Large deposits (>1% supply)
- Checkpoint gaps (>4 weeks)
- Admin action attempts
- Reward injection anomalies

### Upgrade Procedures

1. Testnet deployment & verification
2. Formal audit of upgrade diff
3. Community review period (1 week)
4. Timelock queue
5. Post-upgrade verification script

## Audit Methodology Requirements

### Static Analysis

- Slither with custom detectors
- Mythril for symbolic execution
- Echidna for property testing

### Dynamic Testing

- Foundry invariant tests (10M+ runs)
- Mainnet fork testing with real positions
- Gas profiling under max load

### Manual Review Focus

- Two-phase checkpoint logic
- Admin operation state machines
- Cross-contract reentrancy paths
- Precision loss in reward calculations

## Known Issues & Accepted Risks

### Acknowledged Limitations

1. **Iteration cap overflow**: System breaks if gaps exceed 255/52 weeks

   - _Mitigation_: Operational monitoring + regular checkpoints

2. **Stack depth in checkpoint**: Cannot use separate storage namespace

   - _Mitigation_: Single storage pointer pattern

3. **Discrete duration set**: Only [4,8,12,26,52,78,104] weeks allowed
   - _Mitigation_: UI/UX guidance

### Out of Scope

- Frontend vulnerabilities
- Off-chain infrastructure
- Third-party dependencies (OpenZeppelin, Magna)
- L1 ↔ L2 bridge security

## Appendix A: Quick Reference

### Key Functions

```solidity
// Permanent Lock Operations
createPermanentLock(amount, duration)
convertToPermanent(duration)
updatePermanentLock(amount, newDuration)
triggerUnlock()

// Admin Operations
forceWithdrawAll(user)
kill() // StakingRewardDistributor
setMaxLock(duration)

// Query Functions
permanentSupply()
permanentOf(user)
balanceOfAtTime(user, timestamp)
```

### Error Codes

- `AlreadyPermanent`: Cannot convert permanent lock
- `NotPermanent`: Operation requires permanent lock
- `LockStillActive`: Cannot withdraw before expiry
- `DurationTooShort`: New duration less than remaining

### Events to Monitor

- `PermanentConversion(user, duration, timestamp)`
- `UnlockTriggered(user, endTime, timestamp)`
- `ForcedWithdraw(user, amount, transferredAmount, timestamp, end)`

## Appendix B: Testing Commands

```bash
# Run comprehensive test suite
forge test --mc Stak --no-match-contract Fork -vvv

# Run with formal verification
certoraRun specs/StakeWeight.spec

# Gas profiling
forge test --gas-report

# Coverage analysis
forge coverage --report lcov
```

## Deliverable Checklist for Auditors

### Required Analyses

- [ ] Storage layout differential analysis
- [ ] Invariant formal verification results
- [ ] Attack vector enumeration with PoCs
- [ ] Gas optimization recommendations
- [ ] Cross-contract interaction audit
- [ ] Upgrade safety verification

### Required Documentation

- [ ] Security findings ranked by severity
- [ ] Remediation recommendations
- [ ] Operational security guidelines
- [ ] Test coverage assessment
- [ ] Code quality metrics

### Timeline

- Audit Start: [DATE]
- Preliminary Report: [DATE + 2 weeks]
- Remediation Period: [1 week]
- Final Report: [DATE + 4 weeks]

---

_This document represents the complete technical specification for the P3 staking redesign audit. Any questions or
clarifications should be directed to the development team before audit commencement._
