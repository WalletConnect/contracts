// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { Timelock } from "src/Timelock.sol";
import { L2WCT } from "src/L2WCT.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";
import { Pauser } from "src/Pauser.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { Airdrop } from "src/Airdrop.sol";
import { AirdropJsonHandler } from "script/utils/AirdropJsonHandler.sol";
import { OptimismDeployments, BaseScript } from "script/Base.s.sol";
import { Eip1967Logger } from "script/utils/Eip1967Logger.sol";
import {
    newL2WCT,
    newWalletConnectConfig,
    newPauser,
    newStakeWeight,
    newStakingRewardDistributor
} from "script/helpers/Proxy.sol";

struct OptimismDeploymentParams {
    address admin;
    address manager;
    address timelockCanceller;
    address opBridge;
    address pauser;
    address emergencyReturn;
    address treasury;
}

contract OptimismDeploy is BaseScript {
    function run() public broadcast {
        if (address(readOptimismDeployments(block.chainid).l2wct) != address(0)) {
            return console2.log("%s contracts already deployed", getChain(block.chainid).name);
        }

        console2.log("Deploying %s contracts", getChain(block.chainid).name);
        OptimismDeployments memory deps = _deployAll(_readDeploymentParamsFromEnv());

        if (vm.envOr("BROADCAST", false)) {
            _writeOptimismDeployments(deps);
        }

        logDeployments();
    }

    function setConfig() public broadcast {
        OptimismDeployments memory deps = readOptimismDeployments(block.chainid);
        deps.config.updateL2wct(address(deps.l2wct));
        deps.config.updatePauser(address(deps.pauser));
        deps.config.updateStakeWeight(address(deps.stakeWeight));
    }

    function logDeployments() public {
        OptimismDeployments memory deps = readOptimismDeployments(block.chainid);
        Eip1967Logger.logEip1967(vm, "L2WCT", address(deps.l2wct));
        Eip1967Logger.logEip1967(vm, "WalletConnectConfig", address(deps.config));
        Eip1967Logger.logEip1967(vm, "Pauser", address(deps.pauser));
        Eip1967Logger.logEip1967(vm, "StakeWeight", address(deps.stakeWeight));
        Eip1967Logger.logEip1967(vm, "StakingRewardDistributor", address(deps.stakingRewardDistributor));
        console2.log("Admin Timelock:", address(deps.adminTimelock));
        console2.log("Manager Timelock:", address(deps.managerTimelock));
        console2.log("Airdrop:", address(deps.airdrop));
    }

    function _deployAll(OptimismDeploymentParams memory params) private returns (OptimismDeployments memory) {
        uint256 parentChainId =
            block.chainid == getChain("optimism").chainId ? getChain("mainnet").chainId : getChain("sepolia").chainId;
        address remoteToken = address(readEthereumDeployments(parentChainId).wct);

        L2WCT l2wct = newL2WCT({
            initialOwner: params.admin,
            init: L2WCT.Init({
                initialAdmin: params.admin,
                initialManager: params.manager,
                bridge: address(params.opBridge),
                remoteToken: remoteToken
            })
        });

        WalletConnectConfig config =
            newWalletConnectConfig(params.admin, WalletConnectConfig.Init({ admin: params.admin }));

        Pauser pauser = newPauser(params.admin, Pauser.Init({ admin: params.admin, pauser: params.pauser }));

        StakeWeight stakeWeight =
            newStakeWeight(params.admin, StakeWeight.Init({ admin: params.admin, config: address(config) }));

        StakingRewardDistributor stakingRewardDistributor = newStakingRewardDistributor(
            params.admin,
            StakingRewardDistributor.Init({
                admin: params.admin,
                config: address(config),
                startTime: block.timestamp + 2 weeks,
                emergencyReturn: params.emergencyReturn
            })
        );

        Timelock adminTimelock = new Timelock(
            1 weeks, _singleAddressArray(params.admin), _singleAddressArray(params.admin), params.timelockCanceller
        );
        Timelock managerTimelock = new Timelock(
            3 days, _singleAddressArray(params.manager), _singleAddressArray(params.manager), params.timelockCanceller
        );

        return OptimismDeployments({
            l2wct: l2wct,
            adminTimelock: adminTimelock,
            managerTimelock: managerTimelock,
            config: config,
            pauser: pauser,
            stakeWeight: stakeWeight,
            stakingRewardDistributor: stakingRewardDistributor,
            airdrop: Airdrop(address(0))
        });
    }

    function deployAirdrop() public broadcast {
        OptimismDeployments memory deps = readOptimismDeployments(block.chainid);
        OptimismDeploymentParams memory params = _readDeploymentParamsFromEnv();

        (bytes32 merkleRoot,) = AirdropJsonHandler.jsonToMerkleRoot(vm, "/script/data/airdrop_data.json");
        Airdrop airdrop = new Airdrop(params.admin, params.pauser, params.treasury, merkleRoot, address(deps.l2wct));

        deps.airdrop = airdrop;

        _writeOptimismDeployments(deps);
    }

    function _writeOptimismDeployments(OptimismDeployments memory deps) private {
        _writeDeployments(abi.encode(deps));
    }

    function _readDeploymentParamsFromEnv() private view returns (OptimismDeploymentParams memory) {
        return OptimismDeploymentParams({
            admin: vm.envAddress("ADMIN_ADDRESS"),
            manager: vm.envAddress("MANAGER_ADDRESS"),
            opBridge: vm.envAddress("OP_BRIDGE_ADDRESS"),
            timelockCanceller: vm.envAddress("TIMELOCK_CANCELLER_ADDRESS"),
            pauser: vm.envAddress("PAUSER_ADDRESS"),
            emergencyReturn: vm.envAddress("EMERGENCY_RETURN_ADDRESS"),
            treasury: vm.envAddress("TREASURY_ADDRESS")
        });
    }
}
