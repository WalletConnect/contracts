# safe-tx-verify

Independently verify a Safe (Gnosis Safe) multisig transaction **before signing it on a Ledger**.

The script recomputes the Safe EIP-712 hashes — `domainHash`, `messageHash`, `safeTxHash` — **from the raw
transaction parameters**. It never trusts the hash the Safe backend returns: it fetches the queued transaction's
parameters, recomputes the hash locally, and tells you whether they agree. It then decodes the calldata using this
repo's compiled ABIs and labels every address against [`DEPLOYMENT_ADDRESSES.md`](../../DEPLOYMENT_ADDRESSES.md).

When you sign a Safe transaction, the Ledger shows the pair **(domain hash, message hash)**. The message hash is
the one that encodes the actual transaction, so it is the value to check against the device.

## Requirements

- [`uv`](https://docs.astral.sh/uv/) — the only prerequisite. Dependencies (`eth-utils`, `eth-abi`) are declared
  inline (PEP 723) and resolved automatically by `uv run`; nothing to install manually.
- Optional: this repo's compiled artifacts (`evm/out`, via `forge build`) for richer calldata decoding, and network
  access to `api.safe.global` (the Safe Transaction Service; no API key required for reads).

## Usage

```bash
uv run tools/safe-tx-verify/verify_safe_tx.py "<safe-url-or-address>" --nonce N \
    [--chain-id N] [--version V] [--onchain] [--rpc URL] [--json]
```

- `target` — a Safe app URL (`https://app.safe.global/...?safe=oeth:0x…`) or a `prefix:0xADDRESS` (e.g. `oeth:0x398A…`).
- `--nonce N` — the queued transaction's nonce to verify (required).
- `--chain-id N` — override the chain id (otherwise derived from the prefix).
- `--version V` — Safe contract version (default `1.3.0`; auto-read with `--onchain`). Governs the EIP-712 domain
  (chainId is only bound for ≥ 1.3.0) and the `SafeTx` typehash.
- `--onchain` — also read the Safe's live `nonce` / `threshold` / `VERSION()` via RPC and flag a stale nonce.
- `--rpc URL` — RPC endpoint (otherwise a public default for the chain).
- `--json` — machine-readable output. Exit code `0` = backend hash matches, `2` = mismatch.

### Examples

```bash
# Verify nonce 48 on the Optimism admin Safe
uv run tools/safe-tx-verify/verify_safe_tx.py "oeth:0x398A2749487B2a91f2f543C01F7afD19AEE4b6b0" --nonce 48

# From a Safe app URL, cross-checking the on-chain nonce/version too
uv run tools/safe-tx-verify/verify_safe_tx.py \
  "https://app.safe.global/transactions/queue?safe=oeth:0x398A2749487B2a91f2f543C01F7afD19AEE4b6b0" \
  --nonce 48 --onchain
```

## What to check before signing

1. **`MATCH`** — the parameters the backend gave and the hash it returned are consistent (the script recomputed the
   same `safeTxHash` from the params). A `MISMATCH` means **do not sign**.
2. The **message hash** printed here equals what the Ledger displays.
3. The **decoded action** (`to`, `operation`, function + args) is what you intend — `operation: 1` is a
   `delegatecall`; batched `multiSend` calls are expanded and each inner call decoded.
4. Every address is the one you expect — known addresses are labeled from `DEPLOYMENT_ADDRESSES.md`.

## Notes

- Supported chains (prefix → chainId): `eth`(1), `oeth`(10), `arb1`(42161), `base`(8453), `matic`(137), `gno`(100),
  `bnb`(56), `avax`(43114), `linea`(59144), `scr`(534352), `celo`(42220), `blast`(81457), `zksync`(324), `mnt`(5000),
  plus testnets `sep`, `basesep`, `oeth-sep`, `arb-sep`. Others: pass `--chain-id` + `--rpc`.
- The Safe Transaction Service moved to the unified `https://api.safe.global/tx-service/<short>/api/v1/…` endpoint;
  this tool targets it.
- The EIP-712 hashing was validated against real Optimism Safe transactions (recomputed `safeTxHash` matched the
  backend for every sampled tx, including delegatecall `multiSend` batches). Calldata decoding is best-effort and
  never affects the hash verification.
