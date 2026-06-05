# Staking "no rewards" tickets: root cause, fix options & estimates

> Tech doc requested by Nacho. Context: recurring support tickets ("staked but no rewards") —
> three verified cases June 2026, one earlier case March 2026, all the same cause.
> On-chain debugging playbook: `.claude/skills/staking-support-debug/` in this repo.

## Root cause (verified on-chain, not a bug)

`StakingRewardDistributor.claim()` processes at most **52 weeks per call**
(`MAX_REWARD_ITERATIONS`, `StakingRewardDistributor.sol:74`) from the user's stored
`weekCursorOf`, then saves the cursor and stops. Users whose last claim is >52 weeks old
(typical: claimed once on a small 2024 lock, later converted/topped-up in 2026) get a claim
that walks 52 old zero-balance weeks, **pays 0, and the portal hides the Claim button**.

The portal makes it worse in two specific places (`apps/portal`, walletconnect-apps):

- `stake/_components/cards/rewards-card.tsx:34` — `actions={claimSimulation.data ? <Actions/> : null}`:
  `0n` is falsy ⇒ no button rendered at all.
- `ClaimButton`/`ClaimRewardsDrawer` — `isDisabled={!amount}` and `if (!amount) return` ⇒ even if
  rendered, a 0-preview claim can't be sent. The user is hard-locked out of the very action
  (claim repeatedly) that fixes their state.

Verified examples: pending 37.50 / 110.94 / 9.63 WCT behind a 0-showing button; 2 claim passes each.

## How PancakeSwap (our upstream fork source) solved it

Their `RevenueSharingPool.claim()`/`claimForUser()` is **permissionless** — anyone can trigger a
claim *for* a user; payout destination is unchanged so there's nothing to steal. On top they run a
24-line periphery, `RevenueSharingPoolGateway` (BSC `0x011f2a82846a4E9c62C2FC4Fd6fDbad19147D94A`):

```solidity
function claimMultipleWithoutProxy(address[] calldata pools, address _for) external {
    for (uint256 i = 0; i < pools.length; i++) {
        IRevenueSharingPool(pools[i]).claimForUser(_for);
    }
}
```

One transaction, multiple inner claims; state persists within the tx, so each inner call advances
the cursor another 52 weeks. A 78-week backlog clears in one click, no simulation gymnastics.
Our fork closed this door by adding the `UnauthorizedClaimer` check
(`StakingRewardDistributor.sol:489-491`): only the user or their recipient may call `claim(user)`.
Since we don't upgrade deployed contracts outside security fixes, parity via `claimForUser` is not
on the table — but the **recipient hook the fork kept** enables an equivalent periphery (Tier 2b),
and account-level batching (Tier 2a) needs no contract at all.

## Existing infrastructure we can leverage

- **Indexer**: `reown-com/onchain-api` (Ponder) already ingests `StakeWeight` Deposit/Withdraw/
  PermanentConversion and **SRD `RewardsClaimed`** → Postgres tables `lock` and `reward`.
  Today the `RewardsClaimed` handler keeps only a cumulative sum and discards `claimEpoch`,
  `maxEpoch`, block timestamp, and tx hash.
- **API**: `services/foundation-api` (walletconnect-apps, Hono on Cloudflare Workers) serves
  `/staking?address=` from those tables, already fronted by a token-bucket rate limiter
  (durable object) — the natural place for a cheap per-user flag.
- **Portal**: `weekCursorOf` is already in the generated ABI; `position.createdAt` already
  fetched; dashboard app already has EIP-5792 plumbing (`sendCalls`, `waitForBatchedTx`).
- **Semantics bug feeding the tickets**: portal's "All time rewards" renders `reward.amount`,
  which is all-time **claimed**, not earned. Affected users see "All time rewards: 0.196 WCT"
  next to "Rewards: 0" — the UI corroborates their "I got nothing" belief. Relabel ("Claimed so
  far") or add an earned figure.

## Fix options

### Tier 0 — docs + support guide (ship today, no code)

User-facing page: "Why does my claim show 0?" with the Etherscan write-proxy walkthrough
(`claimTo` / `claim(yourAddress)` 2–3× at the SRD proxy). Helena links it; support stops
escalating. Effort: **hours**.

### Tier 1 — portal: detect the gap, unlock the button, guide the passes (~2–3 days)

No backend, no contract change, ~zero marginal RPC.

**Detection** (new `useOlderRewards()` hook):

```ts
const WEEK = 604_800n;
// one extra read, batched by viem into the existing multicall — zero extra HTTP requests
const weekCursor = read SRD.weekCursorOf(address);
const currentWeek = BigInt(Math.floor(Date.now() / 1000 / 604_800)) * WEEK; // client math
// never-claimed users have weekCursor == 0: fall back to position.createdAt (already fetched)
const anchor = weekCursor > 0n ? weekCursor
             : BigInt(Math.floor(stakingInfo.position.createdAt.getTime() / 1000 / 604_800)) * WEEK;
const weeksBehind = (currentWeek - anchor) / WEEK;
const hasOlderRewards = weeksBehind > 52n;          // the flag — no exact amount needed
const passesNeeded = Number((weeksBehind + 51n) / 52n);
```

`weekCursorOf` only changes when the user claims ⇒ react-query cache + invalidate in the claim
mutation's `onSuccess` (alongside the existing invalidations).

**Display — three states for `RewardsCard`:**

| State | Condition | Card shows | Action |
|---|---|---|---|
| Normal | no gap | amount (as today) | Claim (as today) |
| Backlog, hidden rewards | gap && preview == 0 | badge **"Older rewards available"** instead of bare 0 | button **enabled**: "Claim older rewards" |
| Backlog, partial preview | gap && preview > 0 | amount + caption *"more available after this claim"* | guided claim |

Copy for the drawer in backlog mode (no jargon, no exact numbers needed):

> Your rewards history is longer than one claim can process. Claiming takes N quick
> transactions. The first one(s) may show 0 WCT — that's expected: they unlock your
> remaining rewards. We'll guide you through each step.

**Guided flow:** turn `ClaimRewardsDrawer` into a stepper ("Claim — pass 1 of N"). The mutation
loops: `claimTo` → wait receipt → re-read `weekCursorOf` → next pass while `weeksBehind > 52`,
final pass shows the real amount in the success toast. Each pass is an O(cents) OP tx with ~2s
confirmation. Required fixes regardless: `rewards-card.tsx:34` falsy-`0n` render guard and the
`!amount` disables must also branch on `hasOlderRewards`.

**Optional polish (+1 day):** wagmi `useSendCalls` (EIP-5792) to batch all passes into one wallet
confirmation where the wallet supports atomic batch (`wallet_getCapabilities`); sequential
fallback otherwise. Good story for WalletConnect to dogfood 5792.

False-positive note: a gapped wallet with no active position and nothing pending would be told to
claim for nothing. Gate the badge on `stakingInfo.position` existing (covers ~all real cases); the
Tier 1b backend flag makes it exact.

### Tier 1b — detection lives at the indexer (RECOMMENDED shape, ~2–3 days total)

Zero portal RPC; the detection data materializes where the events already flow, and Ponder's
re-sync model gives backfill for free:

1. **onchain-api (Ponder)** — in the `RewardsClaimed` handler, also read the exact
   `weekCursorOf(user)` via `context.client.readContract` at the event block (one cached read per
   claim event — not per page view) and store `weekCursor` + `lastClaimAt` on the `reward` row.
   Add a `rewardClaim` history table (address, amount, claimEpoch, maxEpoch, txHash, timestamp)
   alongside the cumulative sum — support gets full claim history in our own Postgres (today we
   fetch it from Blockscout), and "All time rewards" can be relabeled honestly ("Claimed so far").
   **Backfill is automatic**: a Ponder schema/handler change triggers a full re-sync, so every
   historical claim flows through the new handler and `weekCursor` materializes for all past
   claimers. (Caveat: historical `readContract` needs archive state from the configured RPC.)
   **Store the cursor, not the flag** — `hasOlderRewards` is time-dependent (becomes true as weeks
   pass with no events) and would rot if persisted; the static cursor is the durable fact.
2. **foundation-api** — `/staking` adds `rewards: { amount, lastClaimAt, hasOlderRewards,
   passesNeeded }`, computed at read time: `weekCursor + 52 weeks < currentWeek`, falling back to
   `lock.createdAt` for never-claimed wallets (no reward row). Endpoint is already rate-limited by
   the token-bucket durable object.
3. **Portal** — pure UI: consume the flag from the `stakingInfo` it already fetches; the display
   states and guided-pass stepper from Tier 1 are unchanged (the claim-button unlock cannot live
   in the indexer).

Tier 1 (client-side `weekCursorOf` read) remains valid if cross-repo coordination is the
bottleneck — same UX, no indexer/API deploy. Both converge on identical display states.

### Tier 2 — one-click backlog clearing WITHOUT touching the contract

> Policy: deployed contracts are not upgraded except for security issues. Pancake's
> `claimForUser` route (which needs an SRD upgrade) is therefore out. Both options below work
> against the contract exactly as deployed.

**2a — EIP-5792 batch from the user's own account (no new contract at all).**
`wallet_sendCalls` executes the batch *as the user*, so the existing
`msg.sender == user` auth check passes: batch `[claimTo(r), claimTo(r), …]` × `passesNeeded` →
one wallet confirmation clears any backlog. The dashboard app already has the plumbing
(`sendCalls`, `waitForBatchedTx`, `useWalletCapabilities`). Capability-gate via
`wallet_getCapabilities` (atomic batch); non-capable EOAs fall back to the Tier-1 stepper.

**2b — optional periphery helper using hooks that already exist (new standalone contract,
zero SRD changes).** The deployed contract lets a user's *recipient* trigger claims
(`claim(user)` allows `msg.sender == recipient[user]`). A ~50-line `ClaimHelper`:

```solidity
function claimN(address user, uint256 passes) external {
    for (uint256 i; i < passes; i++) SRD.claim(user);     // auth: helper is user's recipient
    WCT.transfer(user, WCT.balanceOf(address(this)));      // forward everything, same tx
}
```

User flow: `setRecipient(helper)` once, then anyone/anything can run `claimN`; tokens always end
at the user. With 5792 it collapses to one confirmation:
`[setRecipient(helper), helper.claimN(user, n), setRecipient(0)]`. Deployable permissionlessly —
no admin role, no upgrade ceremony; still deserves a focused review since users point their
recipient at it.

Recommendation between them: ship **2a** (pure FE, biggest coverage as 7702 adoption grows);
hold 2b unless support volume from non-batching EOAs justifies a deployed helper.

### Non-options considered

- **FE simulates N sequential claims** (the March attempt): requires state-override simulation of
  dependent txs — fragile, provider-specific, and unnecessary once the flag exists. Dropped.
- **Exact pending amount in the portal**: possible (1 Multicall3 request, ~237 sub-calls — see the
  debug skill), result immutable per (wallet, week) so cacheable weekly. Nice-to-have behind the
  flag, not needed for the UX to work. If product wants the number, prefer the existing staking
  API to compute/cache it weekly server-side.

## Recommendation

Ship **Tier 0 today**. This sprint: **Tier 1b** (indexer cursor + API flag) plus the portal UI
unlock — the falsy-0 button bug is a straight defect to fix regardless — with **Tier 2a**
(5792 batch) layered into the same claim flow for capable wallets. No contract changes anywhere
in the plan; 2b stays in the back pocket if non-batching EOA volume warrants it.
