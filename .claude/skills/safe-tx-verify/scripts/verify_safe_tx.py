#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.9"
# dependencies = []
# ///
"""Verify a Safe multisig transaction before signing on a Ledger.

Independently recomputes the Safe EIP-712 hashes (domain hash, message hash,
safeTxHash) from the raw transaction PARAMETERS — it never trusts the hash the
Safe backend returns — then decodes the calldata into a human-readable action
using THIS repo's compiled ABIs and cross-references every address against
DEPLOYMENT_ADDRESSES.md.

What your Ledger shows when signing a Safe tx is the pair (domain hash, message
hash); the message hash is the one that encodes the actual transaction, so it is
the headline value here.

Two modes:
  1. QUEUE (default) — verify a tx already queued in the Safe Transaction Service.
  2. PROPOSE (--to ...) — verify a tx you are ABOUT TO CREATE that isn't queued
     yet. You supply the raw params; the script computes the same Ledger hashes
     locally, decodes the calldata, and prints the safeTxHash the Safe UI should
     show once you create the tx. Nonce defaults to the Safe's next on-chain
     nonce (override with --nonce).

Usage (via `uv run`; plain `python3 verify_safe_tx.py …` also works):
  uv run verify_safe_tx.py "<safe-url-or-address>" [--nonce N]
                           [--chain-id N] [--version V] [--onchain] [--rpc URL]
                           [--json]
  uv run verify_safe_tx.py "<safe-url-or-address>" --to 0x... --data 0x...
                           [--value W] [--operation 0|1] [--nonce N]   # propose mode

Examples:
  uv run verify_safe_tx.py "https://app.safe.global/transactions/queue?safe=oeth:0x398A2749487B2a91f2f543C01F7afD19AEE4b6b0" --nonce 48
  uv run verify_safe_tx.py "oeth:0x398A2749487B2a91f2f543C01F7afD19AEE4b6b0" --nonce 48 --onchain
  # propose a forceWithdrawAll before it is queued:
  uv run verify_safe_tx.py "oeth:0x398A2749487B2a91f2f543C01F7afD19AEE4b6b0" \
      --to 0x521B4C065Bbdbe3E20B3727340730936912DfA46 \
      --data 0x0f0824be0000000000000000000000005cd9e6560a4a86bba1d463e8729e4f1a2651f43a --nonce 49

No Python dependencies (PEP 723 header declares none); needs only `uv` (or python3)
and `cast` (foundry) on PATH.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import urllib.request

# --- EIP-712 Safe type hashes -----------------------------------------------
DOMAIN_TYPEHASH = "0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218"      # > 1.2.0 (chainId)
DOMAIN_TYPEHASH_OLD = "0x035aff83d86937d35b32e04f0ddc6ff469290eef2f1b692d8a815c89404d4749"  # <= 1.2.0 (no chainId)
SAFE_TX_TYPEHASH = "0xbb8310d486368db6bd6f849402fdd73ad53d316b5a4b2644ad6efe0f941286d8"     # >= 1.0.0
SAFE_TX_TYPEHASH_OLD = "0x14d461bc7412367e924637b363c7bf29b8f47e2f84869f4426e5633d8af47b20" # < 1.0.0

MULTISEND_SELECTOR = "0x8d80ff0a"  # multiSend(bytes)
ZERO = "0x0000000000000000000000000000000000000000"

# Well-known Safe infrastructure singletons (chain-agnostic, not in DEPLOYMENT_ADDRESSES.md).
# NOTE: v1.3.0 shipped TWO deployments of each — the "canonical" (CREATE2, same addr everywhere)
# and the "eip155" (chain-specific replay-protected) variant. The Safe UI on a given network may
# pick EITHER, and the choice changes `to` → changes the message hash / safeTxHash. Reown's 1.3.0+L2
# Safes on Optimism build Tx-Builder batches through the **eip155 MultiSendCallOnly**
# 0xA1dabEF33b3B82c7814B6D82A79e50F4AC44102B (verified 2026-07-10), NOT the canonical 0x40A2…130D.
# So in propose mode for a batch, default the MultiSend `--to` to the eip155 address for this org.
KNOWN_SINGLETONS = {
    "0xa1dabef33b3b82c7814b6d82a79e50f4ac44102b": "MultiSendCallOnly v1.3.0 (eip155) [Safe]",
    "0x40a2accbd92bca938b02010e17a5b8929b49130d": "MultiSendCallOnly v1.3.0 (canonical) [Safe]",
    "0x998739bfdaadde7c933b942a68053933098f9eda": "MultiSend v1.3.0 (eip155) [Safe]",
    "0xa238cbeb142c10ef7ad8442c6d1f9e89e07e7761": "MultiSend v1.3.0 (canonical) [Safe]",
    "0x9641d764fc13c8b624c04430c7356c1c7c8102e2": "MultiSendCallOnly v1.4.1 [Safe]",
    "0x38869bf66a61cf6bdb996a6ae40d5853fd43b526": "MultiSend v1.4.1 [Safe]",
}
# Default MultiSend target for this org's batch propose-mode (see note above).
DEFAULT_MULTISEND = "0xA1dabEF33b3B82c7814B6D82A79e50F4AC44102B"

# Safe "short name" -> chainId (for the EIP-712 domain).
PREFIX_TO_CHAINID = {
    "eth": "1", "oeth": "10", "matic": "137", "pol": "137", "bnb": "56",
    "arb1": "42161", "avax": "43114", "gno": "100", "base": "8453",
    "zksync": "324", "sep": "11155111", "gor": "5", "base-sep": "84532",
    "arb-sep": "421614", "oeth-sep": "11155420", "linea": "59144",
    "scr": "534352", "mantle": "5000", "celo": "42220", "blast": "81457",
}
# Default public RPCs for --onchain checks (override with --rpc).
PREFIX_TO_RPC = {
    "eth": "https://eth.llamarpc.com", "oeth": "https://mainnet.optimism.io",
    "base": "https://mainnet.base.org", "arb1": "https://arb1.arbitrum.io/rpc",
    "matic": "https://polygon-rpc.com", "pol": "https://polygon-rpc.com",
    "gno": "https://rpc.gnosischain.com", "bnb": "https://bsc-dataseed.binance.org",
}
# ERC-1967 implementation slot.
IMPL_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))

C = {"b": "\033[1m", "d": "\033[2m", "g": "\033[32m", "r": "\033[31m",
     "c": "\033[36m", "y": "\033[33m", "x": "\033[0m"}


def color(s, k):
    return f"{C[k]}{s}{C['x']}" if sys.stdout.isatty() else s


def fail(msg):
    print(f"{color('Error:', 'r')} {msg}", file=sys.stderr)
    sys.exit(1)


def cast(*args, timeout=60):
    r = subprocess.run(["cast", *args], capture_output=True, text=True, timeout=timeout)
    if r.returncode != 0:
        raise RuntimeError(f"cast {' '.join(args[:2])}: {r.stderr.strip()[:200]}")
    return r.stdout.strip()


# --- hex / word helpers ------------------------------------------------------
def word(x):
    """Left-pad an address/bytes32 hex string or an integer to a 32-byte hex word (no 0x)."""
    if isinstance(x, str) and x.startswith("0x"):
        h = x[2:]
    else:
        h = format(int(x), "x")
    if len(h) > 64:
        fail(f"value does not fit in 32 bytes: {x}")
    return h.rjust(64, "0")


def concat(*words):
    return "0x" + "".join(w[2:] if w.startswith("0x") else w for w in words)


def keccak(hexdata):
    # cast keccak needs even-length hex; empty data hashes the empty byte string.
    h = hexdata if hexdata.startswith("0x") else "0x" + hexdata
    if len(h) % 2 != 0:
        fail(f"odd-length hex: {h}")
    return cast("keccak", h)


def cmp_versions(a, b):
    pa = [int(p) if p.isdigit() else 0 for p in a.split("+")[0].split(".")]
    pb = [int(p) if p.isdigit() else 0 for p in b.split("+")[0].split(".")]
    for i in range(max(len(pa), len(pb))):
        av, bv = (pa[i] if i < len(pa) else 0), (pb[i] if i < len(pb) else 0)
        if av != bv:
            return av - bv
    return 0


# --- core hash computation ---------------------------------------------------
def compute_hashes(p):
    version = (p.get("version") or "1.3.0").strip()
    if cmp_versions(version, "1.2.0") <= 0:
        domain_enc = concat(DOMAIN_TYPEHASH_OLD, word(p["safe"]))
    else:
        domain_enc = concat(DOMAIN_TYPEHASH, word(p["chainId"]), word(p["safe"]))
    domain_hash = keccak(domain_enc)

    tx_typehash = SAFE_TX_TYPEHASH_OLD if cmp_versions(version, "1.0.0") < 0 else SAFE_TX_TYPEHASH
    data_hash = keccak(p.get("data") or "0x")
    message = concat(
        tx_typehash, word(p["to"]), word(p["value"]), data_hash, word(p["operation"]),
        word(p["safeTxGas"]), word(p["baseGas"]), word(p["gasPrice"]),
        word(p["gasToken"]), word(p["refundReceiver"]), word(p["nonce"]),
    )
    message_hash = keccak(message)
    safe_tx_hash = keccak(concat("0x1901", domain_hash, message_hash))
    return {"domainHash": domain_hash, "messageHash": message_hash, "safeTxHash": safe_tx_hash}


# --- input parsing -----------------------------------------------------------
def parse_safe_input(s):
    s = s.strip()
    m = re.search(r"0x[a-fA-F0-9]{40}", s)
    if not m:
        return None
    address = m.group(0)
    prefix = "eth"
    sp = re.search(r"[?&]safe=([a-z0-9-]+):0x[a-fA-F0-9]{40}", s, re.I)
    bare = re.match(r"^([a-z0-9-]+):0x[a-fA-F0-9]{40}", s, re.I)
    if sp:
        prefix = sp.group(1).lower()
    elif bare:
        prefix = bare.group(1).lower()
    txm = re.search(r"multisig_0x[a-fA-F0-9]{40}_(0x[a-fA-F0-9]{64})", s, re.I)
    return {"address": address, "prefix": prefix, "txHash": txm.group(1) if txm else None}


# --- Safe Transaction Service (params only) ----------------------------------
def fetch_json(url):
    req = urllib.request.Request(url, headers={"Accept": "application/json", "User-Agent": "safe-tx-verify"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


# --- repo cross-reference: address labels + selector index -------------------
def load_address_labels():
    """Parse DEPLOYMENT_ADDRESSES.md -> {lower_addr: [ {name, chain, chainId} ]}.

    An address may be deployed on several chains under (usually) the same name,
    so we keep every occurrence and disambiguate by chainId at lookup time.
    """
    path = os.path.join(REPO_ROOT, "DEPLOYMENT_ADDRESSES.md")
    labels = {}
    if not os.path.exists(path):
        return labels
    chain, chain_id = "?", None
    owners = {}  # secondary labels (ProxyAdmin/Owner column) applied only if no primary
    with open(path) as f:
        for line in f:
            hm = re.match(r"^##\s+(.+?)\s*$", line)
            if hm:
                chain = hm.group(1).strip()
                cm = re.search(r"Chain ID:\s*(\d+)", chain)
                chain_id = cm.group(1) if cm else None
                continue
            cells = [c.strip() for c in line.split("|") if c.strip()]
            if len(cells) >= 2:
                am = re.search(r"0x[a-fA-F0-9]{40}", cells[1])
                name = cells[0].strip("` ")
                if am and name and name.lower() != "contract":
                    labels.setdefault(am.group(0).lower(), []).append(
                        {"name": name, "chain": chain, "chainId": chain_id})
            if len(cells) >= 3:  # owner/proxy-admin column, e.g. "`0x..` (ProxyAdmin)"
                om = re.search(r"0x[a-fA-F0-9]{40}", cells[2])
                roles = [r for r in re.findall(r"\(([^)]+)\)", cells[2]) if not r.startswith("http")]
                if om:
                    owners.setdefault(om.group(0).lower(), []).append(
                        {"name": roles[-1] if roles else "Owner/Admin", "chain": chain, "chainId": chain_id})
    for addr, entries in owners.items():
        labels.setdefault(addr, entries)
    return labels


def build_selector_index():
    """Scan evm/out/*.sol/*.json methodIdentifiers -> {selector: {sig: set(contracts)}}."""
    out_dir = os.path.join(REPO_ROOT, "evm", "out")
    index = {}
    if not os.path.isdir(out_dir):
        return index
    for sol in os.listdir(out_dir):
        sol_path = os.path.join(out_dir, sol)
        if not os.path.isdir(sol_path):
            continue
        for fn in os.listdir(sol_path):
            if not fn.endswith(".json"):
                continue
            try:
                with open(os.path.join(sol_path, fn)) as f:
                    art = json.load(f)
            except Exception:
                continue
            for sig, sel in (art.get("methodIdentifiers") or {}).items():
                sel = "0x" + sel.lower()
                index.setdefault(sel, {}).setdefault(sig, set()).add(fn[:-5])
    return index


def label_for(addr, labels, chain_id=None):
    entries = labels.get(addr.lower())
    if entries:
        e = next((x for x in entries if x["chainId"] == str(chain_id)), entries[0])
        return f"{e['name']} [{e['chain']}]"
    # Fall back to well-known Safe infra singletons (MultiSend etc.) not in DEPLOYMENT_ADDRESSES.md
    return KNOWN_SINGLETONS.get(addr.lower())


def annotate_addresses(text, labels, chain_id=None):
    """Append '(= ContractName)' after any known address appearing in text."""
    def repl(m):
        lbl = label_for(m.group(0), labels, chain_id)
        return f"{m.group(0)} {color('(= ' + lbl + ')', 'c')}" if lbl else m.group(0)
    return re.sub(r"0x[a-fA-F0-9]{40}", repl, text)


def _parse_arg_lines(sig, data):
    """cast calldata-decode prints one line per top-level argument; return them raw."""
    try:
        return cast("calldata-decode", sig, data).splitlines()
    except Exception:
        return None


def _split_array(line):
    inner = line.strip()
    if inner.startswith("[") and inner.endswith("]"):
        inner = inner[1:-1].strip()
    return [x.strip() for x in inner.split(",")] if inner else []


def expand_wrapper(sig, data):
    """If sig is a Timelock/ProxyAdmin wrapper, return [(to, value, data, note)] sub-calls, else None."""
    name = sig.split("(")[0]
    args = _parse_arg_lines(sig, data)
    if not args:
        return None
    try:
        if name in ("execute", "schedule"):  # (target, value, payload, ...)
            return [(args[0], args[1], args[2], None)]
        if name in ("executeBatch", "scheduleBatch"):  # (targets[], values[], payloads[], ...)
            tgts, vals, plds = _split_array(args[0]), _split_array(args[1]), _split_array(args[2])
            return [(tgts[i], vals[i] if i < len(vals) else "0", plds[i], None)
                    for i in range(len(tgts))]
        if name == "upgradeAndCall":  # (proxy, newImpl, data) — data runs on the new impl
            proxy, impl, payload = args[0], args[1], args[2]
            note = f"upgrade proxy {proxy} → implementation {impl}"
            return [(impl, "0", payload, note)] if payload not in ("0x", "") else [(impl, "0", "0x", note)]
        if name in ("upgradeTo",):
            return [(args[0], "0", "0x", f"upgrade to implementation {args[0]}")]
    except (IndexError, ValueError):
        return None
    return None


def decode_call(to, data, index, labels, chain_id=None, safe=None, depth=0):
    """Human-readable lines for this call; recurses into multiSend and Timelock/ProxyAdmin wrappers."""
    ind = "  " * depth
    lines = []
    data = data or "0x"

    lbl = label_for(to, labels, chain_id)
    if lbl:
        to_str = f"{to} {color('(= ' + lbl + ')', 'c')}"
    elif safe and to.lower() == safe.lower():
        to_str = f"{to} {color('(= this Safe — account/config management)', 'c')}"
    else:
        to_str = f"{to}{color(' (unknown contract)', 'y')}"

    if len(data) < 10:
        lines.append(f"{ind}{to_str}: plain value transfer (no calldata)")
        return lines

    selector = data[:10].lower()

    if selector == MULTISEND_SELECTOR:
        lines.append(f"{ind}{color('multiSend', 'b')} batch → {to_str}")
        for i, inner in enumerate(unpack_multisend(data)):
            op = "DELEGATECALL " + color("⚠", "r") if inner["operation"] == 1 else "CALL"
            lines.append(f"{ind}  [{i}] {op}  value={inner['value']}")
            lines += decode_call(inner["to"], inner["data"], index, labels, chain_id, safe, depth + 2)
        return lines

    # Resolve signature: prefer THIS repo's compiled ABIs; else public 4byte DB (flagged).
    entry = index.get(selector)
    if entry:
        sig = sorted(entry.keys())[0]
        contracts = sorted({c for cs in entry.values() for c in cs})
        src = color("[repo ABI: " + ", ".join(contracts[:3]) + "]", "d")
        verified = True
    else:
        sig = None
        try:
            sig = cast("4byte", selector).splitlines()[0].strip()
        except Exception:
            pass
        src = color("[public 4byte DB — UNVERIFIED, possible collision]", "y")
        verified = False

    lines.append(f"{ind}{to_str}")
    if not sig:
        lines.append(f"{ind}  selector {selector} {color('— not in repo ABIs or 4byte DB', 'y')}")
        lines.append(f"{ind}  raw: {data[:74] + '…' if len(data) > 74 else data}")
        return lines

    lines.append(f"{ind}  {color(sig, 'b')}  {src}")
    decoded = _parse_arg_lines(sig, data) or []
    for arg_line in decoded:
        lines.append(f"{ind}    {annotate_addresses(arg_line.strip(), labels, chain_id)}")

    # Dive into wrapper calls (Timelock schedule/execute, ProxyAdmin upgradeAndCall).
    subcalls = expand_wrapper(sig, data)
    if subcalls:
        lines.append(f"{ind}  {color('↳ inner call(s):', 'b')}")
        for j, (sto, sval, sdata, note) in enumerate(subcalls):
            if note:
                lines.append(f"{ind}    [{j}] {annotate_addresses(note, labels, chain_id)}")
            else:
                lines.append(f"{ind}    [{j}] value={sval}")
            if (sdata or "0x") == "0x" and note:
                continue  # e.g. upgrade with no initializer call — nothing more to decode
            lines += decode_call(sto, sdata, index, labels, chain_id, safe, depth + 3)
    return lines


def unpack_multisend(data):
    """Unpack multiSend(bytes) calldata into a list of inner transactions."""
    # data = 0x8d80ff0a + abi.encode(bytes). Decode the bytes arg, then walk the packed blob.
    try:
        blob = cast("calldata-decode", "multiSend(bytes)", data).strip()
    except Exception:
        return []
    b = bytes.fromhex(blob[2:] if blob.startswith("0x") else blob)
    txs, i = [], 0
    while i + 85 <= len(b):
        operation = b[i]; i += 1
        to = "0x" + b[i:i + 20].hex(); i += 20
        value = int.from_bytes(b[i:i + 32], "big"); i += 32
        dlen = int.from_bytes(b[i:i + 32], "big"); i += 32
        payload = b[i:i + dlen]; i += dlen
        txs.append({"operation": operation, "to": to, "value": str(value), "data": "0x" + payload.hex()})
    return txs


# --- optional on-chain sanity checks -----------------------------------------
def onchain_safe_nonce(address, rpc):
    """Return the Safe's current on-chain nonce, or None if unavailable.

    Safe nonces execute strictly in order, so any queued transaction whose nonce
    is BELOW this value can never execute — it's a stale leftover (superseded or
    replaced by another tx that already consumed that nonce). Best-effort: returns
    None if there's no RPC or the call fails, and staleness detection is skipped.
    """
    if not rpc:
        return None
    try:
        out = cast("call", address, "nonce()(uint256)", "--rpc-url", rpc)
        return int(out.split()[0])
    except Exception:
        return None


def onchain_checks(to, rpc):
    lines = []
    try:
        code = cast("code", to, "--rpc-url", rpc)
        if code in ("0x", ""):
            lines.append(color(f"⚠ {to} has NO code on-chain (EOA or wrong chain?)", "r"))
        else:
            lines.append(f"{to}: has code ({len(code) // 2 - 1} bytes)")
            try:
                impl = cast("storage", to, IMPL_SLOT, "--rpc-url", rpc)
                impl_addr = "0x" + impl[-40:]
                if int(impl, 16) != 0:
                    lines.append(f"  ERC-1967 proxy → implementation {impl_addr}")
            except Exception:
                pass
    except Exception as e:
        lines.append(color(f"on-chain check skipped: {e}", "y"))
    return lines


# --- main --------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("input", help="Safe URL or address (optionally prefixed, e.g. oeth:0x...)")
    ap.add_argument("--nonce")
    ap.add_argument("--chain-id", dest="chain_id")
    ap.add_argument("--version")
    ap.add_argument("--onchain", action="store_true", help="run cast on-chain sanity checks")
    ap.add_argument("--rpc")
    ap.add_argument("--json", action="store_true")
    # --- propose mode: verify a tx you are about to CREATE (not yet queued) ---
    # Supply the raw params; the script computes the same Ledger hashes locally,
    # decodes the calldata, and prints the safeTxHash to expect in the Safe UI.
    ap.add_argument("--to", help="propose mode: target address of the tx you will create")
    ap.add_argument("--data", help="propose mode: calldata (0x...) — default 0x")
    ap.add_argument("--value", default="0", help="propose mode: wei value (default 0)")
    ap.add_argument("--operation", default="0", help="propose mode: 0=CALL, 1=DELEGATECALL (default 0)")
    ap.add_argument("--safe-tx-gas", dest="safe_tx_gas", default="0")
    ap.add_argument("--base-gas", dest="base_gas", default="0")
    ap.add_argument("--gas-price", dest="gas_price", default="0")
    ap.add_argument("--gas-token", dest="gas_token", default=ZERO)
    ap.add_argument("--refund-receiver", dest="refund_receiver", default=ZERO)
    a = ap.parse_args()

    parsed = parse_safe_input(a.input)
    if not parsed:
        fail(f"could not find a Safe address in: {a.input}")
    address, prefix, tx_hash = parsed["address"], parsed["prefix"], parsed["txHash"]

    chain_id = a.chain_id or PREFIX_TO_CHAINID.get(prefix)
    if not chain_id:
        fail(f'unknown network short-name "{prefix}"; pass --chain-id.')

    rpc = a.rpc or PREFIX_TO_RPC.get(prefix)
    base = f"https://api.safe.global/tx-service/{prefix}/api/v1"

    version = a.version
    if not version:
        try:
            version = fetch_json(f"{base}/safes/{address}/").get("version") or "1.3.0"
        except Exception as e:
            version = "1.3.0"
            print(color(f"warn: could not fetch Safe version ({e}); assuming {version}", "y"), file=sys.stderr)

    propose = a.to is not None
    if propose:
        # No queued tx to fetch — build the params from the flags directly.
        nonce = a.nonce
        if nonce is None:
            nonce = onchain_safe_nonce(address, rpc)
            if nonce is None:
                fail("propose mode: could not read the Safe's on-chain nonce; pass --nonce N "
                     "(the next nonce the Safe will use).")
            # nonce() is the next-to-EXECUTE; a new tx queued behind already-pending
            # ones takes the next FREE slot (max queued nonce + 1). Reconcile so we
            # don't compute hashes for a nonce that's already taken.
            try:
                pend = fetch_json(f"{base}/safes/{address}/multisig-transactions/"
                                  f"?executed=false&limit=100").get("results") or []
                queued = [int(t["nonce"]) for t in pend if t.get("nonce") is not None]
                next_free = max([nonce] + [n + 1 for n in queued]) if queued else nonce
            except Exception:
                next_free = nonce
            if next_free != nonce:
                print(color(f"note: on-chain next-to-execute nonce is {nonce}, but "
                            f"transaction(s) are already queued ahead — a NEW tx takes "
                            f"nonce {next_free}. Using {next_free} (override with --nonce).", "y"),
                      file=sys.stderr)
                nonce = next_free
            else:
                print(color(f"note: using the Safe's next nonce {nonce} "
                            f"(override with --nonce)", "d"), file=sys.stderr)
        params = {
            "safe": address, "chainId": chain_id, "version": version,
            "to": a.to, "value": a.value, "data": a.data or "0x",
            "operation": a.operation, "safeTxGas": a.safe_tx_gas, "baseGas": a.base_gas,
            "gasPrice": a.gas_price, "gasToken": a.gas_token,
            "refundReceiver": a.refund_receiver, "nonce": nonce,
        }
        api_hash = None
        api_method = None
        return _report(a, params, prefix, address, chain_id, version, rpc,
                       api_hash, api_method, propose=True)

    try:
        listing = fetch_json(f"{base}/safes/{address}/multisig-transactions/?executed=false&limit=100")
    except Exception as e:
        fail(f"failed to fetch pending transactions: {e}")
    results = listing.get("results") or []
    if not results:
        fail(f"no pending transactions for {prefix}:{address}")

    # Safe nonces execute strictly in order: any queued tx with nonce < the
    # Safe's current on-chain nonce can NEVER execute (stale/superseded).
    current_nonce = onchain_safe_nonce(address, rpc)

    def is_stale(n):
        return current_nonce is not None and n is not None and int(n) < current_nonce

    if a.nonce is not None:
        tx = next((t for t in results if str(t.get("nonce")) == str(a.nonce)), None)
        if not tx:
            fail(f"no pending transaction with nonce {a.nonce}")
    elif tx_hash:
        tx = next((t for t in results if (t.get("safeTxHash") or "").lower() == tx_hash.lower()), None)
        if not tx:
            fail(f"tx {tx_hash} not found in pending queue")
    else:
        nonces = sorted({t.get("nonce") for t in results})
        # Only nonces >= the current on-chain nonce can actually execute.
        live_txs = [t for t in results if not is_stale(t.get("nonce"))]
        live_nonces = sorted({t.get("nonce") for t in live_txs})
        if len(live_txs) == 1:
            tx = live_txs[0]
        elif len(live_txs) == 0:
            fail(f"all {len(results)} pending transaction(s) are stale (below the Safe's "
                 f"current on-chain nonce {current_nonce}) — none can execute.")
        else:
            stale_nonces = [n for n in nonces if is_stale(n)]
            print("Multiple pending transactions queued.", file=sys.stderr)
            if current_nonce is not None:
                print(f"Safe current on-chain nonce: {current_nonce} "
                      f"(anything below it can never execute).", file=sys.stderr)

            def status(n):
                if is_stale(n):
                    return " [STALE — can never execute, superseded]"
                if current_nonce is not None and n == current_nonce:
                    return " [next to execute]"
                return " [queued]" if current_nonce is not None else ""

            # Live transactions first, stale ones last.
            for t in sorted(results, key=lambda x: (is_stale(x.get("nonce")), x.get("nonce") or 0)):
                print(f"  nonce {t.get('nonce')}{status(t.get('nonce'))}  to {t.get('to')}  "
                      f"method {(t.get('dataDecoded') or {}).get('method', '(raw)')}", file=sys.stderr)
            pick = live_nonces if current_nonce is not None else nonces
            note = f" (ignore stale {', '.join(map(str, stale_nonces))})" if stale_nonces else ""
            print(f"\nRe-run with --nonce <n> — live nonces: {', '.join(map(str, pick))}{note}.",
                  file=sys.stderr)
            sys.exit(2)

    if is_stale(tx.get("nonce")):
        print(color(f"⚠ nonce {tx.get('nonce')} is below the Safe's current on-chain nonce "
                    f"{current_nonce} — this transaction can NEVER execute (already superseded). "
                    f"Verifying anyway for inspection.", "y"), file=sys.stderr)

    params = {
        "safe": address, "chainId": chain_id, "version": version,
        "to": tx.get("to") or ZERO, "value": tx.get("value") or "0",
        "data": tx.get("data") or "0x", "operation": tx.get("operation") or 0,
        "safeTxGas": tx.get("safeTxGas") or 0, "baseGas": tx.get("baseGas") or 0,
        "gasPrice": tx.get("gasPrice") or "0", "gasToken": tx.get("gasToken") or ZERO,
        "refundReceiver": tx.get("refundReceiver") or ZERO, "nonce": tx.get("nonce"),
    }
    api_hash = tx.get("safeTxHash")
    api_method = (tx.get("dataDecoded") or {}).get("method")
    return _report(a, params, prefix, address, chain_id, version, rpc,
                   api_hash, api_method, propose=False)


def _report(a, params, prefix, address, chain_id, version, rpc, api_hash, api_method, propose):
    """Compute hashes, decode calldata, and print the verification report.

    Shared by both the queue path (api_hash from the Safe backend, cross-checked)
    and the propose path (no backend tx yet — api_hash is None and the computed
    safeTxHash is what the Safe UI should show once the tx is created).
    """
    computed = compute_hashes(params)
    match = bool(api_hash) and api_hash.lower() == computed["safeTxHash"].lower()

    labels = load_address_labels()
    index = build_selector_index()
    decoded_lines = decode_call(params["to"], params["data"], index, labels, chain_id, safe=address)

    if a.json:
        print(json.dumps({
            "network": prefix, "chainId": chain_id, "version": version, "mode": "propose" if propose else "queue",
            "params": params, "computed": computed, "apiSafeTxHash": api_hash, "apiMatch": match,
            "decoded": [re.sub(r"\033\[[0-9;]*m", "", ln) for ln in decoded_lines],
        }, indent=2))
        return

    print()
    if propose:
        print(color("PROPOSE MODE — hashes for a tx you are about to CREATE (nothing queued yet).", "y"))
        print()
    print(color("👉 CHECK THIS ON YOUR LEDGER — Message hash:", "b"))
    print(color(color(f"   {computed['messageHash']}", "c"), "b"))
    print()
    print(color("   Supporting values (all computed locally — nothing trusted from the API):", "d"))
    print(color(f"   Domain hash:  {computed['domainHash']}   (also on the Ledger; = chainId {chain_id} + safe addr)", "d"))
    print(color(f"   SafeTxHash:   {computed['safeTxHash']}   (Safe/Etherscan label; not on the Ledger)", "d"))
    print("─" * 78)
    print(f"Safe:      {prefix}:{address}  ·  version {version}  ·  nonce {params['nonce']}")
    op = "DELEGATECALL " + color("⚠", "r") if int(params["operation"]) == 1 else "CALL"
    print(f"Operation: {params['operation']} ({op})   Value: {params['value']}")
    if api_method:
        print(color(f"Safe backend decoded this as: {api_method}", "d"))
    print()
    print(color("What this transaction does (decoded from THIS repo's ABIs):", "b"))
    for ln in decoded_lines:
        print("  " + ln)
    print("─" * 78)
    if propose:
        print(color("ℹ Propose mode: no queued tx to cross-check against. After you create the tx in "
                    "the Safe UI, confirm it shows the SafeTxHash above — and that your Ledger shows "
                    "the message + domain hash above — before signing.", "c"))
    elif api_hash:
        print(color("✓ safeTxHash matches Safe API (independent cross-check passed)", "g") if match
              else color(f"✗ MISMATCH vs Safe API {api_hash} — DO NOT SIGN, investigate.", "r"))

    if a.onchain:
        print()
        if not rpc:
            print(color(f"on-chain checks skipped: no RPC for {prefix} (pass --rpc)", "y"))
        else:
            print(color(f"On-chain sanity ({prefix}):", "b"))
            for ln in onchain_checks(params["to"], rpc):
                print("  " + ln)

    if api_hash and not match:
        sys.exit(3)


if __name__ == "__main__":
    main()
