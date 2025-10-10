## Testing Patterns

- **Test Philosophy**: Concrete tests validate specific paths, fuzz tests provide confidence across ranges
- **Foundry Gotchas**: 
  - `vm.prank` and `vm.expectRevert` apply to the NEXT external call only
  - Use `vm.startPrank/stopPrank` for multi-call setups to avoid losing the prank context
- **BTT Structure**: Tests use modifiers to match Branch-Based Testing tree structure for clarity
- **Time Advancement**: Use `_mineBlocks()` not `vm.warp()` (updates both timestamp and block number)
- **Reward Distribution**: Use `stakingRewardDistributor.injectReward()` not `feed()` (matches production)
- **Invariant Cache**: The `cache/invariant` directory stores failed sequences for regression testing - only clear after fixing bugs

## Fork Testing Setup
```bash
source .common.env && source .optimism.env
export OPTIMISM_RPC_URL=https://optimism-rpc.publicnode.com
forge test --force  # --force required for OpenZeppelin plugin
```

## Critical System Constraints

### Token Supply Limits
- **WCT Max Supply**: 1 billion tokens (no holder > 15%)
- **int128 Safety**: Max 100M tokens (1e26) for test amounts to prevent overflows
- **Test Amount Guidelines**: whale (10M), large (1M), medium (100k), small (10k)

### Checkpoint Loop Limits (CRITICAL)
- **StakeWeight**: Max 255 iterations (~5 years of weekly checkpoints)
- **StakingRewardDistributor**: Max 52 iterations (~1 year of weekly checkpoints)
- **Testing Impact**: Keep time warps <10 weeks to avoid breaking these limits
- **Known Issue**: Gaps >52 weeks will cause incomplete state and overflows