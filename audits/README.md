# Security Audits

Third-party security audits for the Reown (fka WalletConnect) protocol smart contracts.

> ⚠️ **Disclaimer**: Audits are not a guarantee of correctness. Some components may have been modified after being
> audited.

---

## Deployed Contract Audit Coverage

### Optimism Mainnet (Chain ID: 10)

See [DEPLOYMENT_ADDRESSES.md](../DEPLOYMENT_ADDRESSES.md) for complete deployment details.

| Contract                              | Address                                                                                               | Audits                                                                               | Status      |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | ----------- |
| **L2WCT Token**                       | [`0xeF44...7945`](https://optimistic.etherscan.io/address/0xeF4461891DfB3AC8572cCf7C794664A8DD927945) | [#1](#1-halborn-aug-2024), [#6](#6-halborn-mar-2025)                                 | ✅ 2 audits |
| **StakeWeight**                       | [`0x521B...fA46`](https://optimistic.etherscan.io/address/0x521B4C065Bbdbe3E20B3727340730936912DfA46) | [#2](#2-halborn-oct-2024), [#3](#3-halborn-nov-2024), [#7](#7-cantina-p3-upgrade)    | ✅ 3 audits |
| **StakingRewardDistributor**          | [`0xF368...fCAF`](https://optimistic.etherscan.io/address/0xF368F535e329c6d08DFf0d4b2dA961C4e7F3fCAF) | [#2](#2-halborn-oct-2024), [#4](#4-halborn-jan-8-2025), [#7](#7-cantina-p3-upgrade)  | ✅ 3 audits |
| **StakingRewardsCalculator**          | [`0x5581...BcC3`](https://optimistic.etherscan.io/address/0x5581e8C58bD9Ad4B3A88a5250deBa164938dBcC3) | [#5](#5-halborn-jan-30-2025)                                                         | ✅ 1 audit  |
| **Airdrop**                           | [`0x4ee9...3fb4`](https://optimistic.etherscan.io/address/0x4ee97a759AACa2EdF9c1445223b6Cd17c2eD3fb4) | [#2](#2-halborn-oct-2024)                                                            | ✅ 1 audit  |
| **Pauser**                            | [`0x9163...adE7`](https://optimistic.etherscan.io/address/0x9163de7F22A9f3ad261B3dBfbB9A42886816adE7) | [#3](#3-halborn-nov-2024)                                                            | ✅ 1 audit  |
| **WalletConnectConfig**               | [`0xd2f1...78B3`](https://optimistic.etherscan.io/address/0xd2f149fAA66DC4448176123f850C14Ff14f978B3) | [#3](#3-halborn-nov-2024), [#5](#5-halborn-jan-30-2025), [#7](#7-cantina-p3-upgrade) | ✅ 3 audits |
| **LockedTokenStaker** (Backers)       | [`0x688C...0176`](https://optimistic.etherscan.io/address/0x688CfB3e55fCE2540b5491E923Dc6a9C4f240176) | [#3](#3-halborn-nov-2024), [#7](#7-cantina-p3-upgrade)                               | ✅ 2 audits |
| **LockedTokenStaker** (Reown)         | [`0x5f63...B9B2`](https://optimistic.etherscan.io/address/0x5f630a47DE14e346fC28deB8fE379833A6F6B9B2) | [#3](#3-halborn-nov-2024), [#7](#7-cantina-p3-upgrade)                               | ✅ 2 audits |
| **LockedTokenStaker** (WalletConnect) | [`0x8621...10FA`](https://optimistic.etherscan.io/address/0x8621034C9acD397cc5921d036225f75699c710FA) | [#3](#3-halborn-nov-2024), [#7](#7-cantina-p3-upgrade)                               | ✅ 2 audits |

**All deployed contracts have been audited** ✅

_Note: MerkleVester contracts (Magna code) are excluded from this audit summary_

---

## Audit Reports

All audits listed chronologically.

### 1. Halborn Aug 2024

**Halborn** • Aug 28 - Sep 2, 2024 • Commit
[`e9d2f4d`](https://github.com/WalletConnectFoundation/contracts/commit/e9d2f4d)

📄 [20240902_halborn_wct-l2wct-token.pdf](./20240902_halborn_wct-l2wct-token.pdf)

**Scope**: `src/WCT.sol`, `src/L2WCT.sol`, `src/Timelock.sol`, `script/Base.s.sol`, `script/deploy/EthereumDeploy.s.sol`, `script/deploy/OptimismDeploy.s.sol`, `script/helpers/Proxy.sol`

**Findings**: 2 Low, 3 Info → **All fixed**

---

### 2. Halborn Oct 2024

**Halborn** • Oct 23 - Nov 1, 2024 • Commit
[`74de69f`](https://github.com/WalletConnectFoundation/contracts/commit/74de69f)

📄 [20241101_halborn_stakeweight-distributor-airdrop.pdf](./20241101_halborn_stakeweight-distributor-airdrop.pdf)

**Scope**: `StakeWeight.sol`, `StakingRewardDistributor.sol`, `Airdrop.sol`

**Findings**: 2 Low, 3 Info → **All fixed**

---

### 3. Halborn Nov 2024

**Halborn** • Nov 12-15, 2024 • Commit [`26afde9`](https://github.com/WalletConnectFoundation/contracts/commit/26afde9)

📄
[20241115_halborn_infrastructure-pauser-config-staker.pdf](./20241115_halborn_infrastructure-pauser-config-staker.pdf)

**Scope**: `Pauser.sol`, `WalletConnectConfig.sol`, `LockedTokenStaker.sol`, `StakeWeight.sol`

**Findings**: 1 Low, 5 Info → **All addressed**

---

### 4. Halborn Jan 8 2025

**Halborn** • Jan 8, 2025 • Commit [`710ebed`](https://github.com/WalletConnectFoundation/contracts/commit/710ebed)

📄 [20250108_halborn_transfer-restrictions-fix.pdf](./20250108_halborn_transfer-restrictions-fix.pdf)

**Scope**: `StakingRewardDistributor.sol`, `StakeWeight.sol` transfer restrictions

**Findings**: 0 findings → **Fixes verified**

---

### 5. Halborn Jan 30 2025

**Halborn** • Jan 29-30, 2025 • Commit [`4651755`](https://github.com/WalletConnectFoundation/contracts/commit/4651755)

📄 [20250130_halborn_rewards-calculator.pdf](./20250130_halborn_rewards-calculator.pdf)

**Scope**: `StakingRewardsCalculator.sol`, `WalletConnectConfig.sol`

**Findings**: 2 Info → **All fixed**

---

### 6. Halborn Mar 2025

**Halborn** • Mar 20-24, 2025 • Commit [`4d34ec3`](https://github.com/WalletConnectFoundation/contracts/commit/4d34ec3)

📄 [20250324_halborn_l2wct-upgrade.pdf](./20250324_halborn_l2wct-upgrade.pdf)

**Scope**: `src/interfaces/IERC7802.sol`, `src/interfaces/INttToken.sol`, `src/L2WCT.sol`, `src/WCT.sol`, `src/NttTokenUpgradeable.sol`

**Findings**: 1 Info → **Fixed (deprecated storage renamed in `evm/src/L2WCT.sol:45-53`)**

---

### 7. Cantina P3 Upgrade

**Cantina/Spearbit** • Sep 28 - Oct 5, 2025 (report published Oct 14, 2025) • Commit
[`299e7ba1`](https://github.com/WalletConnectFoundation/contracts/commit/299e7ba1)

📄 [20251014_cantina_p3-permanent-staking-upgrade.pdf](./20251014_cantina_p3-permanent-staking-upgrade.pdf)

**Scope**: `StakeWeight.sol`, `StakingRewardDistributor.sol`, `LockedTokenStaker.sol`, plus operational interactions with MerkleVester (WalletConnectConfig not audited in this review)

**Findings**: 1 Medium, 4 Low, 9 Info/Gas → **9 fixed / 5 acknowledged**

---

## Security Summary

### Overall Statistics

- **Total Audits**: 7
- **Security Firms**: Cantina/Spearbit (1), Halborn (6)
- **Review Period**: Aug 2024 - Oct 2025
- **Total Findings**: 33
  - 🔴 Critical: 0
  - 🟠 High: 0
  - 🟡 Medium: 1 (fixed)
  - 🟢 Low: 9 (7 fixed, 2 acknowledged)
  - ℹ️ Info/Gas: 23 (20 fixed, 3 acknowledged)

**✅ All critical findings addressed** (1 informational pending in latest upgrade)

### Coverage by Contract Type

| Component                      | # Audits | Latest   |
| ------------------------------ | -------- | -------- |
| Token Contracts (WCT/L2WCT)    | 2        | Mar 2025 |
| Core Staking (StakeWeight)     | 4        | Oct 2025 |
| Reward Distribution            | 3        | Oct 2025 |
| Infrastructure (Pauser/Config) | 3        | Oct 2025 |
| Locked Token Staker            | 2        | Oct 2025 |
| Airdrop                        | 1        | Oct 2024 |
| Rewards Calculator             | 1        | Jan 2025 |

---

## Resources

- 🌐 [DEPLOYMENT_ADDRESSES.md](../DEPLOYMENT_ADDRESSES.md) - All deployment addresses
