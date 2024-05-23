// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { BaseScript, Deployments } from "./Base.s.sol";
import { BRR } from "src/BRR.sol";
import { deployAll } from "./helpers/Proxy.sol";

/// @notice Deployment parameters for the protocol contracts
/// @dev These are mostly externally controlled addresses
/// @param manager the manager of the contracts (allowed to access setters, etc.). Using the same manager for all
/// @param treasury the reward vault treasury
/// @param maxRewardsPerEpoch the amount of rewards in wei to distribute per epoch
/// @param initialTreasuryBalance the initial amount in wei to mint to the treasury
/// @param maxNodes the maximum number of nodes allowed in the registry
/// @param minStakeAmount the minimum amount of wei required to stake, also unstaking cannot make stake go below this
/// @param isStakingAllowlist whether to allow only whitelisted addresses to stake

struct DeploymentParams {
    address manager;
    address treasury;
    uint8 maxNodes;
    bool isStakingAllowlist;
    uint256 maxRewardsPerEpoch;
    uint256 initialTreasuryBalance;
    uint256 minStakeAmount;
}

contract Deploy is BaseScript {
    function _readDeploymentParamsFromEnv() internal view returns (DeploymentParams memory) {
        return DeploymentParams({
            manager: vm.envOr("MANAGER_ADDRESS", vm.addr(vm.deriveKey(mnemonic, 0))),
            treasury: vm.envOr("TREASURY_ADDRESS", vm.addr(vm.deriveKey(mnemonic, 1))),
            maxRewardsPerEpoch: vm.envUint("REWARDS_PER_EPOCH"),
            initialTreasuryBalance: vm.envUint("INITIAL_TREASURY_BALANCE"),
            isStakingAllowlist: vm.envOr("IS_STAKING_ALLOWLIST", true),
            maxNodes: uint8(vm.envUint("MAX_NODES")),
            minStakeAmount: vm.envUint("MIN_STAKE_AMOUNT")
        });
    }

    function deploy() public {
        Deployments memory existingDeployments = readDeployments();
        if (existingDeployments.brr == BRR(address(0))) {
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

        vm.startBroadcast();
        Deployments memory deps = deployAll(params);
        vm.stopBroadcast();

        writeDeployments(deps);
        logDeployments(deps);
    }

    function logDeployments(Deployments memory deps) public pure {
        _logDeployments(deps);
    }

    function logDeployments() public {
        Deployments memory deps = readDeployments();

        _logDeployments(deps);
    }

    function _logDeployments(Deployments memory deps) internal pure {
        console2.log("BRR:", address(deps.brr));
        console2.log("Config:", address(deps.config));
        console2.log("Pauser:", address(deps.pauser));
        console2.log("Registry:", address(deps.registry));
        console2.log("RewardManager:", address(deps.rewardManager));
        console2.log("Staking:", address(deps.staking));
    }

    function mintTreasuryBalance() public {
        DeploymentParams memory params = _readDeploymentParamsFromEnv();
        Deployments memory deps = readDeployments();
        deps.brr.mint(params.treasury, params.initialTreasuryBalance);
    }
}
