# WalletConnect Decentralization Architecture - Audit Document

## 1. Executive Summary

WalletConnect is developing a decentralized infrastructure to enable permissionless, interoperable messaging between
dApps and wallets. This document outlines the high-level architecture, focusing on the integration of on-chain and
off-chain components, with particular emphasis on the storage layer decentralization.

Key components:

- WCT token for incentivizing node operators and wallets
- Permissioned node operator network (transitioning to permissionless)
- Performance-based rewards system
- Oracle network for reporting node performance

The project aims to decentralize iteratively, starting with the storage layer. The system will initially operate in a
permissioned pre-production environment with 5 external parties, gradually moving towards a fully permissionless
implementation.

## 2. System Architecture

### 2.1 On-chain Components

1. WCT Token (L1 and L2)
   - Common functionality:
     - Governance features (ERC20Votes)
     - Access control
     - Upgradeable design using proxy pattern
     - Permit functionality
2. WCT (L1)
   - Controlled by admin multisig
3. L2WCT
   - L2-specific functionality
   - Configurable transfer restrictions
   - Bridge-controlled minting/burning
   - Configurable address allowlisting
4. Timelock
   - Extends OpenZeppelin's TimelockController
   - Configurable delay periods
   - Role-based execution control
5. Staking
   - Lock-based staking where stake weight decays linearly over time
   - Lock periods up to 4 years (209 weeks) with longer locks providing higher weight
   - Stake weight calculated as: bias - slope \* (t - timestamp) where:
     - bias is initial stake weight
     - slope is bias/unlock_time for linear decay
     - t is current timestamp
   - Checkpointing system to track historical stake weights
   - Binary search for efficient historical stake weight lookups
   - Rewards distributed proportionally based on stake weight
   - Emergency withdrawal capabilities with admin control
   - Tracks both transferred and non-transferred balances:
     - Non-transferred balance represents tokens already locked in vesting contract
     - Transferred balance represents tokens directly transferred to staking contract
     - Total locked amount is sum of both balances
     - Enables staking of vested tokens without requiring transfer
6. PermissionedNodeRegistry and WalletRegistry
   - Registries stores whitelist of eligible actors for performance rewards
   - Implements add/remove functions for managing whitelisted addresses
   - Includes query functions for checking eligibility and status
   - WalletRegistry includes certification status for wallets
   - PermissionedNodeRegistry allows nodes to specify a different address for claiming rewards
7. NodeRewardManager
   - Handles reward logic and distribution for node operators
   - Sets maximum emissions per epoch
   - Manages claiming of rewards
   - Implements performance-based reward calculation
   - Interacts with Oracle for performance data
8. WalletRewardManager
   - Manages rewards for certified and whitelisted wallets
   - Synthetix-inspired approach without epochs
   - Implements continuous reward accrual based on wallet status and stake
9. Oracle
   - Interacts with RewardManager to post performance data
   - Includes data validation and safeguards against malfunction or exploitation
10. WalletConnectConfig
    - Service-locator pattern for contract addresses
    - Stores global configuration values
    - Allows for easy updates of contract addresses and parameters
11. Pauser
    - Manages paused states of other contracts
    - Allows for quick response to vulnerabilities or anomalies
    - Implements role-based access for pausing and unpausing

### Proxies

The following contracts will use the OpenZeppelin Upgradeable Contracts library with TransparentUpgradeableProxy:

- Staking
- RewardManagers
- Oracle
- WalletConnectConfig
- WCT Token

Rationale: These core contracts may need updates or bug fixes in the future. Using proxies maintains contract addresses,
ensuring continuity for users and integrations.

### 2.2 Off-chain Components

1. Node Operators
   - Run the distributed database nodes
   - Ensure high availability, low latency, and successful requests
2. Oracle Network
   - Monitors and reports node performance
   - Posts performance data on-chain
3. WalletConnect Foundation
   - Initial governance and administration
   - Manages contract deployments, upgrades, and configurations

### 2.3 Actors and Responsibilities

- WalletConnect Foundation Admin Multisig
  - Protocol governance
  - Contract upgrades
  - Access control management
  - Update WalletConnectConfig
  - Disable transfer restrictions on L2WCT
- WalletConnect Foundation Manager Multisig
  - Parameter updates
  - Token distribution control
  - Operator allowlist management
- Timelock Contracts
  - Enforced delays on critical operations
  - Role-based execution controls
- Pauser Multisig
  - Emergency response capabilities
  - Has pre-signed txs waiting to be executed
  - Can pause multiple contracts at once
- Emergency MultiSig
  - Ready to receive ownerships / funds in case of emergencies
- Oracle System
  - Performance monitoring
  - On-chain data reporting
- Node Operators
  - Running database nodes
  - Staking WCT tokens
  - Maintaining node performance and availability
- Wallets
  - Implementing WalletConnect standards
  - Staking WCT tokens
  - Optionally running nodes
- Rest of token holders
  - Participation in token distribution events
  - Staking WCT tokens

## 3. Oracle Architecture

The WCT Oracle system synchronizes on-chain and off-chain states, focusing on node operator performance metrics.

Components:

- Oracle Smart Contracts:
  - Performance reporting and validation
  - Optional consensus mechanism for future scalability
- Oracle Daemon:
  - Automated monitoring and reporting
  - Performance metric collection

Implementation Phases:

1. Initial Phase: Centralized oracle with robust validation
2. Future Phase: Potential transition to distributed oracle network based on network requirements

Security Considerations:

- Data validation requirements
- Failure mode handling
- Performance impact monitoring
- Upgrade capabilities with security controls

Workflow:

1. Data Collection: Oracle daemons gather performance data from node operators
2. Report Generation: Oracles compile standardized reports
3. Report Submission: Full report data submitted to PerformanceOracle contract
4. State Update: Smart contracts process report data and update network parameters

## 4. Access Control and Security

### 4.1 Role-Based Access Control (RBAC)

The system implements a hybrid access control model:

1. Core Token Contracts
   - Admin controls for critical functions
   - Timelocked operations for safety
2. Protocol Contracts
   - Role-based permissions for different operational needs
   - Hierarchical access structure
3. Auxiliary Contracts
   - Function-specific access controls
   - Emergency control capabilities

### 4.2 Security Controls

- Industry-standard multisig implementations
- Timelocked operations for critical changes
- Emergency pause capabilities
- Regular security reviews and updates

## 5. Upgradeability and Modularity

- Proxy Patterns: Use of OpenZeppelin's TransparentUpgradeableProxy for core contracts
- Upgrade Strategy: Multi-sig controlled upgrades with time-locks
- Modularity Assessment: Evaluation of contract splitting or merging for improved maintainability

## 6. Testing Approach

Our testing approach employs a comprehensive strategy that includes unit testing, integration testing, fuzz testing, and
invariant testing. We use the Branching Tree Technique (BTT) to structure our tests and ensure thorough coverage of all
possible execution paths.

### 6.1 Unit Testing

We use concrete unit tests to verify individual function behaviors. These tests are organized using the BTT approach, as
evidenced by the `.tree` files in our test structure. For example:

- `unit/concrete/l2wct/transfer/transfer.tree`
- `unit/concrete/stake-weight/set-max-lock/setMaxLock.tree`

These `.tree` files outline all possible execution paths, considering different contract states and function parameters.

### 6.2 Integration Testing

Integration tests verify the interaction between different components of our system. These tests are located in the
`integration/concrete` directory and also follow the BTT structure. For instance:

- `integration/concrete/stake-weight/balance-of/balanceOf.tree`
- `integration/concrete/timelock/execute/execute.tree`

### 6.3 Fuzz Testing

Fuzz tests are implemented to discover edge cases and unexpected behaviors by providing random inputs to functions.
These tests are located in the `unit/fuzz` directory. Examples include:

- `unit/fuzz/l2-wct/transfer.t.sol`
- `unit/fuzz/stake-weight/timestampToFloorWeek.t.sol`

### 6.4 Invariant Testing

Invariant tests ensure that the system's core properties hold true under various conditions. These tests are located in
the `invariant` directory and use handlers and stores to manage state:

- `invariant/WCT.t.sol`
- `invariant/L2WCT.t.sol`
- `invariant/Airdrop.t.sol`
- `invariant/StakeWeight.t.sol`
- `invariant/StakingRewardDistributor.t.sol`
- `invariant/LockedTokenStaker.t.sol`

### 6.5 Branching Tree Technique (BTT)

BTT is used throughout our testing approach to ensure comprehensive coverage. Each `.tree` file represents a structured
approach to testing a specific function, considering all possible execution paths, contract states, and function
parameters.

For example, in `unit/concrete/staking/update-min-stake-amount/updateMinStakeAmount.tree`, we might have:

```
transfer.t.sol
# given transfer restrictions are enabled
## when sender is not in allowedFrom list
### when recipient is not in allowedTo list
#### it should revert with TransferRestricted
### when recipient is in allowedTo list
#### it should transfer tokens successfully
#### it should emit a {Transfer} event
## when sender is in allowedFrom list
### it should transfer tokens successfully
### it should emit a {Transfer} event
### it should revert with "ERC20: transfer amount exceeds balance"
# given transfer restrictions are disabled
## given sender has sufficient balance
### it should transfer tokens successfully
### it should emit a {Transfer} event
## given sender has insufficient balance
### it should revert with "ERC20: transfer amount exceeds balance"
```

This structure ensures that we test all relevant scenarios for the `transfer` function.

By combining these testing methodologies and using BTT, we aim to achieve high test coverage and ensure the reliability
and security of our smart contract system.

## 7. Best Practices and Industry Standards

- Utilization of OpenZeppelin contracts for standard functionalities
- Consideration of established DeFi protocols (e.g., Synthetix, Lido) for specific mechanisms
- Adherence to Solidity style guide and best practices
- Comprehensive testing suite including unit tests, integration tests, and fuzz testing
