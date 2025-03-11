# EVM Contracts

This directory contains Ethereum Virtual Machine (EVM) compatible smart contracts for cross-chain token transfers.

## Structure

- `contracts/`: Smart contract source code
- `scripts/`: Deployment and utility scripts
- `test/`: Test files for the contracts

## Development

This project uses [Foundry](https://book.getfoundry.sh/) for EVM contract development.

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Building

```bash
cd evm
forge build
```

### Testing

```bash
cd evm
forge test
```

### Deployment

```bash
cd evm
forge script scripts/Deploy.s.sol --rpc-url <your-rpc-url> --private-key <your-private-key>
```
