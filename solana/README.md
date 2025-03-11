# Solana Programs

This directory contains Solana programs (smart contracts) for cross-chain token transfers.

## Structure

- `programs/`: Solana program source code
- `tests/`: Test files for the programs

## Development

This project uses [Anchor](https://www.anchor-lang.com/) for Solana program development.

### Prerequisites

- [Rust](https://www.rust-lang.org/tools/install)
- [Solana CLI](https://docs.solana.com/cli/install-solana-cli-tools)
- [Anchor](https://www.anchor-lang.com/docs/installation)

### Building

```bash
cd solana
anchor build
```

### Testing

```bash
cd solana
anchor test
```

### Deployment

```bash
cd solana
anchor deploy
```
