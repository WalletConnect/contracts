#!/bin/bash

echo "Deleting previous deployments on chain 31337"
rm deployments/31337
echo "Done."

anvil >/dev/null 2>&1 &

echo "Deploying the Solidity contracts..."
forge script script/Deploy.s.sol:Deploy --broadcast --rpc-url=http://localhost:8545 --legacy -s "deploy()" --force >/dev/null 2>&1
echo "Done."

echo "Dumping state"
cast rpc anvil_dumpState >>infra/anvil_state.txt
echo "Done."

echo "State saved at infra/anvil_state.txt"

echo "Cleaning up..."
kill $(pgrep -f "anvil")
echo "Done."
