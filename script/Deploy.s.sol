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
    address treasury;
    uint256 rewardsPerEpoch;
    uint256 initialTreasuryBalance;
    uint8 maxNodes;
    uint256 minStakeAmount;
}

contract Deploy is BaseScript {
    function _readDeploymentParamsFromEnv() internal view returns (DeploymentParams memory) {
        return DeploymentParams({
            manager: vm.envOr("MANAGER_ADDRESS", vm.addr(vm.deriveKey(mnemonic, 0))),
            treasury: vm.envOr("TREASURY_ADDRESS", vm.addr(vm.deriveKey(mnemonic, 1))),
            rewardsPerEpoch: vm.envUint("REWARDS_PER_EPOCH"),
            initialTreasuryBalance: vm.envUint("INITIAL_TREASURY_BALANCE"),
            maxNodes: uint8(vm.envUint("MAX_NODES")),
            minStakeAmount: vm.envUint("MIN_STAKE_AMOUNT")
        });
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
        PermissionedNodeRegistry registry =
            new PermissionedNodeRegistry({ initialOwner: params.manager, maxNodes_: params.maxNodes });
        console2.log("PermissionedNodeRegistry address:", address(registry));
        RewardManager rewardManager = new RewardManager({
            initialOwner: params.manager,
            initialMaxRewardsPerEpoch: params.rewardsPerEpoch,
            walletConnectConfig_: config
        });
        console2.log("RewardManager address:", address(rewardManager));
        Staking staking = new Staking({
            initialOwner: params.manager,
            initialMinStakeAmount: params.minStakeAmount,
            walletConnectConfig_: config
        });
        console2.log("Staking address:", address(staking));
        cnct.mint(params.treasury, params.initialTreasuryBalance);

        // Update the addresses in the config
        config.updateCnct(address(cnct));
        config.updatePauser(address(pauser));
        config.updatePermissionedNodeRegistry(address(registry));
        config.updateRewardManager(address(rewardManager));
        config.updateStaking(address(staking));
        config.updateWalletConnectRewardsVault(params.treasury);
        console2.log("WalletConnectConfig updated");

        vm.stopBroadcast();

        Deployments memory deploys = Deployments({
            cnct: cnct,
            pauser: pauser,
            registry: registry,
            rewardManager: rewardManager,
            staking: staking,
            config: config
        });

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
