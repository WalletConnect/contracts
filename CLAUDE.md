## Testing Patterns

- **Test Philosophy**: Concrete tests validate specific paths, fuzz tests provide confidence across ranges
- **Foundry Gotchas**:
  - `vm.prank` and `vm.expectRevert` apply to the NEXT external call only
  - Use `vm.startPrank/stopPrank` for multi-call setups to avoid losing the prank context
- **BTT Structure**: Tests use modifiers to match Branch-Based Testing tree structure for clarity
- **Time Advancement**: Use `_mineBlocks()` not `vm.warp()` (updates both timestamp and block number)
- **Invariant Cache**: The `cache/invariant` directory stores failed sequences for regression testing - only clear after
  fixing bugs

## Fork Testing Setup

```bash
# Fork tests use the 'optimism' RPC alias from foundry.toml (uses Infura)
# Ensure .common.env has API_KEY_INFURA set
source .common.env && source .optimism.env
forge test --force  # --force required for OpenZeppelin plugin
```

**Note:** Fork tests use `vm.createSelectFork("optimism", blockNumber)` which references the `optimism` RPC alias in `foundry.toml`. This automatically uses your Infura API key from `.common.env`.

## Critical System Constraints

### Token Supply Limits

- **WCT Max Supply**: 1 billion tokens (no holder > 15%)
- **int128 Safety**: Max 100M tokens (1e26) for test amounts to prevent overflows
- **Test Amount Guidelines**: whale (10M), large (1M), medium (100k), small (10k)
