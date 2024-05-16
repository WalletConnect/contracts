// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

import { CNCT } from "src/CNCT.sol";
import { Pauser } from "src/Pauser.sol";
import { PermissionedNodeRegistry } from "src/PermissionedNodeRegistry.sol";
import { RewardManager } from "src/RewardManager.sol";
import { Staking } from "src/Staking.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";
import { console2 } from "forge-std/src/console2.sol";

import { BaseScript, Deployments } from "./Base.s.sol";

/// @notice Deployment paramaters for the protocol contract
/// @dev These are mostly externally controlled addresses
/// @param manager the manager of the contracts (allowed to access setters, etc.). Using the same manager for all

struct DeploymentParams {
    address manager;
}

contract Deploy is BaseScript {
    function _readDeploymentParamsFromEnv() internal view returns (DeploymentParams memory) {
        return DeploymentParams({ manager: vm.envOr("MANAGER_ADDRESS", broadcaster) });
    }

    function _deployAll(DeploymentParams memory params) internal returns (Deployments memory) {
        vm.startBroadcast();
        WalletConnectConfig config = new WalletConnectConfig({ initialOwner: params.manager });
        console2.log("WalletConnectConfig address:", address(config));
        CNCT cnct = new CNCT({ initialOwner: params.manager });
        console2.log("CNCT address:", address(cnct));
        Pauser pauser =
            new Pauser(Pauser.Init({ admin: params.manager, pauser: params.manager, unpauser: params.manager }));
        console2.log("Pauser address:", address(pauser));
        PermissionedNodeRegistry registry = new PermissionedNodeRegistry({ initialOwner: params.manager });
        console2.log("PermissionedNodeRegistry address:", address(registry));
        RewardManager rewardManager =
            new RewardManager({ initialOwner: params.manager, initialRewardsPerEpoch: 0, walletConnectConfig_: config });
        console2.log("RewardManager address:", address(rewardManager));
        Staking staking = new Staking({ initialOwner: params.manager });
        console2.log("Staking address:", address(staking));

        Deployments memory deploys = Deployments({
            cnct: cnct,
            pauser: pauser,
            registry: registry,
            rewardManager: rewardManager,
            staking: staking,
            config: config
        });
        vm.stopBroadcast();

        writeDeployments(deploys);
        return deploys;
    }

    function run() public {
        Deployments memory existingDeployments = readDeployments();
        if (existingDeployments.cnct == CNCT(address(0))) {
            console2.log("Deploying all contracts");
        } else {
            console2.log("Contracts already deployed");
            string memory res = vm.prompt("Do you want to redeploy all contracts? (y/N)");
            if (bytes(res).length != 1 || bytes(res)[0] != "y") {
                console2.log("Exiting");
                return;
            }
        }
        DeploymentParams memory params = _readDeploymentParamsFromEnv();
        Deployments memory deps = _deployAll(params);
        writeDeployments(deps);
    }
}
