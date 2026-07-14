// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { LegacyL2WCT } from "src/legacy/LegacyL2WCT.sol";
import { L2WCT } from "src/L2WCT.sol";
import { WCT } from "src/WCT.sol";
import { BaseScript, EthereumDeployments, OptimismDeployments } from "script/Base.s.sol";
import { Eip1967Logger } from "script/utils/Eip1967Logger.sol";
import { DeploymentJsonWriter } from "script/utils/DeploymentJsonWriter.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Options } from "openzeppelin-foundry-upgrades/Options.sol";
import { newL2WCT } from "script/helpers/Proxy.sol";

struct LegacyDeploymentParams {
    address admin;
    address manager;
    address bridge;
    address remoteToken;
}

contract WCTDeploy is BaseScript {
    // Add helper function to check if chain is OP Superchain
    function _isOpSuperchain(uint256 chainId) internal returns (bool) {
        return chainId == getChain("optimism").chainId || chainId == getChain("base").chainId
            || chainId == getChain("optimism_sepolia").chainId || chainId == getChain("base_sepolia").chainId;
    }

    // Helper function to handle deployment JSON updates
    function _updateDeploymentJson(address contractAddress, string memory contractType) internal {
        string memory deploymentsPath =
            string.concat(vm.projectRoot(), "/deployments/", vm.toString(block.chainid), ".json");

        if (_isOpSuperchain(block.chainid)) {
            OptimismDeployments memory deps;
            if (vm.exists(deploymentsPath)) {
                deps = readOptimismDeployments(block.chainid);
            }
            deps.l2wct = L2WCT(contractAddress);
            DeploymentJsonWriter.writeOptimismDeploymentsToJson(vm, block.chainid, deps);
        } else {
            EthereumDeployments memory deps;
            if (vm.exists(deploymentsPath)) {
                deps = readEthereumDeployments(block.chainid);
            }
            deps.wct = WCT(contractAddress);
            DeploymentJsonWriter.writeEthereumDeploymentsToJson(vm, block.chainid, deps);
        }
    }

    function run() public broadcast {
        console2.log("Deploying LegacyL2WCT on %s", getChain(block.chainid).name);
        LegacyDeploymentParams memory params = _readDeploymentParamsFromEnv();

        // Deploy LegacyL2WCT using the helper function
        LegacyL2WCT legacyL2WCT = newL2WCT(
            params.admin,
            LegacyL2WCT.Init({
                initialAdmin: params.admin,
                initialManager: params.manager,
                bridge: params.bridge,
                remoteToken: params.remoteToken
            })
        );

        // Log the deployment
        Eip1967Logger.logEip1967(vm, "LegacyL2WCT", address(legacyL2WCT));
        console2.log("LegacyL2WCT deployed at:", address(legacyL2WCT));

        // Write deployment to JSON if needed
        if (vm.envOr("WRITE_JSON", false)) {
            _updateDeploymentJson(address(legacyL2WCT), "LegacyL2WCT");
        }
    }

    function upgradeToL2WCT() public broadcast {
        // Only the superchain bridge is needed for this upgrade; read it directly rather than loading the
        // full deployment params, which would revert on unrelated unset env vars (ADMIN_ADDRESS,
        // OP_BRIDGE_ADDRESS, …) that a pure upgrade has no reason to set.
        address superchainBridge = vm.envAddress("SUPERCHAIN_BRIDGE_ADDRESS");
        // Read the deployed proxy from the persisted artifact rather than recomputing its CREATE2 address
        // (which depends on the proxy's initialOwner/init-calldata and diverges from what other deploy
        // paths actually deployed).
        address legacyAddress = _readDeployedProxy();

        // Set up upgrade options
        Options memory opts;
        opts.referenceContract = "LegacyL2WCT.sol";
        opts.unsafeSkipAllChecks = false;

        // Validate the upgrade first
        Upgrades.validateUpgrade("L2WCT.sol", opts);

        // Upgrade using Upgrades library
        Upgrades.upgradeProxy(legacyAddress, "L2WCT.sol", bytes(""), opts);

        L2WCT upgraded = L2WCT(legacyAddress);

        upgraded.setBridge(superchainBridge);

        console2.log("Upgraded LegacyL2WCT to L2WCT at:", address(upgraded));

        // Write deployment to JSON if needed
        if (vm.envOr("WRITE_JSON", false)) {
            _updateDeploymentJson(address(upgraded), "L2WCT");
        }
    }

    function upgradeToWCT() public broadcast {
        // Read the deployed proxy from the persisted artifact rather than recomputing its CREATE2 address.
        address legacyAddress = _readDeployedProxy();

        // Set up upgrade options
        Options memory opts;
        opts.referenceContract = "LegacyL2WCT.sol";
        opts.unsafeSkipAllChecks = false;

        // Validate the upgrade first
        Upgrades.validateUpgrade("WCT.sol", opts);

        // Upgrade using Upgrades library
        Upgrades.upgradeProxy(legacyAddress, "WCT.sol", bytes(""), opts);

        WCT upgraded = WCT(legacyAddress);

        console2.log("Upgraded LegacyL2WCT to WCT at:", address(upgraded));

        // Write deployment to JSON if needed
        if (vm.envOr("WRITE_JSON", false)) {
            _updateDeploymentJson(address(upgraded), "WCT");
        }
    }

    /// @dev Resolve the deployed WCT/L2WCT proxy from the persisted deployment JSON, which is the source of
    /// truth. Recomputing the CREATE2 address is unsafe: the proxy address depends on its initialOwner and
    /// init calldata, and those differ across deploy paths (e.g. OptimismDeploy uses the admin timelock as
    /// owner, WCTDeploy used ADMIN_ADDRESS), so recomputation can silently point at a codeless phantom
    /// address. Reads the JSON (`deployments/<chainId>.json`) rather than the binary artifact, because some
    /// chains (e.g. Arbitrum, Base) only ship the JSON. Mirrors the OP-vs-Ethereum branching of _updateDeploymentJson.
    function _readDeployedProxy() internal returns (address proxy) {
        string memory path =
            string.concat(vm.projectRoot(), "/deployments/", vm.toString(block.chainid), ".json");
        require(vm.exists(path), "WCTDeploy: no deployment JSON for chain");
        string memory json = vm.readFile(path);
        string memory key = _isOpSuperchain(block.chainid) ? ".L2WCT.address" : ".WCT.address";
        proxy = vm.parseJsonAddress(json, key);
        require(proxy != address(0), "WCTDeploy: no deployed proxy recorded in artifact");
        require(proxy.code.length > 0, "WCTDeploy: artifact proxy address has no code");
    }

    function _readDeploymentParamsFromEnv() private view returns (LegacyDeploymentParams memory) {
        return LegacyDeploymentParams({
            admin: vm.envAddress("ADMIN_ADDRESS"),
            manager: vm.envAddress("MANAGER_ADDRESS"),
            bridge: vm.envAddress("OP_BRIDGE_ADDRESS"),
            remoteToken: vm.envAddress("REMOTE_TOKEN_ADDRESS")
        });
    }
}
