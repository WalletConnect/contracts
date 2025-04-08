// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { LegacyL2WCT } from "src/legacy/LegacyL2WCT.sol";
import { L2WCT } from "src/L2WCT.sol";
import { WCT } from "src/WCT.sol";
import { BaseScript, EthereumDeployments, OptimismDeployments } from "script/Base.s.sol";
import { Eip1967Logger } from "script/utils/Eip1967Logger.sol";
import { DeploymentJsonWriter } from "script/utils/DeploymentJsonWriter.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Options } from "openzeppelin-foundry-upgrades/Options.sol";
import { newL2WCT } from "script/helpers/Proxy.sol";

struct LegacyDeploymentParams {
    address admin;
    address manager;
    address bridge;
    address superchainBridge;
    address remoteToken;
    bytes32 salt;
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
        LegacyDeploymentParams memory params = _readDeploymentParamsFromEnv();
        address legacyAddress = _computeLegacyAddress(params.salt);

        // Set up upgrade options
        Options memory opts;
        opts.referenceContract = "LegacyL2WCT.sol";
        opts.unsafeSkipAllChecks = false;

        // Validate the upgrade first
        Upgrades.validateUpgrade("L2WCT.sol", opts);

        // Upgrade using Upgrades library
        Upgrades.upgradeProxy(legacyAddress, "L2WCT.sol", bytes(""), opts);

        L2WCT upgraded = L2WCT(legacyAddress);

        upgraded.setBridge(params.superchainBridge);

        console2.log("Upgraded LegacyL2WCT to L2WCT at:", address(upgraded));

        // Write deployment to JSON if needed
        if (vm.envOr("WRITE_JSON", false)) {
            _updateDeploymentJson(address(upgraded), "L2WCT");
        }
    }

    function upgradeToWCT() public broadcast {
        LegacyDeploymentParams memory params = _readDeploymentParamsFromEnv();
        address legacyAddress = _computeLegacyAddress(params.salt);

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

    function _computeLegacyAddress(bytes32 salt) internal view returns (address) {
        // First compute implementation address
        bytes memory bytecode = abi.encodePacked(type(LegacyL2WCT).creationCode);
        bytes32 initCodeHash = keccak256(bytecode);
        address implementation = vm.computeCreate2Address(salt, initCodeHash);
        console2.log("Implementation address:", implementation);

        // Then compute proxy address
        bytecode = abi.encodePacked(
            type(TransparentUpgradeableProxy).creationCode,
            abi.encode(
                implementation,
                vm.envAddress("ADMIN_ADDRESS"),
                abi.encodeCall(
                    LegacyL2WCT.initialize,
                    LegacyL2WCT.Init({
                        initialAdmin: vm.envAddress("ADMIN_ADDRESS"),
                        initialManager: vm.envAddress("MANAGER_ADDRESS"),
                        bridge: vm.envAddress("OP_BRIDGE_ADDRESS"),
                        remoteToken: vm.envAddress("REMOTE_TOKEN_ADDRESS")
                    })
                )
            )
        );
        initCodeHash = keccak256(bytecode);

        return vm.computeCreate2Address(salt, initCodeHash);
    }

    function _readDeploymentParamsFromEnv() private view returns (LegacyDeploymentParams memory) {
        return LegacyDeploymentParams({
            admin: vm.envAddress("ADMIN_ADDRESS"),
            manager: vm.envAddress("MANAGER_ADDRESS"),
            bridge: vm.envAddress("OP_BRIDGE_ADDRESS"),
            superchainBridge: vm.envAddress("SUPERCHAIN_BRIDGE_ADDRESS"),
            remoteToken: vm.envAddress("REMOTE_TOKEN_ADDRESS"),
            salt: keccak256(abi.encodePacked("walletconnect.l2wct"))
        });
    }
}
