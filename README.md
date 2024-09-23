# WalletConnect Decentralization Architecture

## Overview

WalletConnect is developing a decentralized infrastructure for permissionless, interoperable messaging between dApps and
wallets. This project aims to gradually transition from a permissioned to a fully permissionless network, starting with
the decentralization of the storage layer.

## Key Components

- WCT Token: Incentivizes node operators and wallets
- Node Operator Network: Initially permissioned, transitioning to permissionless
- Performance-based Rewards System
- Oracle Network: Reports node performance

## System Architecture

### On-chain Components

- Smart Contracts: WCT Token, Staking, Node/Wallet Registries, Reward Managers, Oracle, Config Management
- Utilizes upgradeable contracts and role-based access control

### Off-chain Components

- Node Operators: Run distributed database nodes
- Oracle Network: Monitors and reports performance
- WalletConnect Foundation: Initial governance and administration

## Security Measures

- Role-Based Access Control (RBAC)
- Multi-signature setups
- Timelock mechanisms
- Pausable contracts
- Comprehensive testing suite: unit, integration, fuzz, and invariant testing

## Roadmap

1. Launch permissioned pre-production environment
2. Gradual transition to permissionless network
3. Continuous improvements and security audits

## Development Approach

- Utilizes OpenZeppelin contracts
- Follows Solidity best practices
- Implements Branching Tree Technique (BTT) for thorough testing

For more detailed information, please refer to the full [architecture document](./docs/system-architecture.md).
