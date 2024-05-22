// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy,
    ProxyAdmin
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { BRR } from "src/BRR.sol";
import { Pauser } from "src/Pauser.sol";
import { PermissionedNodeRegistry } from "src/PermissionedNodeRegistry.sol";
import { RewardManager } from "src/RewardManager.sol";
import { Staking } from "src/Staking.sol";
import { BakersSyndicateConfig } from "src/BakersSyndicateConfig.sol";

import { DeploymentParams } from "../Deploy.s.sol";
import { Deployments } from "../Base.s.sol";

/// @notice Deploys all proxy and implementation contract, initializes them and returns a struct containing all the
/// addresses.
/// @dev All upgradeable contracts are deployed using the transparent proxy pattern, with the proxy admin being a
/// timelock controller with `params.upgrader` as proposer and executor, and `params.admin` as timelock admin.
/// @param params the configuration to use for the deployment.
function deployAll(DeploymentParams memory params) returns (Deployments memory) {
    // Deploy proxies
    BakersSyndicateConfig config = BakersSyndicateConfig(
        Upgrades.deployTransparentProxy(
            "BakersSyndicateConfig.sol:BakersSyndicateConfig",
            params.manager,
            abi.encodeCall(BakersSyndicateConfig.initialize, BakersSyndicateConfig.Init({ owner: params.manager }))
        )
    );
    Pauser pauser = Pauser(
        Upgrades.deployTransparentProxy(
            "Pauser.sol:Pauser",
            params.manager,
            abi.encodeCall(Pauser.initialize, Pauser.Init({ owner: params.manager }))
        )
    );
    RewardManager rewardManager = RewardManager(
        Upgrades.deployTransparentProxy(
            "RewardManager.sol:RewardManager",
            params.manager,
            abi.encodeCall(
                RewardManager.initialize,
                RewardManager.Init({
                    owner: params.manager,
                    maxRewardsPerEpoch: params.maxRewardsPerEpoch,
                    bakersSyndicateConfig: config
                })
            )
        )
    );
    Staking staking = Staking(
        Upgrades.deployTransparentProxy(
            "Staking.sol:Staking",
            params.manager,
            abi.encodeCall(
                Staking.initialize,
                Staking.Init({
                    owner: params.manager,
                    minStakeAmount: params.minStakeAmount,
                    isStakingAllowlist: params.isStakingAllowlist,
                    bakersSyndicateConfig: config
                })
            )
        )
    );

    // Deploy non-proxy contracts
    BRR brr = new BRR({ initialOwner: params.manager });
    PermissionedNodeRegistry registry =
        new PermissionedNodeRegistry({ initialOwner: params.manager, maxNodes_: params.maxNodes });

    // Update the addresses in the config
    config.updateBrr(address(brr));
    config.updatePauser(address(pauser));
    config.updatePermissionedNodeRegistry(address(registry));
    config.updateRewardManager(address(rewardManager));
    config.updateStaking(address(staking));
    config.updateBakersSyndicateRewardsVault(params.treasury);

    Deployments memory deploys = Deployments({
        brr: brr,
        pauser: pauser,
        registry: registry,
        rewardManager: rewardManager,
        staking: staking,
        config: config
    });

    return deploys;
}
