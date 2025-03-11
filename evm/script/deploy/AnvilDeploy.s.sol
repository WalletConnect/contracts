// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { Timelock } from "src/Timelock.sol";
import { L2WCT } from "src/L2WCT.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";
import { Pauser } from "src/Pauser.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { StakingRewardsCalculator } from "src/StakingRewardsCalculator.sol";
import { Airdrop } from "src/Airdrop.sol";
import { LockedTokenStaker } from "src/LockedTokenStaker.sol";
import { MerkleVester } from "src/interfaces/MerkleVester.sol";
import { AirdropJsonHandler } from "script/utils/AirdropJsonHandler.sol";
import { OptimismDeployments, BaseScript } from "script/Base.s.sol";
import { Eip1967Logger } from "script/utils/Eip1967Logger.sol";
import {
    newMockERC20,
    newWalletConnectConfig,
    newPauser,
    newStakeWeight,
    newStakingRewardDistributor
} from "script/helpers/Proxy.sol";
import { DeploymentJsonWriter } from "script/utils/DeploymentJsonWriter.sol";
import { stdJson } from "forge-std/StdJson.sol";

struct AnvilDeploymentParams {
    address admin;
    address manager;
    address timelockCanceller;
    address opBridge;
    address pauser;
    address emergencyReturn;
    address treasury;
}

contract AnvilDeploy is BaseScript {
    using stdJson for string;

    function run() public broadcast {
        if (address(readOptimismDeployments(block.chainid).l2wct) != address(0)) {
            string memory shouldOverride = vm.prompt("Contracts already deployed. Override? (y/n)");
            if (keccak256(bytes(shouldOverride)) != keccak256(bytes("y"))) {
                return console2.log("%s contracts already deployed", getChain(block.chainid).name);
            }
        }

        console2.log("Deploying %s contracts", getChain(block.chainid).name);
        OptimismDeployments memory deps = _deployAll(_readDeploymentParamsFromEnv());

        if (vm.envOr("BROADCAST", false)) {
            _writeOptimismDeployments(deps);
        }

        _setConfig(deps);

        logDeployments();
    }

    function _setConfig(OptimismDeployments memory deps) private {
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
        console2.log("Airdrop:", address(deps.airdrop));
        console2.log("Admin Timelock:", address(deps.adminTimelock));
        console2.log("Manager Timelock:", address(deps.managerTimelock));

        // Write JSON deployment file
        if (vm.envOr("WRITE_JSON", false)) {
            DeploymentJsonWriter.writeOptimismDeploymentsToJson(vm, block.chainid, deps);
        }
    }

    function _deployAll(AnvilDeploymentParams memory params) private returns (OptimismDeployments memory) {
        L2WCT l2wct = L2WCT(address(newMockERC20(params.admin)));

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

        // Read only the merkle root from the JSON file to avoid OOM errors
        string memory fullPath = string.concat(vm.projectRoot(), "/script/data/airdrop_data.json");
        string memory json = vm.readFile(fullPath);
        bytes32 merkleRoot = json.readBytes32(".merkleRoot");

        // If the merkle root is zero, use a non-zero value to avoid the InvalidMerkleRoot error
        if (merkleRoot == bytes32(0)) {
            merkleRoot = 0x1234567890123456789012345678901234567890123456789012345678901234;
        }

        Airdrop airdrop = new Airdrop(params.admin, params.pauser, params.treasury, merkleRoot, address(l2wct));

        return OptimismDeployments({
            l2wct: l2wct,
            config: config,
            pauser: pauser,
            stakeWeight: stakeWeight,
            stakingRewardDistributor: stakingRewardDistributor,
            adminTimelock: adminTimelock,
            managerTimelock: managerTimelock,
            airdrop: airdrop,
            lockedTokenStakerReown: LockedTokenStaker(address(0)),
            merkleVesterReown: MerkleVester(address(0)),
            lockedTokenStakerWalletConnect: LockedTokenStaker(address(0)),
            merkleVesterWalletConnect: MerkleVester(address(0)),
            lockedTokenStakerBackers: LockedTokenStaker(address(0)),
            merkleVesterBackers: MerkleVester(address(0)),
            stakingRewardsCalculator: StakingRewardsCalculator(address(0))
        });
    }

    function _writeOptimismDeployments(OptimismDeployments memory deps) private {
        _writeDeployments(abi.encode(deps));
    }

    function _readDeploymentParamsFromEnv() private view returns (AnvilDeploymentParams memory) {
        return AnvilDeploymentParams({
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
