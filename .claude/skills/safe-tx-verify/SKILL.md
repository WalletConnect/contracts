---
name: safe-tx-verify
description: Verify a Safe (Gnosis Safe) multisig transaction before signing on a Ledger. Independently recomputes the Safe EIP-712 hashes (message hash / domain hash / safeTxHash) from raw params WITHOUT trusting the Safe backend, then decodes the calldata into a human-readable action using THIS repo's compiled ABIs and cross-references every address against DEPLOYMENT_ADDRESSES.md. Use when someone pastes a Safe URL (app.safe.global) or a prefixed address like "oeth:0x…", asks "what will my Ledger show / what does this tx do / is this safe to sign", or wants to check a queued Safe transaction.
---

# safe-tx-verify

Answers one question safely: **"what am I actually about to sign on my Ledger, and is it what I think it is?"** — for a Safe multisig transaction in the Reown contracts.

It does three independent things:

1. **Recomputes the EIP-712 hashes locally.** It pulls only the raw transaction
   *parameters* (to, value, data, operation, nonce, gas fields) and the Safe
   contract version from the Safe Transaction Service, then computes the
   **message hash**, **domain hash**, and **safeTxHash** itself with `cast keccak`.
   The backend's own `safeTxHash` is never trusted — it's only shown at the end
   as an independent cross-check.
2. **Decodes the calldata** into a human-readable action using THIS repo's
   compiled ABIs (`evm/out/**/*.json`, matched by 4-byte selector — no
   collisions, unlike the public 4byte DB). It recurses into `multiSend`
   batches, Timelock `execute`/`executeBatch`/`schedule`/`scheduleBatch`, and
   ProxyAdmin `upgradeAndCall`, so nested actions (e.g. a proxy upgrade hidden
   inside a timelock batch) are surfaced.
3. **Cross-references every address** against `DEPLOYMENT_ADDRESSES.md`
   (chain-aware), labeling `to` and address arguments with the contract name
   (e.g. `StakeWeight [Optimism]`, `NTT Manager`, `ProxyAdmin`).

## When to use

- A Safe URL is pasted: `https://app.safe.global/transactions/queue?safe=oeth:0x…`
  or `…/transactions/tx?id=multisig_0x…_0x…&safe=eth:0x…`
- A prefixed address: `oeth:0x398A2749487B2a91f2f543C01F7afD19AEE4b6b0`
- "What will my Ledger show?", "what does this queued tx do?", "is this safe to sign?"

## How to run

Runs via [`uv`](https://docs.astral.sh/uv/) (the script carries a PEP-723 header with
no Python dependencies, so `uv run` needs no install step); plain `python3` works too.
Requires `cast` (foundry) on PATH — already used elsewhere in this repo. No build step.

```bash
uv run .claude/skills/safe-tx-verify/scripts/verify_safe_tx.py "<safe-url-or-address>" [--nonce N]
```

Flags:
- `--nonce N`    — pick a specific pending transaction (required when several nonces are queued)
- `--onchain`    — run `cast` sanity checks (code exists at `to`, resolve ERC-1967 proxy impl)
- `--rpc URL`    — RPC for `--onchain` (defaults to a public RPC per network)
- `--chain-id N` — override chain id if the network short-name isn't recognized
- `--version V`  — override the Safe contract version (default: fetched; else 1.3.0)
- `--json`       — machine-readable output (hashes, params, flattened decode)

If no `--nonce` is given and multiple nonces are queued, it lists them (exit 2)
so the user can pick one.

### Propose mode — verify a tx you're about to *create* (not yet queued)

When YOU are the proposer (the tx needs your signature and isn't in the Safe
backend yet), pass the raw params instead of relying on a queued tx. The script
computes the same Ledger hashes (message + domain), decodes the calldata, and
prints the **safeTxHash the Safe UI should display once you create the tx** — so
you can cross-check in the other direction (UI/simulation → local computation).

```bash
uv run .claude/skills/safe-tx-verify/scripts/verify_safe_tx.py "<safe-url-or-address>" \
    --to 0x<target> --data 0x<calldata> [--value W] [--operation 0|1] [--nonce N]
```

Propose-mode flags:
- `--to`, `--data` — target + calldata of the tx you will create (presence of `--to` triggers propose mode)
- `--value` (default 0), `--operation` (0=CALL, 1=DELEGATECALL; default 0)
- `--safe-tx-gas`/`--base-gas`/`--gas-price`/`--gas-token`/`--refund-receiver` — default 0 / zero-address (matches how the Safe UI builds a standard tx)
- `--nonce` — if omitted, defaults to the Safe's next FREE nonce (on-chain `nonce()` reconciled against already-queued txs, so a tx queued behind others gets the right slot)

Since there's no queued tx to cross-check against, propose mode prints the
computed safeTxHash and tells the user to confirm the Safe UI shows the same
value (and the Ledger the same message/domain hash) before signing.
Build calldata with `cast calldata "fn(types)" args`.

#### Verifying a BATCH (Tx Builder "All actions") in propose mode

A Safe Tx-Builder batch is a single **`DELEGATECALL` (operation 1)** into a **MultiSend**
singleton whose `data` is `multiSend(bytes)` (selector `0x8d80ff0a`) packing each inner
call as `op(1B)+to(20B)+value(32B)+len(32B)+data`. Two gotchas that will make your
computed hash disagree with the UI:

1. **Which MultiSend singleton.** Safe v1.3.0 shipped a *canonical* MultiSendCallOnly
   (`0x40A2aCCbd92BCA938b02010E17A5b8929b49130D`) AND an *eip155* one
   (`0xA1dabEF33b3B82c7814B6D82A79e50F4AC44102B`). The UI picks one per network and it
   becomes the tx `to`, so guessing wrong changes the message hash / safeTxHash (the
   *domain* hash still matches — it's only Safe+chain). **Reown's 1.3.0+L2 Safes on
   Optimism use the eip155 `0xA1dabEF3…44102B`** (validated 2026-07-10). Pass that as `--to`.
2. **Operation must be `1`.** The Ledger will show `DELEGATECALL ⚠` — expected for a batch.

Build + verify a 2-action batch:
```bash
# pack the inner calls (op=00 CALL, to=target, value=0, len, data) then wrap in multiSend(bytes)
INNER=00<to20><value32><len32><data> 00<to20><value32><len32><data>
MS=$(cast calldata "multiSend(bytes)" 0x$INNER)
uv run .../verify_safe_tx.py "oeth:0x<safe>" --to 0xA1dabEF33b3B82c7814B6D82A79e50F4AC44102B --data "$MS" --operation 1 --nonce <next-free>
```
The script decodes the multiSend into its inner calls (labeled via repo ABIs), so you can
confirm each action + target before signing. Known MultiSend/MultiSendCallOnly addresses
(both v1.3.0 variants + v1.4.1) are auto-labeled instead of showing "unknown contract".

Validated: propose `forceWithdrawAll(0x5cD9…f43a)` on StakeWeight [Optimism] at
nonce 49 → message hash `0x5bf7db87f5c2c18c9990727da4fa35c60cd5c545e332ad6e73af3b7c55ba607c`,
safeTxHash `0x5b55971dcb0216a83d8bb724b3002eedd3e678ed3f3f39cb3df7256c2576863e`
(matched the ExecutionSuccess txHash in the Safe simulation).

**Stale nonces are detected automatically.** Safe nonces execute strictly in
order, so any queued tx whose nonce is below the Safe's current on-chain nonce
can never execute (it was superseded/replaced). The script reads the on-chain
`nonce()` (best-effort, via the same per-network public RPC as `--onchain`; skipped
if unreachable) and:
- excludes stale nonces from the "live nonces" it asks you to pick from, and
  labels them `[STALE — can never execute, superseded]` in the exit-2 listing
  (the next executable one is labeled `[next to execute]`);
- auto-selects when exactly one *live* transaction remains, even if dead entries
  are still in the queue;
- prints a loud `⚠` warning (but still verifies) if you explicitly pass a stale
  `--nonce N`, and fails cleanly if *every* queued tx is stale.

**On exit 2 (multiple live pending nonces), do NOT auto-verify all of them.** A bare
queue URL does not identify a transaction — relay the one-line summary the script
printed (nonce → `to` → method, with stale ones already flagged) and ask the user
which live nonce they want fully verified, then re-run with `--nonce N` for that
one. Only verify every nonce if the user explicitly asks for all of them.

## Reading the result to the user

- The headline **Message hash** (and the **Domain hash**) are the two values a
  Ledger displays when signing a Safe EIP-712 tx. Tell the user to compare them
  character-for-character on the device. The **safeTxHash** is what Safe/
  Etherscan label the tx with but is NOT shown on the Ledger.
- Walk them through the decoded action(s) in plain language, using the contract
  labels. Call out anything high-stakes: `DELEGATECALL ⚠`, owner changes
  (`swapOwner`/`addOwner`/`changeThreshold`), proxy upgrades (`upgradeAndCall`/
  `upgradeTo` → new implementation address), `setMinter`, role grants.
- `[repo ABI: …]` = decoded from this repo's verified ABI (trustworthy).
  `[public 4byte DB — UNVERIFIED]` = signature came from the network 4byte DB and
  could be a selector collision; treat the decode as a hint, not proof.
- `✓ safeTxHash matches Safe API` = independent cross-check passed. A
  `✗ MISMATCH` (exit code 3) means **do not sign** — investigate.

## Notes / limits

- Address labels come from `DEPLOYMENT_ADDRESSES.md`; regenerate it
  (`pnpm run sync:deployments`) if a new deployment isn't recognized.
- Selector index is built from `evm/out` — run `forge build` if artifacts are stale.
- Safe singleton functions (e.g. `swapOwner`) and OZ `upgradeAndCall` resolve via
  the public 4byte DB (flagged UNVERIFIED) because those ABIs aren't compiled into
  `evm/out`; the decode is still correct for these well-known selectors.
- Validated: Optimism Safe `0x398A…b6b0` nonce 48 → message hash
  `0x0ca4d2606a60453fc21696b7cf2965534de48e86a043bdefbf2d4d546d965059`,
  safeTxHash `0xf2400894943443afd32961ffbd90a2c8a9bc07e9d7cd9be7dce7f58c37dec34a`.
- Validated (BATCH, propose mode): a 2-action `forceWithdrawAll` batch on StakeWeight [Optimism]
  via Safe `0x398A…b6b0`, DELEGATECALL into **eip155** MultiSendCallOnly `0xA1dabEF3…44102B`,
  reproduced the Safe UI's domain hash, message hash, and safeTxHash exactly. Key lesson: the
  first attempt used the *canonical* MultiSend `0x40A2…130D` and produced a different (wrong)
  message hash — for these Safes the **eip155** variant is the correct `to`. (Specific targets
  omitted — token-repurchase actions are confidential per the WCT Repurchase Policy.)
