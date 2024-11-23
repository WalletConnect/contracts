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
import { LockedTokenStaker } from "src/LockedTokenStaker.sol";
import { MerkleVester } from "src/interfaces/MerkleVester.sol";
import { OptimismDeployments, BaseScript } from "script/Base.s.sol";
import { Eip1967Logger } from "script/utils/Eip1967Logger.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
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
    bytes32 merkleRoot;
    address merkleVester;
}

contract OptimismDeploy is BaseScript {
    function run() public broadcast {
        console2.log("Deploying %s contracts", getChain(block.chainid).name);
        OptimismDeploymentParams memory params = _readDeploymentParamsFromEnv();
        OptimismDeployments memory deps = _deployAll(params);

        if (vm.envOr("BROADCAST", false)) {
            _writeOptimismDeployments(deps);
        }

        _setConfig(deps);

        _changeOwnership(params, deps);

        logDeployments();
    }

    function setConfig() public broadcast {
        OptimismDeployments memory deps = readOptimismDeployments(block.chainid);
        _setConfig(deps);
    }

    function _changeOwnership(OptimismDeploymentParams memory params, OptimismDeployments memory deps) private {
        // Config: Broadcaster -> Admin Timelock and Admin
        deps.config.grantRole(deps.config.DEFAULT_ADMIN_ROLE(), address(deps.adminTimelock));
        deps.config.revokeRole(deps.config.DEFAULT_ADMIN_ROLE(), params.admin);
        deps.config.revokeRole(deps.config.DEFAULT_ADMIN_ROLE(), broadcaster);

        // Pauser: Broadcaster -> Admin Timelock, Admin and Manager Timelock
        deps.pauser.revokeRole(deps.pauser.UNPAUSER_ROLE(), broadcaster);
        deps.pauser.grantRole(deps.pauser.UNPAUSER_ROLE(), address(deps.managerTimelock));
        deps.pauser.grantRole(deps.pauser.DEFAULT_ADMIN_ROLE(), params.admin);
        deps.pauser.grantRole(deps.pauser.DEFAULT_ADMIN_ROLE(), address(deps.adminTimelock));
        deps.pauser.revokeRole(deps.pauser.DEFAULT_ADMIN_ROLE(), broadcaster);
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
        console2.log("Admin Timelock:", address(deps.adminTimelock));
        console2.log("Manager Timelock:", address(deps.managerTimelock));
        console2.log("Airdrop:", address(deps.airdrop));
        console2.log("MerkleVester:", address(deps.merkleVester));
        console2.log("LockedTokenStaker:", address(deps.lockedTokenStaker));
    }

    function _deployAll(OptimismDeploymentParams memory params) private returns (OptimismDeployments memory) {
        uint256 parentChainId =
            block.chainid == getChain("optimism").chainId ? getChain("mainnet").chainId : getChain("sepolia").chainId;
        address remoteToken = address(readEthereumDeployments(parentChainId).wct);

        OptimismDeployments memory deployments = readOptimismDeployments(block.chainid);

        if (address(deployments.adminTimelock) == address(0)) {
            console2.log("Deploying Admin Timelock...");
            deployments.adminTimelock = new Timelock(
                1 weeks, _singleAddressArray(params.admin), _singleAddressArray(params.admin), params.timelockCanceller
            );
        }

        if (address(deployments.managerTimelock) == address(0)) {
            console2.log("Deploying Manager Timelock...");
            deployments.managerTimelock = new Timelock(
                3 days,
                _singleAddressArray(params.manager),
                _singleAddressArray(params.manager),
                params.timelockCanceller
            );
        }

        if (address(deployments.l2wct) == address(0)) {
            console2.log("Deploying L2WCT...");
            deployments.l2wct = newL2WCT({
                initialOwner: address(deployments.adminTimelock),
                init: L2WCT.Init({
                    initialAdmin: params.admin,
                    initialManager: params.manager,
                    bridge: address(params.opBridge),
                    remoteToken: remoteToken
                })
            });
        }

        if (address(deployments.config) == address(0)) {
            console2.log("Deploying WalletConnectConfig...");
            deployments.config = newWalletConnectConfig(
                address(deployments.adminTimelock), WalletConnectConfig.Init({ admin: broadcaster })
            );
        }

        if (address(deployments.pauser) == address(0)) {
            console2.log("Deploying Pauser...");
            deployments.pauser = newPauser(
                address(deployments.adminTimelock), Pauser.Init({ admin: broadcaster, pauser: params.pauser })
            );
        }

        if (address(deployments.stakeWeight) == address(0)) {
            console2.log("Deploying StakeWeight...");
            deployments.stakeWeight = newStakeWeight(
                address(deployments.adminTimelock),
                StakeWeight.Init({ admin: params.admin, config: address(deployments.config) })
            );
        }

        if (address(deployments.stakingRewardDistributor) == address(0)) {
            console2.log("Deploying StakingRewardDistributor...");
            deployments.stakingRewardDistributor = newStakingRewardDistributor(
                address(deployments.adminTimelock),
                StakingRewardDistributor.Init({
                    admin: params.treasury,
                    config: address(deployments.config),
                    startTime: 1_732_752_000, // 2024-11-28 00:00:00 UTC
                    emergencyReturn: params.emergencyReturn
                })
            );
        }

        return deployments;
    }

    function deployAirdrop() public broadcast {
        OptimismDeployments memory deps = readOptimismDeployments(block.chainid);
        OptimismDeploymentParams memory params = _readDeploymentParamsFromEnv();

        if (address(deps.airdrop) == address(0)) {
            deps.airdrop =
                new Airdrop(params.admin, params.pauser, params.treasury, params.merkleRoot, address(deps.l2wct));
        }

        if (vm.envOr("BROADCAST", false)) {
            _writeOptimismDeployments(deps);
        }
    }

    function deployLockedTokenStaker() public broadcast {
        OptimismDeploymentParams memory params = _readDeploymentParamsFromEnv();
        OptimismDeployments memory deps = readOptimismDeployments(block.chainid);

        if (address(deps.adminTimelock) == address(0)) {
            revert("Admin Timelock not deployed");
        }

        if (params.merkleVester == address(0)) {
            revert("Merkle Vester not set");
        }

        if (address(deps.merkleVester) == address(0)) {
            deps.merkleVester = MerkleVester(params.merkleVester);
        }

        if (address(deps.lockedTokenStaker) == address(0)) {
            deps.lockedTokenStaker = new LockedTokenStaker{
                salt: keccak256(abi.encodePacked("walletconnect.lockedtokenstaker"))
            }(deps.merkleVester, WalletConnectConfig(address(deps.config)));
        }

        if (vm.envOr("BROADCAST", false)) {
            _writeOptimismDeployments(deps);
        }
    }

    function verifyDeployments() public {
        OptimismDeployments memory deps = readOptimismDeployments(block.chainid);
        OptimismDeploymentParams memory params = _readDeploymentParamsFromEnv();
        // Verify all deployed
        if (address(deps.adminTimelock) == address(0)) {
            revert("Admin Timelock not deployed");
        }
        if (address(deps.managerTimelock) == address(0)) {
            revert("Manager Timelock not deployed");
        }
        if (address(deps.l2wct) == address(0)) {
            revert("L2WCT not deployed");
        }
        if (address(deps.config) == address(0)) {
            revert("WalletConnectConfig not deployed");
        }
        if (address(deps.pauser) == address(0)) {
            revert("Pauser not deployed");
        }
        if (address(deps.stakeWeight) == address(0)) {
            revert("StakeWeight not deployed");
        }
        if (address(deps.airdrop) == address(0)) {
            console2.log("Airdrop not deployed");
        }
        if (address(deps.merkleVester) == address(0)) {
            console2.log("MerkleVester not deployed");
        }
        if (address(deps.lockedTokenStaker) == address(0)) {
            console2.log("LockedTokenStaker not deployed");
        }

        // Proxy admin owner is deps.adminTimelock
        ProxyAdmin l2wctProxyAdmin = ProxyAdmin(Eip1967Logger.getAdmin(vm, address(deps.l2wct)));
        if (l2wctProxyAdmin.owner() != address(deps.adminTimelock)) {
            console2.log("L2WCT Proxy Admin owner is not Admin Timelock");
        }

        ProxyAdmin configProxyAdmin = ProxyAdmin(Eip1967Logger.getAdmin(vm, address(deps.config)));
        if (configProxyAdmin.owner() != address(deps.adminTimelock)) {
            revert("WalletConnectConfig Proxy Admin owner is not Admin Timelock");
        }

        ProxyAdmin pauserProxyAdmin = ProxyAdmin(Eip1967Logger.getAdmin(vm, address(deps.pauser)));
        if (pauserProxyAdmin.owner() != address(deps.adminTimelock)) {
            revert("Pauser Proxy Admin owner is not Admin Timelock");
        }

        ProxyAdmin stakeWeightProxyAdmin = ProxyAdmin(Eip1967Logger.getAdmin(vm, address(deps.stakeWeight)));
        if (stakeWeightProxyAdmin.owner() != address(deps.adminTimelock)) {
            revert("StakeWeight Proxy Admin owner is not Admin Timelock");
        }

        ProxyAdmin stakingRewardDistributorProxyAdmin =
            ProxyAdmin(Eip1967Logger.getAdmin(vm, address(deps.stakingRewardDistributor)));

        if (stakingRewardDistributorProxyAdmin.owner() != address(deps.adminTimelock)) {
            revert("StakingRewardDistributor Proxy Admin owner is not Admin Timelock");
        }

        // L2WCT
        if (!deps.l2wct.hasRole(deps.l2wct.DEFAULT_ADMIN_ROLE(), address(deps.adminTimelock))) {
            console2.log("L2WCT default admin is not Admin Timelock");
        }
        if (!deps.l2wct.hasRole(deps.l2wct.MANAGER_ROLE(), address(deps.managerTimelock))) {
            console2.log("L2WCT manager role is not Manager Timelock");
        }
        if (deps.l2wct.hasRole(deps.l2wct.MANAGER_ROLE(), params.manager)) {
            console2.log("L2WCT manager role is Manager MultiSig");
        }
        if (deps.l2wct.hasRole(deps.l2wct.DEFAULT_ADMIN_ROLE(), params.admin)) {
            console2.log("L2WCT default admin is Admin MultiSig");
        }

        // StakingRewardDistributor
        if (deps.stakingRewardDistributor.owner() != address(params.treasury)) {
            revert("StakingRewardDistributor owner is not Treasury");
        }

        // Config
        // Role checks
        if (!deps.config.hasRole(deps.config.DEFAULT_ADMIN_ROLE(), address(deps.adminTimelock))) {
            revert("WalletConnectConfig default admin is not Admin Timelock");
        }
        if (deps.config.hasRole(deps.config.DEFAULT_ADMIN_ROLE(), broadcaster)) {
            revert("WalletConnectConfig default admin is broadcaster");
        }
        if (deps.config.hasRole(deps.config.DEFAULT_ADMIN_ROLE(), params.admin)) {
            console2.log("WalletConnectConfig default admin is Admin MultiSig");
        }
        // Value checks
        if (deps.config.getL2wct() != address(deps.l2wct)) {
            console2.log("WalletConnectConfig l2wct is not L2WCT");
        }
        if (deps.config.getPauser() != address(deps.pauser)) {
            console2.log("WalletConnectConfig pauser is not Pauser");
        }
        if (deps.config.getStakeWeight() != address(deps.stakeWeight)) {
            console2.log("WalletConnectConfig stakeWeight is not StakeWeight");
        }
        // StakeWeight
        if (!deps.stakeWeight.hasRole(deps.stakeWeight.DEFAULT_ADMIN_ROLE(), address(deps.adminTimelock))) {
            console2.log("StakeWeight default admin is not Admin Timelock");
        }
        if (deps.stakeWeight.hasRole(deps.stakeWeight.DEFAULT_ADMIN_ROLE(), broadcaster)) {
            revert("StakeWeight default admin is broadcaster");
        }
        if (deps.stakeWeight.hasRole(deps.stakeWeight.DEFAULT_ADMIN_ROLE(), params.admin)) {
            console2.log("StakeWeight default admin is Admin MultiSig");
        }
        // Pauser
        if (!deps.pauser.hasRole(deps.pauser.PAUSER_ROLE(), address(params.pauser))) {
            revert("Pauser pauser role is not Pauser MultiSig");
        }
        if (!deps.pauser.hasRole(deps.pauser.UNPAUSER_ROLE(), address(deps.managerTimelock))) {
            revert("Pauser unpauser role is not Manager Timelock");
        }
        if (!deps.pauser.hasRole(deps.pauser.DEFAULT_ADMIN_ROLE(), address(deps.adminTimelock))) {
            revert("Pauser default admin is not Admin Timelock");
        }
        if (deps.pauser.hasRole(deps.pauser.DEFAULT_ADMIN_ROLE(), params.admin)) {
            console2.log("Pauser default admin is Admin MultiSig");
        }
        if (deps.pauser.hasRole(deps.pauser.DEFAULT_ADMIN_ROLE(), broadcaster)) {
            revert("Pauser default admin is broadcaster");
        }
        if (deps.pauser.hasRole(deps.pauser.UNPAUSER_ROLE(), broadcaster)) {
            revert("Pauser unpauser role is broadcaster");
        }

        // Airdrop
        // if (deps.airdrop.merkleRoot() != params.merkleRoot) {
        //     console2.log("Airdrop merkleRoot is not Merkle Root");
        // }
        // if (deps.airdrop.reserveAddress() != params.treasury) {
        //     console2.log("Airdrop reserveAddress is not Treasury");
        // }
        // // LockedTokenStaker
        // if (!deps.stakeWeight.hasRole(deps.stakeWeight.LOCKED_TOKEN_STAKER_ROLE(), address(deps.lockedTokenStaker)))
        // {
        //     console2.log("StakeWeight lockedTokenStaker role is not LockedTokenStaker");
        // }
        // address[] memory postClaimHandlers = deps.merkleVester.getPostClaimHandlers();
        // if (postClaimHandlers.length != 1 || postClaimHandlers[0] != address(deps.lockedTokenStaker)) {
        //     console2.log("MerkleVester postClaimHandlerWhitelist is not LockedTokenStaker");
        // }
        console2.log("Good to go!");
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
            treasury: vm.envAddress("TREASURY_ADDRESS"),
            merkleRoot: vm.envBytes32("MERKLE_ROOT"),
            merkleVester: vm.envAddress("MERKLE_VESTER_ADDRESS")
        });
    }
}
