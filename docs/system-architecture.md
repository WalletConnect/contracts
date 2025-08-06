# WalletConnect Protocol - System Architecture

## 1. Executive Summary

WalletConnect Protocol is a decentralized token economics system that powers the WalletConnect network through the WCT (WalletConnect Token). The protocol implements cross-chain token bridging, vote-escrowed staking mechanics, and timelock governance across Ethereum, Optimism, and Solana.

Key components:
- WCT token with cross-chain bridging via Wormhole NTT
- Vote-escrowed staking system with time-weighted rewards
- Perpetual staking positions for long-term alignment
- Timelock governance with multi-signature controls
- Emergency pause mechanisms for security

## 2. System Architecture

### 2.1 Core Token Contracts

#### WCT (Ethereum L1)
- **Contract**: [`WCT.sol`](../evm/src/WCT.sol)
- **Purpose**: Primary governance token on Ethereum
- **Features**:
  - ERC-20 with ERC-20Votes for governance
  - ERC-2612 Permit for gasless approvals
  - Wormhole NTT integration for cross-chain bridging
  - Upgradeable via TransparentUpgradeableProxy
  - Controlled by admin timelock (1 week delay)

#### L2WCT (Optimism)
- **Contract**: [`L2WCT.sol`](../evm/src/bridge/L2WCT.sol)
- **Purpose**: L2-native token with staking capabilities
- **Features**:
  - Transfer restrictions (can be permanently disabled)
  - Bridge-controlled minting/burning
  - Address allowlisting for transfers
  - Integration with StakeWeight for staking
  - Manager role for operational functions

### 2.2 Staking System

#### StakeWeight
- **Contract**: [`StakeWeight.sol`](../evm/src/StakeWeight.sol)
- **Purpose**: Vote-escrowed staking with time-weighted rewards
- **Mechanics**:
  - Lock periods up to 4 years (209 weeks maximum)
  - Stake weight decays linearly over time: `weight = amount * time_remaining / max_time`
  - Perpetual staking positions with constant weight
  - Checkpointing system for historical weight tracking
  - Binary search for efficient historical lookups
  - Emergency withdrawal capabilities

#### StakingRewardDistributor
- **Contract**: [`StakingRewardDistributor.sol`](../evm/src/StakingRewardDistributor.sol)
- **Purpose**: Manages reward distribution to stakers
- **Features**:
  - Proportional reward distribution based on stake weight
  - Claim functionality for users
  - Owner-controlled reward funding

### 2.3 Governance & Security

#### Timelock Contracts
- **Admin Timelock**: 1 week delay for critical operations
- **Manager Timelock**: 3 days delay for operational changes
- **Canceller Role**: Can cancel pending timelock operations
- **Based on**: OpenZeppelin's TimelockController

#### Pauser
- **Contract**: [`Pauser.sol`](../evm/src/Pauser.sol)
- **Purpose**: Emergency pause functionality
- **Features**:
  - Can pause multiple contracts simultaneously
  - Role-based access control
  - Pre-signed transactions for rapid response

#### WalletConnectConfig
- **Contract**: [`WalletConnectConfig.sol`](../evm/src/WalletConnectConfig.sol)
- **Purpose**: Central configuration registry
- **Features**:
  - Service-locator pattern for contract addresses
  - Global configuration values
  - Admin-controlled updates

### 2.4 Cross-Chain Infrastructure

#### Wormhole NTT Integration
- **Components**: NTT Manager and Transceiver on each chain
- **Supported Routes**: 
  - Ethereum ↔ Optimism
  - Ethereum ↔ Solana
  - Optimism ↔ Solana
- **Rate Limits**: Configurable per chain pair
- **Security**: Multi-signature controls, emergency pause

### 2.5 Vesting & Distribution

#### Airdrop
- **Contract**: [`Airdrop.sol`](../evm/src/Airdrop.sol)
- **Purpose**: Merkle-based token distribution
- **Features**: One-time claim per address

#### MerkleVester
- **Contracts**: Separate contracts for different cohorts (Reown, WalletConnect, Backers)
- **Purpose**: Time-based vesting with merkle proofs
- **Features**: Linear vesting over specified period

#### LockedTokenStaker
- **Purpose**: Allows vested tokens to be staked without transfer
- **Features**: 
  - Manages staking on behalf of vesting contracts
  - Tracks transferred vs non-transferred balances

## 3. Deployed Infrastructure

### 3.1 Production Networks

| Network | Key Contracts |
|---------|--------------|
| **Ethereum** | WCT, NTT Manager, Timelock |
| **Optimism** | L2WCT, StakeWeight, StakingRewardDistributor, Config, Pauser, Timelocks |
| **Solana** | WCT Token, NTT Manager |

### 3.2 Actors and Responsibilities

#### Admin Multisig
- Protocol governance
- Contract upgrades
- Critical parameter updates
- Transfer restriction management

#### Manager Multisig
- Operational parameter updates
- Day-to-day protocol operations

#### Pauser Multisig
- Emergency response
- Quick reaction to vulnerabilities
- Pre-signed pause transactions

#### Treasury Multisig
- Protocol treasury management
- Reward funding

## 4. Security Architecture

### 4.1 Access Control Model

The protocol implements a hierarchical access control system:

1. **Admin Role** (Timelock-protected)
   - Contract upgrades
   - Critical parameter changes
   - Transfer restriction management

2. **Manager Role** (Timelock-protected)
   - Operational parameters
   - Allowlist updates

3. **Pauser Role**
   - Emergency pause/unpause
   - No timelock for rapid response

### 4.2 Security Features

- **Timelocks**: Enforced delays on critical operations
- **Multi-signature**: All administrative functions require multiple signatures
- **Emergency Pause**: Quick response to vulnerabilities
- **Upgrade Pattern**: TransparentUpgradeableProxy with admin separation
- **Rate Limiting**: Cross-chain transfer limits
- **Reentrancy Guards**: On all critical functions

## 5. Testing Strategy

### 5.1 Test Coverage

The protocol employs comprehensive testing:

- **Unit Tests** (`test/unit/`): Individual function verification
- **Integration Tests** (`test/integration/`): Multi-contract interactions
- **Invariant Tests** (`test/invariant/`): System-wide property verification
- **Fork Tests** (`test/fork/`): Mainnet state testing
- **Fuzz Tests**: Random input testing for edge cases

### 5.2 Branching Tree Technique (BTT)

Tests are structured using BTT methodology:
- `.tree` files outline all execution paths
- Systematic coverage of all scenarios
- Clear test organization and documentation

Example structure:
```
stake-weight/
├── create-lock/
│   ├── createLock.tree
│   └── createLock.t.sol
├── increase-amount/
│   ├── increaseAmount.tree
│   └── increaseAmount.t.sol
```

## 6. Upgrade Strategy

### 6.1 Upgradeable Contracts

The following contracts use TransparentUpgradeableProxy:
- WCT (L1 and L2)
- StakeWeight
- StakingRewardDistributor
- WalletConnectConfig
- Pauser

### 6.2 Upgrade Process

1. Proposal submitted to governance
2. Timelock delay (1 week for critical, 3 days for operational)
3. Multi-signature execution
4. Proxy upgrade implementation

## 7. Integration Guidelines

### 7.1 For Developers

- Token integration: Standard ERC-20 interface
- Staking integration: StakeWeight contract interaction
- Bridge integration: Wormhole NTT protocols

### 7.2 For Node Operators

- No on-chain components currently (future roadmap)
- Performance monitoring off-chain

## 8. Future Considerations

While not currently implemented, the architecture supports future additions:
- Permissionless node operator rewards
- Oracle-based performance monitoring
- Additional cross-chain bridges
- Governance module enhancements

## 9. References

- [OpenZeppelin Contracts](https://docs.openzeppelin.com/)
- [Wormhole NTT Documentation](https://docs.wormhole.com/wormhole/native-token-transfers/overview)
- [Curve Vote-Escrowed Model](https://curve.readthedocs.io/dao-vecrv.html)