# WalletConnect Protocol

[![Foundry][foundry-shield]][foundry-url] [![License: MIT][license-shield]][license-url]
[![Discord][discord-shield]][discord-url] [![Docs][docs-shield]][docs-url]

**The decentralized infrastructure protocol powering WalletConnect's network with cross-chain token economics and
governance.**

## What is WalletConnect Protocol?

WalletConnect Protocol is a comprehensive smart contract system that powers the decentralized WalletConnect network. The
protocol introduces WCT (WalletConnect Token), a cross-chain governance and utility token that enables staking, rewards,
and network participation across Ethereum, Optimism, and Solana.

Key features:

- **Cross-chain token** with native bridging via Wormhole NTT
- **Vote-escrowed staking** with time-weighted rewards (stWCT)
- **Perpetual staking** for long-term network alignment
- **Infrastructure rewards** for network participants
- **Timelock governance** with multi-signature controls

## Architecture

The protocol consists of several interconnected modules:

### Core Components

- **[WCT Token](./evm/src/WCT.sol)**: ERC-20 governance token on Ethereum with Wormhole NTT integration
- **[L2WCT Token](./evm/src/bridge/L2WCT.sol)**: L2-native token with transfer restrictions and staking capabilities
- **[StakeWeight](./evm/src/StakeWeight.sol)**: Vote-escrowed staking with time-weighted rewards and perpetual positions
- **[StakingRewardDistributor](./evm/src/StakingRewardDistributor.sol)**: Handles reward distribution to stakers

### Governance & Security

- **[Timelocks](./evm/src/Timelock.sol)**: 1-week admin timelock, 3-day manager timelock
- **[Pauser](./evm/src/Pauser.sol)**: Emergency pause functionality for critical contracts
- **[WalletConnectConfig](./evm/src/WalletConnectConfig.sol)**: Central configuration registry

### Cross-Chain Infrastructure

- **Wormhole NTT**: Native Token Transfer for Ethereum ↔ Optimism ↔ Solana bridging
- **Rate Limits**: Configurable transfer limits between chain pairs
- **Bridge Security**: Multi-signature controls and emergency pause capabilities

## Deployments

### Production Networks

| Network      | Chain ID | WCT Token                                                                                                                          | Documentation                                                            |
| ------------ | -------- | ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| **Ethereum** | 1        | [`0xeF4461891DfB3AC8572cCf7C794664A8DD927945`](https://etherscan.io/address/0xeF4461891DfB3AC8572cCf7C794664A8DD927945)            | [Full Deployment](./DEPLOYMENT_ADDRESSES.md#ethereum-mainnet-chain-id-1) |
| **Optimism** | 10       | [`0xeF4461891DfB3AC8572cCf7C794664A8DD927945`](https://optimistic.etherscan.io/address/0xeF4461891DfB3AC8572cCf7C794664A8DD927945) | [Full Deployment](./DEPLOYMENT_ADDRESSES.md#optimism-chain-id-10)        |
| **Solana**   | -        | [`WCTk5xWdn5SYg56twGj32sUF3W4WFQ48ogezLBuYTBY`](https://explorer.solana.com/address/WCTk5xWdn5SYg56twGj32sUF3W4WFQ48ogezLBuYTBY)   | [Full Deployment](./DEPLOYMENT_ADDRESSES.md#solana)                      |

For complete deployment addresses including staking contracts, governance, and bridges, see
[DEPLOYMENT_ADDRESSES.md](./DEPLOYMENT_ADDRESSES.md).

## Development

### Prerequisites

- [Foundry](https://getfoundry.sh/) for smart contract development
- Node.js v18+ and pnpm for deployment scripts
- Environment variables (see `.common.example.env`)

### Setup

```bash
# Clone the repository
git clone https://github.com/WalletConnect/contracts
cd contracts

# Install dependencies
cd evm && forge install

# Copy environment variables
cp .common.example.env .common.env
# Edit .common.env with your API keys
```

### Build

```bash
# Compile contracts
forge build

# Generate documentation
forge doc
```

### Testing

```bash
# Run all tests
forge test

# Run specific test suites
forge test --match-path test/unit         # Unit tests
forge test --match-path test/integration  # Integration tests
forge test --match-path test/invariant    # Invariant tests
forge test --match-path test/fork         # Fork tests (requires RPC)

# Run with coverage
forge coverage

# Gas reporting
forge test --gas-report
```

### Deployment

Deployment scripts use Foundry's forge script system:

```bash
# Deploy to testnet
forge script script/deploy/OptimismDeploy.s.sol --rpc-url sepolia --broadcast

# Deploy to mainnet (requires hardware wallet)
forge script script/deploy/OptimismDeploy.s.sol --rpc-url optimism --broadcast --ledger
```

See [deployment scripts](./evm/script/deploy/) for network-specific deployments.

## Security

### Security Practices

- All contracts use OpenZeppelin's battle-tested implementations
- Comprehensive test coverage including unit, integration, and invariant tests
- Timelock governance with multi-signature controls
- Emergency pause functionality on critical operations
- Rate-limited cross-chain transfers

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

### Development Process

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`forge test`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Community

- **Discord**: [Join our Discord](https://discord.gg/walletconnectnetwork)
- **Forum**: [Governance Forum](https://governance.walletconnect.network/)
- **Twitter**: [@walletconnect](https://x.com/walletconnect)
- **Blog**: [walletconnect.network/blog](https://https://walletconnect.network/blog)

## Documentation

- **[Technical Documentation](./docs/)** - Smart contract architecture and design decisions

## License

This project is licensed under the MIT License - see [LICENSE.md](LICENSE.md) for details.

---

Built with ❤️ by the WalletConnect team

<!-- MARKDOWN LINKS & IMAGES -->

[foundry-shield]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg?style=for-the-badge
[foundry-url]: https://getfoundry.sh/
[license-shield]: https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge
[license-url]: https://github.com/WalletConnect/contracts/blob/main/LICENSE.md
[discord-shield]: https://img.shields.io/badge/Discord-Join-7289DA?style=for-the-badge&logo=discord&logoColor=white
[discord-url]: https://discord.com/invite/walletconnectnetwork
[docs-shield]: https://img.shields.io/badge/Docs-Read-blue?style=for-the-badge
[docs-url]: https://docs.walletconnect.network
