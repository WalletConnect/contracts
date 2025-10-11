# P3 Staking Upgrade - Execution Guide for Signers

> **Complete step-by-step guide for the atomic upgrade of Pauser, StakeWeight, StakingRewardDistributor, and LockedTokenStakers**

## 📋 Executive Summary

This upgrade enables **Perpetual Staking** (P3) for WCT tokens on Optimism. All operations will be executed **atomically** in a single timelock batch after a 7-day delay.

### What Changes:
- ✅ **Pauser**: Add StakingRewardDistributor pause flag
- ✅ **StakeWeight**: Enable permanent locks with user-triggered unlocking
- ✅ **StakingRewardDistributor**: Migrate from Ownable to AccessControl
- ✅ **LockedTokenStakers** (3x): Fix permanent lock vesting protection bug

### Zero Downtime:
- No pause required
- All existing positions preserved
- Rewards continue uninterrupted
- Storage layout validated with OpenZeppelin plugin

---

## 🔑 Key Addresses

### Governance & Control
| Role | Address | Description |
|------|---------|-------------|
| **Admin Timelock** | `0x61cc6aF18C351351148815c5F4813A16DEe7A7E4` | 7-day delay, controls all upgrades |
| **Treasury Multisig** | `0xa86Ca428512D0A18828898d2e656E9eb1b6bA6E7` | Gets REWARD_MANAGER_ROLE |
| **Admin Multisig (Proposer)** | `0x398A2749487B2a91f2f543C01F7afD19AEE4b6b0` | Proposes timelock operations |

### Proxy Admins (All owned by Admin Timelock)
| Contract | ProxyAdmin | Proxy |
|----------|------------|-------|
| Pauser | `0x8714E77FA6Aca75A9b21d79295ec7cF04E4821a8` | `0x9163de7F22A9f3ad261B3dBfbB9A42886816adE7` |
| StakeWeight | `0x9898b105fe3679f2d31c3A06B58757D913D88e5F` | `0x521B4C065Bbdbe3E20B3727340730936912DfA46` |
| StakingRewardDistributor | `0x28672bf553c6AB214985868f68A3a491E227aCcB` | `0xF368F535e329c6d08DFf0d4b2dA961C4e7F3fCAF` |

### MerkleVesters & Benefactors
| Vester | Address | Benefactor (POST_CLAIM_HANDLER_MANAGER) |
|--------|---------|----------|
| Reown | `0x648bddEE207da25e19918460c1Dc9F462F657a19` | `0x6f99ee719c2628288372e9972a136d44bddda8e4` |
| WalletConnect | `0x85d0964D328563D502867FF6899C6F73D2E59FD1` | `0xcc97929655e472c2ad608acd854c03fa15899e31` |
| Backers | `0x2FF1Cdf8Fe00Ae6952BAA32e37D84D31A31E2EC2` | `0xcc97929655e472c2ad608acd854c03fa15899e31` |

### Old LockedTokenStakers (NON-PROXY, have permanent lock bug)
| Name | Address | Status |
|------|---------|--------|
| LockedTokenStakerReown | `0x5f630a47DE14e346fC28deB8fE379833A6F6B9B2` | ⚠️ Will be deprecated |
| LockedTokenStakerWalletConnect | `0x8621034C9acD397cc5921d036225f75699c710FA` | ⚠️ Will be deprecated |
| LockedTokenStakerBackers | `0x688CfB3e55fCE2540b5491E923Dc6a9C4f240176` | ⚠️ Will be deprecated |

---

## 📦 Phase 1: Deploy New Implementations

> **Execute these deployments BEFORE scheduling the timelock batch**

**Run the deployment script:**
```bash
forge script script/deploy/P3Upgrade.s.sol:P3Upgrade --sig "run()" \
    --rpc-url $OPTIMISM_RPC_URL --broadcast
```

This will:
1. Deploy all 3 new implementations (with storage validation)
2. Deploy all 3 new LockedTokenStaker proxies
3. Write deployment data to `deployments/10-p3-upgrade.json`

**Alternative: Deploy separately:**

### 1.1 Deploy Pauser Implementation
```solidity
// Deploy new Pauser with StakingRewardDistributor pause support
Pauser newPauserImpl = new Pauser();
```
**Save address:** `NEW_PAUSER_IMPL`

### 1.2 Deploy StakeWeight Implementation
```solidity
// Deploy new StakeWeight with permanent lock support
StakeWeight newStakeWeightImpl = new StakeWeight();
```
**Save address:** `NEW_STAKEWEIGHT_IMPL`

**Note:** Storage layout validation is performed automatically during `deployImplementations()` using the OpenZeppelin Foundry Upgrades plugin.

### 1.3 Deploy StakingRewardDistributor Implementation
```solidity
// Deploy new SRD with AccessControl
StakingRewardDistributor newSRDImpl = new StakingRewardDistributor();
```
**Save address:** `NEW_SRD_IMPL`

### 1.4 Deploy NEW LockedTokenStakers with TransparentUpgradeableProxy (3x)

> ⚠️ **Important:** Old LockedTokenStakers are NOT proxies and have the permanent lock bug. We're deploying fresh implementations wrapped in proxies for upgradeability.

**ProxyAdmin Topology:**
The deployment script uses OpenZeppelin v5's `TransparentUpgradeableProxy` with `initialOwner` parameter, which **auto-deploys a separate ProxyAdmin for each proxy** and transfers ownership to the specified owner (Admin Timelock). This is the standard OZ v5 pattern.

**Deployment via script:**
```bash
# Run the deployment script which handles CREATE2, ProxyAdmin creation, and initialization
forge script script/deploy/P3Upgrade.s.sol:P3Upgrade --sig "deployLockedTokenStakers()" \
    --rpc-url $OPTIMISM_RPC_URL --broadcast
```

The script deploys 3 new LockedTokenStaker proxies using the `newLockedTokenStaker` helper:
- **Reown** (identifier: `"reown-p3"`)
- **WalletConnect** (identifier: `"walletconnect-p3"`)
- **Backers** (identifier: `"backers-p3"`)

Each deployment:
1. Deploys implementation contract via CREATE2
2. Deploys TransparentUpgradeableProxy via CREATE2 (using same salt)
3. Proxy auto-deploys its own ProxyAdmin
4. ProxyAdmin ownership transferred to Admin Timelock (`0x61cc6aF18C351351148815c5F4813A16DEe7A7E4`)
5. Proxy initialized with vester and config addresses

**Save addresses from deployment output:**
- `LTS_REOWN_PROXY` (proxy - this is what gets whitelisted)
- `LTS_WALLETCONNECT_PROXY`
- `LTS_BACKERS_PROXY`

**Verification:**
```bash
# Get proxy addresses from deployment JSON
cat deployments/10-p3-upgrade.json | jq '.LockedTokenStakerReownP3.proxy'
cat deployments/10-p3-upgrade.json | jq '.LockedTokenStakerWalletConnectP3.proxy'
cat deployments/10-p3-upgrade.json | jq '.LockedTokenStakerBackersP3.proxy'

# Verify each proxy is initialized with correct vester
cast call LTS_REOWN_PROXY "vesterContract()(address)" --rpc-url $OPTIMISM_RPC_URL
# Should return: 0x648bddEE207da25e19918460c1Dc9F462F657a19

cast call LTS_WALLETCONNECT_PROXY "vesterContract()(address)" --rpc-url $OPTIMISM_RPC_URL
# Should return: 0x85d0964D328563D502867FF6899C6F73D2E59FD1

cast call LTS_BACKERS_PROXY "vesterContract()(address)" --rpc-url $OPTIMISM_RPC_URL
# Should return: 0x2FF1Cdf8Fe00Ae6952BAA32e37D84D31A31E2EC2

# Verify ProxyAdmin ownership (each proxy has its own ProxyAdmin)
# Get ProxyAdmin address for each proxy
cast call LTS_REOWN_PROXY "admin()(address)" --rpc-url $OPTIMISM_RPC_URL
# Then verify that ProxyAdmin's owner is Admin Timelock
cast call <PROXY_ADMIN_ADDRESS> "owner()(address)" --rpc-url $OPTIMISM_RPC_URL
# Should return: 0x61cc6aF18C351351148815c5F4813A16DEe7A7E4
```

---

## ⚡ Phase 2: Atomic Timelock Batch (Admin Timelock)

> **Single `scheduleBatch` call executing all operations after 7-day delay**

### 2.0 Generate Timelock Calldata

After Phase 1 deployment completes, generate the exact calldata for the timelock batch:

```bash
# Extract implementation addresses from deployment JSON
PAUSER_IMPL=$(cat deployments/10-p3-upgrade.json | jq -r '.NewImplementations.Pauser')
STAKEWEIGHT_IMPL=$(cat deployments/10-p3-upgrade.json | jq -r '.NewImplementations.StakeWeight')
SRD_IMPL=$(cat deployments/10-p3-upgrade.json | jq -r '.NewImplementations.StakingRewardDistributor')

# Generate calldata
forge script script/deploy/P3Upgrade.s.sol:P3Upgrade \
    --sig "logTimelockCalldata(address,address,address)" \
    $PAUSER_IMPL $STAKEWEIGHT_IMPL $SRD_IMPL \
    --rpc-url $OPTIMISM_RPC_URL
```

This will output the encoded calldata for all 3 upgrade operations. **Save this output** for use in the multisig.

### 2.1 Prepare Batch Data

```solidity
address[] memory targets = new address[](3); // Only upgrades
uint256[] memory values = new uint256[](3);
bytes[] memory payloads = new bytes[](3);

// ========== Operation 0: Upgrade Pauser ==========
targets[0] = 0x8714E77FA6Aca75A9b21d79295ec7cF04E4821a8; // Pauser ProxyAdmin
values[0] = 0;
payloads[0] = abi.encodeWithSelector(
    ProxyAdmin.upgradeAndCall.selector,
    0x9163de7F22A9f3ad261B3dBfbB9A42886816adE7, // Pauser Proxy
    NEW_PAUSER_IMPL,
    "" // no initialization
);

// ========== Operation 1: Upgrade StakeWeight ==========
targets[1] = 0x9898b105fe3679f2d31c3A06B58757D913D88e5F; // StakeWeight ProxyAdmin
values[1] = 0;
payloads[1] = abi.encodeWithSelector(
    ProxyAdmin.upgradeAndCall.selector,
    0x521B4C065Bbdbe3E20B3727340730936912DfA46, // StakeWeight Proxy
    NEW_STAKEWEIGHT_IMPL,
    "" // no initialization
);

// ========== Operation 2: Upgrade StakingRewardDistributor ==========
targets[2] = 0x28672bf553c6AB214985868f68A3a491E227aCcB; // SRD ProxyAdmin
values[2] = 0;
payloads[2] = abi.encodeWithSelector(
    ProxyAdmin.upgradeAndCall.selector,
    0xF368F535e329c6d08DFf0d4b2dA961C4e7F3fCAF, // SRD Proxy
    NEW_SRD_IMPL,
    abi.encodeWithSelector(
        StakingRewardDistributor.migrateToAccessControl.selector
    ) // Atomic migration to AccessControl
);

// ========== NOTE: Role management and MerkleVester whitelist changes ==========
// These operations are NOT in the timelock batch because:
// 1. Must happen AFTER StakeWeight upgrade (to ensure P3 support is live)
// 2. Can be executed immediately by Admin Multisig (no 7-day delay)
// 3. Coordinated with Benefactor multisig actions
// See Phase 3 below for these operations
```

**Timelock Parameters:**
```solidity
bytes32 predecessor = bytes32(0);
bytes32 salt = keccak256("P3_STAKING_UPGRADE_ATOMIC_2025");
uint256 delay = 7 days; // Admin Timelock MIN_DELAY
```

### 2.2 Schedule Batch (Admin Multisig → Admin Timelock)

```solidity
// Called by Admin Multisig (0x398A2749487B2a91f2f543C01F7afD19AEE4b6b0)
AdminTimelock(0x61cc6aF18C351351148815c5F4813A16DEe7A7E4).scheduleBatch(
    targets,   // [PauserProxyAdmin, StakeWeightProxyAdmin, SRDProxyAdmin]
    values,    // [0, 0, 0]
    payloads,  // [pauserUpgrade, stakeWeightUpgrade, srdUpgradeAndMigrate]
    predecessor,
    salt,
    delay
);
```

**Verification:**
```bash
# Get operation ID
cast keccak $(cast abi-encode "hashOperationBatch(address[],uint256[],bytes[],bytes32,bytes32)" "[0x8714E77FA6Aca75A9b21d79295ec7cF04E4821a8,0x9898b105fe3679f2d31c3A06B58757D913D88e5F,0x28672bf553c6AB214985868f68A3a491E227aCcB]" "[0,0,0]" "[PAYLOADS_ARRAY]" "0x0000000000000000000000000000000000000000000000000000000000000000" "$(cast keccak 'P3_STAKING_UPGRADE_ATOMIC_2025')")

# Check operation status
cast call 0x61cc6aF18C351351148815c5F4813A16DEe7A7E4 "isOperationPending(bytes32)(bool)" OPERATION_ID --rpc-url $OPTIMISM_RPC_URL

# Check ready timestamp
cast call 0x61cc6aF18C351351148815c5F4813A16DEe7A7E4 "getTimestamp(bytes32)(uint256)" OPERATION_ID --rpc-url $OPTIMISM_RPC_URL
```

### 2.3 Execute Batch (After 7 Days)

⏰ **Wait for:** `block.timestamp >= readyTimestamp`

```solidity
// Called by Admin Multisig
AdminTimelock(0x61cc6aF18C351351148815c5F4813A16DEe7A7E4).executeBatch(
    targets,
    values,
    payloads,
    predecessor,
    salt
);
```

**Post-Execution Verification:**
```bash
# Verify Pauser upgrade
cast call 0x9163de7F22A9f3ad261B3dBfbB9A42886816adE7 "isStakingRewardDistributorPaused()(bool)" --rpc-url $OPTIMISM_RPC_URL
# Should support new function

# Verify StakeWeight upgrade
cast call 0x521B4C065Bbdbe3E20B3727340730936912DfA46 "permanentSupply()(uint256)" --rpc-url $OPTIMISM_RPC_URL
# Should support new function

# Verify SRD AccessControl migration
cast call 0xF368F535e329c6d08DFf0d4b2dA961C4e7F3fCAF "hasRole(bytes32,address)(bool)" 0x0000000000000000000000000000000000000000000000000000000000000000 0x61cc6aF18C351351148815c5F4813A16DEe7A7E4 --rpc-url $OPTIMISM_RPC_URL
# Should return true (Timelock has DEFAULT_ADMIN_ROLE)

cast call 0xF368F535e329c6d08DFf0d4b2dA961C4e7F3fCAF "hasRole(bytes32,address)(bool)" $(cast keccak "REWARD_MANAGER_ROLE") 0xa86Ca428512D0A18828898d2e656E9eb1b6bA6E7 --rpc-url $OPTIMISM_RPC_URL
# Should return true (Treasury has REWARD_MANAGER_ROLE)
```

---

## 🔗 Phase 3: Role Management & MerkleVester Whitelist

> **Executed by Admin Multisig + Benefactor multisigs AFTER timelock execution completes**

### Why After Timelock?
- StakeWeight now has P3 support (permanent locks)
- Safe to grant `LOCKED_TOKEN_STAKER_ROLE` to new handlers
- Admin Multisig can execute immediately (no delay)
- Coordinate with Benefactor multisig actions

---

### 3.0 Grant LOCKED_TOKEN_STAKER_ROLE to NEW Handlers (Admin Multisig)

> **Executed by Admin Multisig (0x398A2749487B2a91f2f543C01F7afD19AEE4b6b0)**

**Get new handler addresses:**
```bash
NEW_LTS_REOWN=$(cat deployments/10-p3-upgrade.json | jq -r '.LockedTokenStakerReownP3.proxy')
NEW_LTS_WALLETCONNECT=$(cat deployments/10-p3-upgrade.json | jq -r '.LockedTokenStakerWalletConnectP3.proxy')
NEW_LTS_BACKERS=$(cat deployments/10-p3-upgrade.json | jq -r '.LockedTokenStakerBackersP3.proxy')
```

**Grant roles:**
```solidity
bytes32 LTS_ROLE = keccak256("LOCKED_TOKEN_STAKER_ROLE");

StakeWeight(0x521B4C065Bbdbe3E20B3727340730936912DfA46).grantRole(LTS_ROLE, NEW_LTS_REOWN);
StakeWeight(0x521B4C065Bbdbe3E20B3727340730936912DfA46).grantRole(LTS_ROLE, NEW_LTS_WALLETCONNECT);
StakeWeight(0x521B4C065Bbdbe3E20B3727340730936912DfA46).grantRole(LTS_ROLE, NEW_LTS_BACKERS);
```

**Verification:**
```bash
cast call 0x521B4C065Bbdbe3E20B3727340730936912DfA46 "hasRole(bytes32,address)(bool)" $(cast keccak "LOCKED_TOKEN_STAKER_ROLE") $NEW_LTS_REOWN --rpc-url $OPTIMISM_RPC_URL
# Should return true
```

---

### 3.1 Add New LockedTokenStakers to MerkleVesters (Benefactor Multisigs)

> **Executed by Benefactor multisigs AFTER Admin Multisig grants roles**

#### 3.1.1 MerkleVesterReown (Benefactor: 0x6f99ee719c2628288372e9972a136d44bddda8e4)

**Verify Role:**
```bash
# Check Benefactor has POST_CLAIM_HANDLER_MANAGER role
cast call 0x648bddEE207da25e19918460c1Dc9F462F657a19 "hasRole(bytes32,address)(bool)" $(cast keccak "POST_CLAIM_HANDLER_MANAGER") 0x6f99ee719c2628288372e9972a136d44bddda8e4 --rpc-url $OPTIMISM_RPC_URL
# Should return true
```

**Add Handler:**
```solidity
// Called by Reown Benefactor Multisig (0x6f99ee719c2628288372e9972a136d44bddda8e4)
MerkleVester(0x648bddEE207da25e19918460c1Dc9F462F657a19).addPostClaimHandlerToWhitelist(
    IPostClaimHandler(LTS_REOWN_PROXY)
);
```

**Verification:**
```bash
# Check new handler is whitelisted
cast call 0x648bddEE207da25e19918460c1Dc9F462F657a19 "isPostClaimHandlerWhitelisted(address)(bool)" LTS_REOWN_PROXY --rpc-url $OPTIMISM_RPC_URL
# Should return true

# Old handler should still be whitelisted (for existing users)
cast call 0x648bddEE207da25e19918460c1Dc9F462F657a19 "isPostClaimHandlerWhitelisted(address)(bool)" 0x5f630a47DE14e346fC28deB8fE379833A6F6B9B2 --rpc-url $OPTIMISM_RPC_URL
# Should return true
```

#### 3.1.2 MerkleVesterWalletConnect (Benefactor: 0xcc97929655e472c2ad608acd854c03fa15899e31)

**Verify Role:**
```bash
cast call 0x85d0964D328563D502867FF6899C6F73D2E59FD1 "hasRole(bytes32,address)(bool)" $(cast keccak "POST_CLAIM_HANDLER_MANAGER") 0xcc97929655e472c2ad608acd854c03fa15899e31 --rpc-url $OPTIMISM_RPC_URL
# Should return true
```

**Add Handler:**
```solidity
// Called by WalletConnect Benefactor Multisig (0xcc97929655e472c2ad608acd854c03fa15899e31)
MerkleVester(0x85d0964D328563D502867FF6899C6F73D2E59FD1).addPostClaimHandlerToWhitelist(
    IPostClaimHandler(LTS_WALLETCONNECT_PROXY)
);
```

**Verification:**
```bash
cast call 0x85d0964D328563D502867FF6899C6F73D2E59FD1 "isPostClaimHandlerWhitelisted(address)(bool)" LTS_WALLETCONNECT_PROXY --rpc-url $OPTIMISM_RPC_URL
# Should return true

# Old handler check
cast call 0x85d0964D328563D502867FF6899C6F73D2E59FD1 "isPostClaimHandlerWhitelisted(address)(bool)" 0x8621034C9acD397cc5921d036225f75699c710FA --rpc-url $OPTIMISM_RPC_URL
# Should return true
```

#### 3.1.3 MerkleVesterBackers (Benefactor: 0xcc97929655e472c2ad608acd854c03fa15899e31)

**Verify Role:**
```bash
cast call 0x2FF1Cdf8Fe00Ae6952BAA32e37D84D31A31E2EC2 "hasRole(bytes32,address)(bool)" $(cast keccak "POST_CLAIM_HANDLER_MANAGER") 0xcc97929655e472c2ad608acd854c03fa15899e31 --rpc-url $OPTIMISM_RPC_URL
# Should return true
```

**Add Handler:**
```solidity
// Called by Backers Benefactor Multisig (0xcc97929655e472c2ad608acd854c03fa15899e31)
MerkleVester(0x2FF1Cdf8Fe00Ae6952BAA32e37D84D31A31E2EC2).addPostClaimHandlerToWhitelist(
    IPostClaimHandler(LTS_BACKERS_PROXY)
);
```

**Verification:**
```bash
cast call 0x2FF1Cdf8Fe00Ae6952BAA32e37D84D31A31E2EC2 "isPostClaimHandlerWhitelisted(address)(bool)" LTS_BACKERS_PROXY --rpc-url $OPTIMISM_RPC_URL
# Should return true

# Old handler check
cast call 0x2FF1Cdf8Fe00Ae6952BAA32e37D84D31A31E2EC2 "isPostClaimHandlerWhitelisted(address)(bool)" 0x688CfB3e55fCE2540b5491E923Dc6a9C4f240176 --rpc-url $OPTIMISM_RPC_URL
# Should return true
```

> **Note:** Old LockedTokenStakers should be removed in Phase 3.5 to prevent users from using buggy implementations. See Phase 3.5 for details.

---

---

### 3.2 Revoke LOCKED_TOKEN_STAKER_ROLE from OLD Handlers (Admin Multisig)

> **Executed by Admin Multisig (0x398A2749487B2a91f2f543C01F7afD19AEE4b6b0)**

**Revoke roles:**
```solidity
bytes32 LTS_ROLE = keccak256("LOCKED_TOKEN_STAKER_ROLE");

StakeWeight(0x521B4C065Bbdbe3E20B3727340730936912DfA46).revokeRole(
    LTS_ROLE,
    0x5f630a47DE14e346fC28deB8fE379833A6F6B9B2 // Old LockedTokenStakerReown
);
StakeWeight(0x521B4C065Bbdbe3E20B3727340730936912DfA46).revokeRole(
    LTS_ROLE,
    0x8621034C9acD397cc5921d036225f75699c710FA // Old LockedTokenStakerWalletConnect
);
StakeWeight(0x521B4C065Bbdbe3E20B3727340730936912DfA46).revokeRole(
    LTS_ROLE,
    0x688CfB3e55fCE2540b5491E923Dc6a9C4f240176 // Old LockedTokenStakerBackers
);
```

**Verification:**
```bash
cast call 0x521B4C065Bbdbe3E20B3727340730936912DfA46 "hasRole(bytes32,address)(bool)" $(cast keccak "LOCKED_TOKEN_STAKER_ROLE") 0x5f630a47DE14e346fC28deB8fE379833A6F6B9B2 --rpc-url $OPTIMISM_RPC_URL
# Should return false
```

---

## 🗑️ Phase 3.5: Remove Old Buggy Handlers from MerkleVester Whitelist (RECOMMENDED)

> **Executed by Benefactor multisigs AFTER Phase 3 completes**

### Why Remove Old Handlers?

The old LockedTokenStaker implementations (non-proxy) have a **permanent lock vesting protection bug** (see CANTINA-6). Removing them from the MerkleVester whitelist:
- ✅ **Prevents** new users from using buggy implementations
- ✅ **Forces** users to use fixed P3 handlers
- ✅ **Does NOT** break existing locks (they're already in StakeWeight)
- ✅ **Improves security** by deprecating vulnerable code

**What this affects:**
- Only impacts **NEW** claims from MerkleVester with `handlePostClaim()`
- Does **NOT** affect existing locks already staked in StakeWeight
- Users with existing locks can still withdraw/extend through StakeWeight directly

### 3.5.1 MerkleVesterReown (Benefactor: 0x6f99ee719c2628288372e9972a136d44bddda8e4)

**Remove Old Handler:**
```solidity
// Called by Reown Benefactor Multisig (0x6f99ee719c2628288372e9972a136d44bddda8e4)
MerkleVester(0x648bddEE207da25e19918460c1Dc9F462F657a19).removePostClaimHandlerToWhitelist(
    IPostClaimHandler(0x5f630a47DE14e346fC28deB8fE379833A6F6B9B2) // Old LockedTokenStakerReown
);
```

**Verification:**
```bash
# Old handler should be removed
cast call 0x648bddEE207da25e19918460c1Dc9F462F657a19 "isPostClaimHandlerWhitelisted(address)(bool)" 0x5f630a47DE14e346fC28deB8fE379833A6F6B9B2 --rpc-url $OPTIMISM_RPC_URL
# Should return false

# New handler should still be whitelisted
cast call 0x648bddEE207da25e19918460c1Dc9F462F657a19 "isPostClaimHandlerWhitelisted(address)(bool)" LTS_REOWN_PROXY --rpc-url $OPTIMISM_RPC_URL
# Should return true
```

### 3.5.2 MerkleVesterWalletConnect (Benefactor: 0xcc97929655e472c2ad608acd854c03fa15899e31)

**Remove Old Handler:**
```solidity
// Called by WalletConnect Benefactor Multisig (0xcc97929655e472c2ad608acd854c03fa15899e31)
MerkleVester(0x85d0964D328563D502867FF6899C6F73D2E59FD1).removePostClaimHandlerToWhitelist(
    IPostClaimHandler(0x8621034C9acD397cc5921d036225f75699c710FA) // Old LockedTokenStakerWalletConnect
);
```

**Verification:**
```bash
# Old handler should be removed
cast call 0x85d0964D328563D502867FF6899C6F73D2E59FD1 "isPostClaimHandlerWhitelisted(address)(bool)" 0x8621034C9acD397cc5921d036225f75699c710FA --rpc-url $OPTIMISM_RPC_URL
# Should return false

# New handler check
cast call 0x85d0964D328563D502867FF6899C6F73D2E59FD1 "isPostClaimHandlerWhitelisted(address)(bool)" LTS_WALLETCONNECT_PROXY --rpc-url $OPTIMISM_RPC_URL
# Should return true
```

### 3.5.3 MerkleVesterBackers (Benefactor: 0xcc97929655e472c2ad608acd854c03fa15899e31)

**Remove Old Handler:**
```solidity
// Called by Backers Benefactor Multisig (0xcc97929655e472c2ad608acd854c03fa15899e31)
MerkleVester(0x2FF1Cdf8Fe00Ae6952BAA32e37D84D31A31E2EC2).removePostClaimHandlerToWhitelist(
    IPostClaimHandler(0x688CfB3e55fCE2540b5491E923Dc6a9C4f240176) // Old LockedTokenStakerBackers
);
```

**Verification:**
```bash
# Old handler should be removed
cast call 0x2FF1Cdf8Fe00Ae6952BAA32e37D84D31A31E2EC2 "isPostClaimHandlerWhitelisted(address)(bool)" 0x688CfB3e55fCE2540b5491E923Dc6a9C4f240176 --rpc-url $OPTIMISM_RPC_URL
# Should return false

# New handler check
cast call 0x2FF1Cdf8Fe00Ae6952BAA32e37D84D31A31E2EC2 "isPostClaimHandlerWhitelisted(address)(bool)" LTS_BACKERS_PROXY --rpc-url $OPTIMISM_RPC_URL
# Should return true
```

> ⚠️ **Important:** If you choose NOT to remove old handlers, update frontend/docs to explicitly warn users against using them for permanent locks.

---

## ✅ Phase 4: Post-Upgrade Verification

### 4.1 Storage Baseline Regression Test
```bash
# Run fork test to verify no storage drift
forge test --match-contract StakeWeightPermanentUpgrade_ForkTest --fork-url $OPTIMISM_RPC_URL -vv
# All tests should PASS
```

### 4.2 Role Assignments Check
```bash
# SRD: DEFAULT_ADMIN_ROLE → Admin Timelock
cast call 0xF368F535e329c6d08DFf0d4b2dA961C4e7F3fCAF "hasRole(bytes32,address)(bool)" 0x0000000000000000000000000000000000000000000000000000000000000000 0x61cc6aF18C351351148815c5F4813A16DEe7A7E4 --rpc-url $OPTIMISM_RPC_URL

# SRD: REWARD_MANAGER_ROLE → Treasury Multisig
cast call 0xF368F535e329c6d08DFf0d4b2dA961C4e7F3fCAF "hasRole(bytes32,address)(bool)" $(cast keccak "REWARD_MANAGER_ROLE") 0xa86Ca428512D0A18828898d2e656E9eb1b6bA6E7 --rpc-url $OPTIMISM_RPC_URL
```

### 4.3 Feature Availability Check
```bash
# Test permanent lock creation
cast send 0x521B4C065Bbdbe3E20B3727340730936912DfA46 "createPermanentLock(uint256,uint256)" 1000000000000000000 52weeks --rpc-url $OPTIMISM_RPC_URL --private-key $TEST_KEY

# Test reward injection (Treasury)
cast send 0xF368F535e329c6d08DFf0d4b2dA961C4e7F3fCAF "injectRewardForCurrentWeek(uint256)" 1000000000000000000000 --rpc-url $OPTIMISM_RPC_URL --from 0xa86Ca428512D0A18828898d2e656E9eb1b6bA6E7
```

### 4.4 Event Monitoring
Monitor for unexpected events during the first 24 hours:
- `StakeWeight.ConvertedToPermanent`
- `StakeWeight.PermanentUnlockTriggered`
- `StakingRewardDistributor.RewardsClaimed`
- `StakingRewardDistributor.RewardInjected`

---

## 🚨 Emergency Procedures

### If Timelock Execution Fails:
1. **Check operation status:**
   ```bash
   cast call 0x61cc6aF18C351351148815c5F4813A16DEe7A7E4 "isOperationDone(bytes32)(bool)" OPERATION_ID --rpc-url $OPTIMISM_RPC_URL
   ```

2. **Inspect failure reason:** Check Optimism block explorer for revert reason

3. **Cancel if needed (Admin only):**
   ```solidity
   AdminTimelock(0x61cc6aF18C351351148815c5F4813A16DEe7A7E4).cancel(OPERATION_ID);
   ```

### If AccessControl Migration Fails:
- Old `owner()` function should revert
- Fallback: Re-schedule with corrected calldata

### If LockedTokenStaker Whitelist Fails:
- Users won't be able to use NEW stakers for permanent locks
- OLD stakers remain functional (but have permanent lock bug)
- Retry whitelist operation via Benefactor multisig
- Check Benefactor has `POST_CLAIM_HANDLER_MANAGER` role

### User Migration Notes:
- **Old handlers** (0x5f63..., 0x8621..., 0x688C...): Should be removed in Phase 3.5 (have **permanent lock vesting protection bug**)
- **New handlers** (proxy addresses): Required for all new locks with correct vesting protection
- **Existing locks**: Unaffected by handler removal, already staked in StakeWeight
- **New claims**: Must use new P3 handlers after Phase 3.5

---

## 📊 Critical Invariants to Monitor

| Invariant | Check Command | Expected |
|-----------|---------------|----------|
| Total staked supply unchanged | `cast call 0x521B4C065Bbdbe3E20B3727340730936912DfA46 "totalSupply()(uint256)"` | ~9.6T (pre-upgrade value) |
| SRD reward balance preserved | `cast call 0xF368F535e329c6d08DFf0d4b2dA961C4e7F3fCAF "lastTokenBalance()(uint256)"` | Match pre-upgrade |
| No user balance drift | Compare `balanceOf()` for top 10 stakers | Within 1e15 |
| Week cursor not reset | `cast call 0xF368F535e329c6d08DFf0d4b2dA961C4e7F3fCAF "weekCursor()(uint256)"` | >= pre-upgrade value |

---

## 🔐 Multisig Signers Checklist

### For Admin Multisig (Scheduling):
- [ ] Verify all implementation addresses are correct
- [ ] Confirm salt is unique (`P3_STAKING_UPGRADE_ATOMIC_2025`)
- [ ] Double-check ProxyAdmin addresses
- [ ] Verify calldata encoding for `migrateToAccessControl()`
- [ ] Confirm 7-day delay

### For Admin Multisig (Execution):
- [ ] Verify 7 days have passed
- [ ] Check operation is ready: `isOperationReady()`
- [ ] Monitor mempool during execution
- [ ] Verify all events emitted successfully

### For Admin Multisig (Phase 3.0 & 3.2):
- [ ] Wait for Admin Timelock execution to complete
- [ ] Verify StakeWeight has P3 support (`permanentSupply()` works)
- [ ] Grant `LOCKED_TOKEN_STAKER_ROLE` to 3 new handlers
- [ ] Verify grants with `hasRole()`
- [ ] Revoke `LOCKED_TOKEN_STAKER_ROLE` from 3 old handlers
- [ ] Verify revocations with `hasRole()`

### For Benefactor Multisigs (Phase 3.1):
- [ ] Wait for Admin Multisig to grant roles
- [ ] Verify new LockedTokenStaker proxies are deployed
- [ ] Check you have `POST_CLAIM_HANDLER_MANAGER` role
- [ ] Add new handlers to whitelist
- [ ] Verify whitelist with `isPostClaimHandlerWhitelisted()`

### For Benefactor Multisigs (Phase 3.5 - RECOMMENDED):
- [ ] Remove old buggy handlers from whitelist
- [ ] Verify old handlers are no longer whitelisted
- [ ] Verify new handlers remain whitelisted
- [ ] Update frontend/docs if old handlers are NOT removed

---

## 📝 Calldata Reference

### scheduleBatch Calldata
```
Function: scheduleBatch(address[],uint256[],bytes[],bytes32,bytes32,uint256)
targets: [0x8714E77FA6Aca75A9b21d79295ec7cF04E4821a8, 0x9898b105fe3679f2d31c3A06B58757D913D88e5F, 0x28672bf553c6AB214985868f68A3a491E227aCcB]
values: [0, 0, 0]
payloads: [See Section 2.1]
predecessor: 0x0000000000000000000000000000000000000000000000000000000000000000
salt: 0x[keccak256("P3_STAKING_UPGRADE_ATOMIC_2025")]
delay: 604800 (7 days in seconds)
```

### migrateToAccessControl Calldata
```
Function: migrateToAccessControl()
Selector: 0x[computed from function signature]
No parameters
```

### addPostClaimHandlerToWhitelist Calldata
```
Function: addPostClaimHandlerToWhitelist(address)
handler: NEW_LTS_PROXY_ADDRESS
```

---

## 📖 Additional Resources

- **P3 Design Doc:** `docs/P3_STAKING_REDESIGN.md`
- **Fork Tests:** `test/fork/StakeWeightPermanentUpgradeFork.t.sol`, `test/fork/StakingRewardDistributorUpgrade.t.sol`
- **Security Considerations:** `docs/SECURITY_CONSIDERATIONS.md`
- **Deployment Addresses:** `DEPLOYMENT_ADDRESSES.md`

---

## ✍️ Sign-Off

| Role | Signer | Signature | Date |
|------|--------|-----------|------|
| Admin Multisig | | | |
| Reown Benefactor | | | |
| WC/Backers Benefactor | | | |

---

**Last Updated:** 2025-10-10
**Version:** 1.0
**Status:** Ready for Execution
