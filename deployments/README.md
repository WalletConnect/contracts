# Deployments

This directory contains deployment information for the WalletConnect contracts across different networks.

## JSON Deployment Files

Deployment information is stored in JSON files named after the chain ID (e.g., `1.json` for Ethereum Mainnet, `10.json`
for Optimism).

### JSON Format

The JSON files have the following structure:

```json
{
  "chainId": 1,
  "WCT": {
    "address": "0x...",
    "implementation": "0x...",
    "admin": "0x..."
  },
  "Timelock": {
    "address": "0x..."
  }
}
```

For proxy contracts, the JSON includes the proxy address, implementation address, and admin address. For non-proxy
contracts, only the contract address is included.

## Generating JSON Deployment Files

There are two ways to generate JSON deployment files:

### 1. Using the Makefile

The Makefile provides targets for generating JSON deployment files for each network:

```bash
# For Ethereum Mainnet
make json-mainnet

# For Sepolia testnet
make json-sepolia

# For Optimism Mainnet
make json-optimism

# For Optimism Sepolia testnet
make json-optimism-sepolia

# For Anvil local network
make json-anvil
```

These commands will run the deployment script's `logDeployments()` function and convert the output to JSON.

### 2. Using the Deployment Scripts Directly

The deployment scripts can also write JSON files directly when the `WRITE_JSON` environment variable is set:

```bash
# For Ethereum Mainnet
WRITE_JSON=true forge script script/deploy/EthereumDeploy.s.sol:EthereumDeploy -s "logDeployments()" --rpc-url $RPC_URL

# For Optimism
WRITE_JSON=true forge script script/deploy/OptimismDeploy.s.sol:OptimismDeploy -s "logDeployments()" --rpc-url $RPC_URL
```
