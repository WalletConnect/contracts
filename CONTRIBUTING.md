# Contributing to WalletConnect Contracts

Thank you for your interest in contributing! We welcome community contributions.

## Setup

**Prerequisites:** [Foundry](https://book.getfoundry.sh/getting-started/installation), [Node.js](https://nodejs.org/)
v18+, [pnpm](https://pnpm.io/installation)

```bash
# Fork and clone the repository
git clone https://github.com/YOUR_USERNAME/contracts.git
cd contracts

# Install dependencies
pnpm install
cd evm && forge install

# Create a feature branch
git checkout -b feature/your-feature-name
```

## Development

```bash
# Build contracts
cd evm && forge build

# Run tests
forge test

# Run with coverage
forge coverage

# Format and lint
pnpm run lint:fmt
pnpm run lint:sol
```

## Code Style

- **Solidity Version**: `0.8.25` (locked for deployed contracts)
- **Imports**: Use named imports (`import {Contract} from "path"`)
- **Formatting**: Use `foundry fmt`
- **Documentation**: Complete NatSpec for all public functions
- **Testing**: Follow Branching Tree Technique (BTT) - see
  [`.cursor/rules/solidity-testing.mdc`](.cursor/rules/solidity-testing.mdc)

For detailed guidelines, see [`.cursor/rules/solidity.mdc`](.cursor/rules/solidity.mdc).

## Pull Requests

1. Ensure all tests pass (`forge test`)
2. Add tests for new functionality
3. Update documentation if needed
4. Create a clear PR description

## Security

**DO NOT** create public issues for security vulnerabilities. Report security issues via
[reown.com/security](https://reown.com/security).

## Questions

- **Discord**: [#dev channel](https://discord.gg/walletconnect)
- **Documentation**: [docs.walletconnect.network](https://docs.walletconnect.network)
