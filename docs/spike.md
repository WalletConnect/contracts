# WalletConnect Staking Upgrade Plan (Tasks 1 & 2)

## Scope

Deliver: (1) summary of current staking/token system and Snapshot integration; (2) design for a proxy upgrade adding IVotes-style delegation + snapshotting to StakeWeight. Ignore multichain/governor wiring.

## Current System Summary (Task 1)

- Token (Optimism): `L2WCT` used across staking/rewards; transfer restrictions until permanently disabled.
- Staking core: `StakeWeight.sol` (ve model)
- Decaying locks (bias/slope) and P3 permanent locks (constant weight)
- Checkpointing for users and global; historical queries via binary search:
- User: `balanceOfAt`, `balanceOfAtTime`
- Global: `totalSupplyAt`, `totalSupplyAtTime`
- Roles: `DEFAULT_ADMIN_ROLE`, `LOCKED_TOKEN_STAKER_ROLE` (vesting); Pauser integration
- Rewards: `StakingRewardDistributor.sol`
- Weekly `tokensPerWeek`, snapshots of total supply; claims pro‑rata to stake weight
- Migrated to AccessControl in P3
- Vesting: `LockedTokenStaker.sol` can `createLockFor`/`increaseLockAmountFor` users with role
- Config: `WalletConnectConfig.sol` provides addresses to other contracts
- Simple pool: `Staking.sol` (independent/simple; not connected to SRD/ve)
- P3 Upgrade (PR #33): shipped permanent locks, SRD AccessControl migration, audit fixes; deployment scripts indicate Optimism upgrade path

## Contracts to Update (Task 2)

1. `StakeWeight.sol` (primary): add IVotes-style delegation and checkpointing
2. Optional `WalletConnectConfig.sol`: add discovery key later only if needed (not required)
3. No changes needed to `StakingRewardDistributor.sol`, `LockedTokenStaker.sol`, `Staking.sol`

## Proposed Functionality (StakeWeight)

- Interface: Implement `IVotes` from OpenZeppelin directly (do NOT inherit from `Votes.sol` or `ERC20Votes`):
- StakeWeight is not a token; it's a staking contract with its own checkpoint system
- Inheriting from `Votes.sol` would conflict with existing `Point` structures and ERC7201 storage
- Implementing `IVotes` interface gives full control and avoids storage/logic conflicts

- Storage (append at end of ERC7201 namespace):
- `mapping(address => address) _delegates`
- Delegate vote checkpoints (aggregate per delegate): use existing `Point` structure or add compact `Checkpoint{uint32 fromBlock; uint224 votes}` for gas optimization
- EIP‑712 domain separator and `mapping(address => uint256) nonces` for `delegateBySig`

- External API (implements IVotes):
- `function delegates(address account) external view returns (address)`
- `function delegate(address delegatee) external`
- `function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external`
- `function getVotes(address account) external view returns (uint256)` - current voting power of delegatee
- `function getPastVotes(address account, uint256 blockNumber) external view returns (uint256)` - historical delegatee voting power
- `function getPastTotalSupply(uint256 blockNumber) external view returns (uint256)` - wrap existing `totalSupplyAt(blockNumber)`

- Events (from IVotes):
- `event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate)`
- `event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance)`

- Integration hooks:
- On any weight change (create/increase/update/withdraw, convert permanent/triggerUnlock, forceWithdraw, checkpoint), compute delegator weight delta and move it between delegatees via delegation checkpoint updates
- Default delegatee = self (users vote with their own weight unless they delegate)
- `getPastVotes` reads from delegate checkpoint history; reuse existing binary search infrastructure

## Backward Compatibility & Risks

- Append-only storage; keep ERC7201 slot and existing ordering intact
- Preserve Pauser, roles, and all staking/reward/vesting behaviors
- Risks: storage layout mistakes, EIP‑712 domain correctness, gas of checkpoint writes, edge cases during permanent/decaying transitions and partial withdrawals

## Feasibility & Estimates

- Feasibility: High — existing robust checkpointing makes delegation additive
- Timeline estimate: ~9–15 engineering days
- Design & storage review: 1–2d
- Implementation: 3–5d
- Tests (unit/integration/fuzz): 4–6d
- Upgrade scripts/docs: 1–2d

## Deliverables

1. Written summary of current staking/token system and Snapshot usage
2. `StakeWeight` upgrade design with IVotes‑style API and storage layout
3. Spike/PoC implementation (no deploy): code changes + storage layout review
4. Test suite covering delegation lifecycle and interactions with decaying/permanent/vesting flows
5. Upgrade validation notes (OZ Upgrades check) and example timelock calldata

## Files Likely Touched

- `evm/src/StakeWeight.sol` (core changes)
- `evm/test/{unit,integration}/...` (new tests)
- `evm/script/deploy/P3Upgrade.s.sol` (extend for validation/new impl)
- `evm/Makefile` (optional helper to log upgrade calldata)
