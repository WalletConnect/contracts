---
name: safe-tx-verify
description: Independently verify a Safe (Gnosis Safe) multisig transaction before signing on a Ledger — recomputes the EIP-712 domain/message/safeTxHash from raw params, decodes calldata, labels addresses. Use when the user wants to check a queued Safe tx, confirm a hash before signing, or asks "verify this safe tx".
---

# safe-tx-verify

Verify a queued Safe transaction **before it is signed on a Ledger**. This skill is a thin wrapper around the
committed, version-controlled script at `tools/safe-tx-verify/verify_safe_tx.py` — that script is the trust anchor
(it recomputes the Safe EIP-712 hashes from raw parameters and never trusts the backend's hash). Do not reimplement
the hashing here; always shell out to the script so the verification stays reproducible and reviewable.

## How to run

Only prerequisite is [`uv`](https://docs.astral.sh/uv/) (deps are declared inline via PEP 723 and resolved by
`uv run`). From the repo root:

```bash
uv run tools/safe-tx-verify/verify_safe_tx.py "<target>" --nonce N \
    [--chain-id N] [--version V] [--onchain] [--rpc URL] [--json]
```

- `<target>` — a Safe app URL (`https://app.safe.global/...?safe=oeth:0x…`) or `prefix:0xADDRESS` (e.g. `oeth:0x398A…`).
- `--nonce N` — the queued transaction's nonce to verify (required).
- `--onchain` — also read the Safe's live nonce/threshold/VERSION() via RPC and flag a stale nonce.
- `--json` — machine-readable; exit `0` = backend hash matches, `2` = mismatch.

If `uv` is not installed, do NOT install it silently — ask the user (this repo forbids unprompted package installs).

## What to do with the output

Report to the user, in this order:
1. **MATCH vs MISMATCH** — a `MISMATCH` means the backend's hash does not equal the hash recomputed from the raw
   params. Tell the user **not to sign**.
2. The **message hash** — this is what the Ledger displays; the user should confirm it matches the device.
3. The **decoded action** (`to`, `operation`, function + args). Call out `operation: 1` (delegatecall) and expand
   `multiSend` batches. Flag anything that doesn't match the user's stated intent.
4. **Address labels** — resolved from `DEPLOYMENT_ADDRESSES.md`; flag any unknown/unexpected address.

For full flag/endpoint details see `tools/safe-tx-verify/README.md`.
