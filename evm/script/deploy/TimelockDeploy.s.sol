// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { Timelock } from "src/Timelock.sol";
import { BaseScript } from "script/Base.s.sol";

/// @title TimelockDeploy
/// @notice Deploys a standalone Timelock for chains that lack one (Arbitrum, Base), so the WCT ProxyAdmin
///         owner and token DEFAULT_ADMIN_ROLE can sit behind a timelock rather than the admin multisig
///         directly. The role/ownership hand-off itself is done separately from the multisig — this script
///         ONLY deploys the timelock.
/// @dev Config mirrors EthereumDeploy: 1-week delay, multisig as sole proposer + executor, dedicated
///      canceller. Timelock is self-administered (OZ admin = address(0)), so future role changes require
///      a timelock proposal.
///
/// IMPORTANT: on production chains BaseScript reverts unless ETH_FROM is set, to avoid falling back to the
/// public test mnemonic. ALWAYS pass your real signer. Example:
///   CHAIN_ID=42161 ETH_FROM=<ledger-addr> ADMIN_ADDRESS=<multisig> TIMELOCK_CANCELLER_ADDRESS=<canceller> \
///     forge script script/deploy/TimelockDeploy.s.sol --rpc-url arbitrum --broadcast --ledger --sender $ETH_FROM
///   (repeat with CHAIN_ID=8453 --rpc-url base for Base)
contract TimelockDeploy is BaseScript {
    function run() public broadcast returns (Timelock timelock) {
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address canceller = vm.envAddress("TIMELOCK_CANCELLER_ADDRESS");

        // 1 weeks == 604800s, the max allowed by Timelock and matching the Ethereum/Optimism delay.
        timelock = new Timelock(1 weeks, _singleAddressArray(admin), _singleAddressArray(admin), canceller);

        console2.log("Timelock deployed at:", address(timelock));
        console2.log("  min delay (s):     ", timelock.getMinDelay());
        console2.log("  proposer+executor: ", admin);
        console2.log("  canceller:         ", canceller);
        console2.log("Next: from the multisig, hand off ownership (grant DEFAULT_ADMIN_ROLE + transferOwnership, then renounce).");
    }
}
