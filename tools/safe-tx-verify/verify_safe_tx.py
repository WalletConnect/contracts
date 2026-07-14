#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "eth-utils>=4.1",   # keccak
#   "eth-abi>=5.0",     # best-effort calldata decoding
# ]
# ///
"""
Verify a Safe (Gnosis Safe) multisig transaction before signing on a Ledger.

Independently recomputes the Safe EIP-712 hashes (domain hash, message hash, safeTxHash) from the raw
transaction PARAMETERS -- it never trusts the hash the Safe backend returns -- then decodes the calldata into a
human-readable action using THIS repo's compiled ABIs and cross-references every address against
DEPLOYMENT_ADDRESSES.md.

What your Ledger shows when signing a Safe tx is the pair (domain hash, message hash); the message hash is the one
that encodes the actual transaction, so it is the headline value here.

Run it with uv (dependencies are resolved automatically from the inline metadata above):

    uv run tools/safe-tx-verify/verify_safe_tx.py "<safe-url-or-address>" [--nonce N]
        [--chain-id N] [--version V] [--onchain] [--rpc URL] [--json]

Examples:
    uv run tools/safe-tx-verify/verify_safe_tx.py \
        "https://app.safe.global/transactions/queue?safe=oeth:0x398A2749487B2a91f2f543C01F7afD19AEE4b6b0" --nonce 48
    uv run tools/safe-tx-verify/verify_safe_tx.py "oeth:0x398A2749487B2a91f2f543C01F7afD19AEE4b6b0" --nonce 48 --onchain
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.request
import urllib.error
from pathlib import Path

from eth_utils import keccak, to_checksum_address

try:
    from eth_abi import decode as abi_decode  # eth-abi >= 4
except Exception:  # pragma: no cover
    abi_decode = None

# --- EIP-712 type hashes (computed from the canonical strings so they are self-verifying) ------------------------
DOMAIN_TYPEHASH = keccak(text="EIP712Domain(uint256 chainId,address verifyingContract)")
DOMAIN_TYPEHASH_OLD = keccak(text="EIP712Domain(address verifyingContract)")  # Safe < 1.3.0 (no chainId)
SAFE_TX_TYPEHASH = keccak(
    text="SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,"
    "uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"
)
SAFE_TX_TYPEHASH_OLD = keccak(  # Safe < 1.0.0 used `dataGas` instead of `baseGas`
    text="SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 dataGas,"
    "uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"
)

MULTISEND_SELECTOR = "0x8d80ff0a"  # multiSend(bytes)

# Safe app chain short-name (used verbatim in the tx-service path) -> (chainId, default public RPC).
# Safe deprecated the per-chain `safe-transaction-<net>.safe.global` hosts; the unified service is
# `https://api.safe.global/tx-service/<short-name>/api/v1/...` (no API key required for reads as of 2026-07).
TX_SERVICE = "https://api.safe.global/tx-service/{short}/api/v1"
CHAINS = {
    "eth":      (1,        "https://eth.llamarpc.com"),
    "oeth":     (10,       "https://mainnet.optimism.io"),
    "arb1":     (42161,    "https://arb1.arbitrum.io/rpc"),
    "base":     (8453,     "https://mainnet.base.org"),
    "matic":    (137,      "https://polygon-rpc.com"),
    "gno":      (100,      "https://rpc.gnosischain.com"),
    "bnb":      (56,       "https://bsc-dataseed.binance.org"),
    "avax":     (43114,    "https://api.avax.network/ext/bc/C/rpc"),
    "linea":    (59144,    "https://rpc.linea.build"),
    "scr":      (534352,   "https://rpc.scroll.io"),
    "celo":     (42220,    "https://forno.celo.org"),
    "blast":    (81457,    "https://rpc.blast.io"),
    "zksync":   (324,      "https://mainnet.era.zksync.io"),
    "mnt":      (5000,     "https://rpc.mantle.xyz"),
    "sep":      (11155111, "https://ethereum-sepolia-rpc.publicnode.com"),
    "basesep":  (84532,    "https://sepolia.base.org"),
    "oeth-sep": (11155420, "https://sepolia.optimism.io"),
    "arb-sep":  (421614,   "https://sepolia-rollup.arbitrum.io/rpc"),
}
CHAINID_TO_SHORT = {cid: short for short, (cid, _rpc) in CHAINS.items()}
CHAINID_TO_RPC = {cid: rpc for _, (cid, rpc) in CHAINS.items()}

_USE_COLOR = sys.stdout.isatty()


def c(text: str, code: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _USE_COLOR else text


def die(msg: str) -> "None":
    print(c(f"Error: {msg}", "31"), file=sys.stderr)
    sys.exit(1)


# --- hashing helpers -------------------------------------------------------------------------------------------
def word(value) -> bytes:
    """Left-pad an address/bytes32/int to a 32-byte EVM word."""
    if isinstance(value, str):
        h = value.lower().removeprefix("0x")
        b = bytes.fromhex(h)
        if len(b) > 32:
            die(f"value does not fit in 32 bytes: {value}")
        return b.rjust(32, b"\x00")
    if isinstance(value, int):
        return value.to_bytes(32, "big")
    raise TypeError(type(value))


def cmp_versions(a: str, b: str) -> int:
    def parts(v):
        return [int(x) for x in re.findall(r"\d+", v)]
    pa, pb = parts(a), parts(b)
    pa += [0] * (len(pb) - len(pa))
    pb += [0] * (len(pa) - len(pb))
    return (pa > pb) - (pa < pb)


def compute_hashes(tx: dict, safe: str, chain_id: int, version: str) -> dict:
    """Recompute (domainHash, messageHash, safeTxHash) from raw params. This is the trust anchor."""
    safe = to_checksum_address(safe)
    data_bytes = bytes.fromhex(tx["data"].lower().removeprefix("0x")) if tx.get("data") else b""

    # Domain separator: >= 1.3.0 binds chainId; older versions do not.
    if cmp_versions(version, "1.3.0") >= 0:
        domain_hash = keccak(word(DOMAIN_TYPEHASH.hex()) + word(chain_id) + word(safe))
    else:
        domain_hash = keccak(word(DOMAIN_TYPEHASH_OLD.hex()) + word(safe))

    tx_typehash = SAFE_TX_TYPEHASH_OLD if cmp_versions(version, "1.0.0") < 0 else SAFE_TX_TYPEHASH
    struct_hash = keccak(
        word(tx_typehash.hex())
        + word(to_checksum_address(tx["to"]))
        + word(int(tx["value"]))
        + word(keccak(data_bytes).hex())
        + word(int(tx["operation"]))
        + word(int(tx["safeTxGas"]))
        + word(int(tx["baseGas"]))
        + word(int(tx["gasPrice"]))
        + word(to_checksum_address(tx["gasToken"]))
        + word(to_checksum_address(tx["refundReceiver"]))
        + word(int(tx["nonce"]))
    )
    safe_tx_hash = keccak(b"\x19\x01" + domain_hash + struct_hash)
    return {
        "domainHash": "0x" + domain_hash.hex(),
        "messageHash": "0x" + struct_hash.hex(),  # the EIP-712 struct hash = the Ledger "message hash"
        "safeTxHash": "0x" + safe_tx_hash.hex(),
    }


# --- IO helpers ------------------------------------------------------------------------------------------------
def http_get_json(url: str, timeout: int = 20) -> dict:
    req = urllib.request.Request(url, headers={"Accept": "application/json", "User-Agent": "verify-safe-tx"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        die(f"HTTP {e.code} for {url}")
    except Exception as e:  # noqa: BLE001
        die(f"request failed for {url}: {e}")


def rpc_call(rpc: str, to: str, data: str, timeout: int = 20) -> str:
    payload = json.dumps(
        {"jsonrpc": "2.0", "id": 1, "method": "eth_call", "params": [{"to": to, "data": data}, "latest"]}
    ).encode()
    req = urllib.request.Request(rpc, data=payload, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode()).get("result", "0x")


def parse_target(target: str) -> tuple[str, str]:
    """Return (chain_prefix, checksummed_address) from 'oeth:0x..' or a Safe app URL."""
    m = re.search(r"(?:safe=)?([a-z0-9-]+):(0x[0-9a-fA-F]{40})", target)
    if not m:
        die(f"could not parse a 'chain:0xaddress' from: {target}")
    return m.group(1), to_checksum_address(m.group(2))


def repo_root() -> Path:
    p = Path(__file__).resolve()
    for parent in [p, *p.parents]:
        if (parent / "DEPLOYMENT_ADDRESSES.md").exists():
            return parent
        if (parent / "evm" / "DEPLOYMENT_ADDRESSES.md").exists():
            return parent
    return Path.cwd()


def load_address_book(root: Path) -> dict[str, str]:
    """address(lower) -> label, parsed from DEPLOYMENT_ADDRESSES.md."""
    book: dict[str, str] = {}
    for cand in (root / "DEPLOYMENT_ADDRESSES.md", root / "evm" / "DEPLOYMENT_ADDRESSES.md"):
        if not cand.exists():
            continue
        section = ""
        for line in cand.read_text().splitlines():
            h = re.match(r"##+\s+(.*)", line)
            if h:
                section = h.group(1).strip()
                continue
            cells = [x.strip() for x in line.split("|")]
            if len(cells) < 3 or cells[1] in ("Contract", "--------", ""):
                continue
            name = cells[1]
            for addr in re.findall(r"0x[0-9a-fA-F]{40}", line):
                book.setdefault(addr.lower(), f"{name} [{section}]")
        break
    return book


def load_selectors(root: Path) -> dict[str, tuple[str, list[str], list[str]]]:
    """4-byte selector -> (name, arg_types, arg_names) from this repo's compiled ABIs (evm/out)."""
    sels: dict[str, tuple[str, list[str], list[str]]] = {}
    out = root / "evm" / "out"
    if not out.exists():
        out = root / "out"
    if not out.exists():
        return sels
    for jf in out.rglob("*.json"):
        try:
            abi = json.loads(jf.read_text()).get("abi", [])
        except Exception:  # noqa: BLE001
            continue
        for item in abi:
            if item.get("type") != "function":
                continue
            types = [_canonical_type(i) for i in item.get("inputs", [])]
            names = [i.get("name", "") for i in item.get("inputs", [])]
            sig = f"{item['name']}({','.join(types)})"
            sel = "0x" + keccak(text=sig)[:4].hex()
            sels.setdefault(sel, (item["name"], types, names))
    return sels


def _canonical_type(inp: dict) -> str:
    t = inp["type"]
    if t.startswith("tuple"):
        inner = ",".join(_canonical_type(c) for c in inp.get("components", []))
        return f"({inner}){t[len('tuple'):]}"
    return t


def decode_calldata(data: str, sels: dict, book: dict, depth: int = 0) -> list[str]:
    lines: list[str] = []
    ind = "  " * depth
    data = data.lower()
    if not data or data == "0x" or len(data) < 10:
        lines.append(f"{ind}(no calldata / plain ETH transfer)")
        return lines
    selector = data[:10]
    if selector == MULTISEND_SELECTOR:
        lines.append(f"{ind}multiSend(bytes) -> batched transactions:")
        lines += decode_multisend(data, sels, book, depth + 1)
        return lines
    match = sels.get(selector)
    if not match:
        lines.append(f"{ind}selector {selector} (unknown -- not in repo ABIs)")
        return lines
    name, types, names = match
    lines.append(f"{ind}{name}({','.join(types)})")
    if abi_decode is not None:
        try:
            values = abi_decode(types, bytes.fromhex(data[10:]))
            for t, n, v in zip(types, names, values):
                lines.append(f"{ind}  {n or '_'}: {_fmt_value(t, v, book)}")
        except Exception as e:  # noqa: BLE001
            lines.append(f"{ind}  (could not decode args: {e})")
    return lines


def decode_multisend(data: str, sels: dict, book: dict, depth: int) -> list[str]:
    lines: list[str] = []
    # multiSend(bytes): after the selector, a standard ABI-encoded single `bytes` arg.
    raw = bytes.fromhex(data[10:])
    if len(raw) < 64:
        return [f"{'  ' * depth}(malformed multiSend)"]
    length = int.from_bytes(raw[32:64], "big")
    payload = raw[64:64 + length]
    i, n = 0, 0
    while i + 85 <= len(payload):
        op = payload[i]
        to = to_checksum_address(payload[i + 1:i + 21].hex())
        val = int.from_bytes(payload[i + 21:i + 53], "big")
        dlen = int.from_bytes(payload[i + 53:i + 85], "big")
        inner = payload[i + 85:i + 85 + dlen]
        i += 85 + dlen
        lines.append(
            f"{'  ' * depth}[{n}] op={op} to={_fmt_addr(to, book)} value={val}"
        )
        lines += decode_calldata("0x" + inner.hex(), sels, book, depth + 1)
        n += 1
    return lines


def _fmt_addr(addr: str, book: dict) -> str:
    label = book.get(addr.lower())
    return f"{addr} ({c(label, '36')})" if label else c(addr, "33")


def _fmt_value(t: str, v, book: dict) -> str:
    if t == "address":
        return _fmt_addr(to_checksum_address(v), book)
    if t.endswith("[]") and isinstance(v, (list, tuple)):
        return "[" + ", ".join(_fmt_value(t[:-2], x, book) for x in v) + "]"
    if isinstance(v, bytes):
        return "0x" + v.hex()
    return str(v)


# --- main ------------------------------------------------------------------------------------------------------
def main() -> None:
    ap = argparse.ArgumentParser(description="Independently verify a Safe multisig tx before signing.")
    ap.add_argument("target", help="Safe app URL or 'prefix:0xADDRESS' (e.g. oeth:0x398A...)")
    ap.add_argument("--nonce", type=int, help="Safe nonce of the queued tx to verify")
    ap.add_argument("--chain-id", type=int, help="override chain id (else derived from the prefix)")
    ap.add_argument("--version", default=None, help="Safe contract version (default 1.3.0 or on-chain with --onchain)")
    ap.add_argument("--onchain", action="store_true", help="also read nonce/threshold/owners/version via RPC")
    ap.add_argument("--rpc", help="RPC URL (else a public default for the chain)")
    ap.add_argument("--json", action="store_true", dest="as_json", help="emit machine-readable JSON")
    args = ap.parse_args()

    prefix, safe = parse_target(args.target)
    if prefix not in CHAINS and args.chain_id is None:
        die(f"unknown chain prefix '{prefix}'; pass --chain-id")
    chain_id = args.chain_id or CHAINS[prefix][0]
    short = prefix if prefix in CHAINS else CHAINID_TO_SHORT.get(chain_id)
    rpc = args.rpc or CHAINID_TO_RPC.get(chain_id)
    root = repo_root()
    book = load_address_book(root)

    version = args.version or "1.3.0"
    onchain: dict = {}
    if args.onchain:
        if not rpc:
            die("no RPC for --onchain; pass --rpc")
        try:
            onchain["nonce"] = int(rpc_call(rpc, safe, "0xaffed0e0") or "0x0", 16)
            onchain["threshold"] = int(rpc_call(rpc, safe, "0xe75235b8") or "0x0", 16)
            ver_raw = rpc_call(rpc, safe, "0xffa1ad74")  # VERSION()
            if ver_raw and len(ver_raw) > 130:
                strlen = int(ver_raw[66:130], 16)
                version = bytes.fromhex(ver_raw[130:130 + strlen * 2]).decode() or version
                if args.version:
                    version = args.version
        except Exception as e:  # noqa: BLE001
            die(f"--onchain RPC call failed: {e}")

    if args.nonce is None:
        die("pass --nonce N (the queued tx nonce to verify)")

    if not short:
        die(f"no Safe tx-service short-name known for chain {chain_id}; use a known chain prefix")
    api = f"{TX_SERVICE.format(short=short)}/safes/{safe}/multisig-transactions/?nonce={args.nonce}"
    results = http_get_json(api).get("results", [])
    if not results:
        die(f"no queued tx at nonce {args.nonce} for {safe} on chain {chain_id}")
    if len(results) > 1:
        print(c(f"WARNING: {len(results)} proposals share nonce {args.nonce}; verifying the first.", "33"),
              file=sys.stderr)
    tx = results[0]
    tx.setdefault("baseGas", tx.get("baseGas", 0))

    computed = compute_hashes(tx, safe, chain_id, version)
    backend_hash = (tx.get("safeTxHash") or "").lower()
    match = backend_hash == computed["safeTxHash"].lower()

    if args.as_json:
        print(json.dumps({
            "safe": safe, "chainId": chain_id, "version": version, "nonce": args.nonce,
            "params": {k: tx.get(k) for k in
                       ("to", "value", "data", "operation", "safeTxGas", "baseGas", "gasPrice",
                        "gasToken", "refundReceiver", "nonce")},
            "computed": computed, "backendSafeTxHash": backend_hash,
            "backendMatches": match, "onchain": onchain,
        }, indent=2))
        sys.exit(0 if match else 2)

    print(c("=== Safe transaction verification ===", "1"))
    print(f"Safe:      {_fmt_addr(safe, book)}")
    print(f"Chain:     {chain_id} ({short})   Safe version: {version}")
    print(f"Nonce:     {args.nonce}")
    if onchain:
        print(f"On-chain:  nonce={onchain.get('nonce')} threshold={onchain.get('threshold')}")
        if onchain.get("nonce", args.nonce) > args.nonce:
            print(c("  ! on-chain nonce is already past this tx's nonce", "31"))
    print()
    print(c("Ledger will show:", "1"))
    print(f"  domain hash:  {computed['domainHash']}")
    print(f"  message hash: {c(computed['messageHash'], '1;36')}   <- verify THIS on the device")
    print(f"  safeTxHash:   {computed['safeTxHash']}")
    print()
    print(f"Backend safeTxHash: {backend_hash}")
    print("  " + (c("MATCH — backend params are consistent with the hash", "1;32") if match
                  else c("MISMATCH — do NOT sign; params/hash disagree", "1;31")))
    print()
    print(c("Decoded action:", "1"))
    print(f"  to:    {_fmt_addr(to_checksum_address(tx['to']), book)}")
    print(f"  value: {tx.get('value')}   operation: {tx.get('operation')} ({'delegatecall' if int(tx.get('operation', 0)) == 1 else 'call'})")
    sels = load_selectors(root)
    for line in decode_calldata(tx.get("data") or "0x", sels, book):
        print("  " + line)
    sys.exit(0 if match else 2)


if __name__ == "__main__":
    main()
