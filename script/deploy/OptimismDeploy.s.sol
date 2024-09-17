// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { Timelock } from "src/Timelock.sol";
import { L2WCT } from "src/L2WCT.sol";
import { OptimismDeployments, BaseScript } from "script/Base.s.sol";

struct OptimismDeploymentParams {
    address admin;
    address manager;
    address timelockCanceller;
    address opBridge;
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

    function logDeployments() public {
        OptimismDeployments memory deps = readOptimismDeployments(block.chainid);
        console2.log("L2WCT:", address(deps.l2wct));
        console2.log("Admin Timelock:", address(deps.adminTimelock));
        console2.log("Manager Timelock:", address(deps.managerTimelock));
    }

    function _deployAll(OptimismDeploymentParams memory params) private returns (OptimismDeployments memory) {
        uint256 parentChainId =
            block.chainid == getChain("optimism").chainId ? getChain("mainnet").chainId : getChain("sepolia").chainId;
        address remoteToken = address(readEthereumDeployments(parentChainId).wct);

        L2WCT l2wct = new L2WCT(params.admin, params.manager, address(params.opBridge), remoteToken);

        Timelock adminTimelock = new Timelock(
            1 weeks, _singleAddressArray(params.admin), _singleAddressArray(params.admin), params.timelockCanceller
        );
        Timelock managerTimelock = new Timelock(
            3 days, _singleAddressArray(params.manager), _singleAddressArray(params.manager), params.timelockCanceller
        );

        return OptimismDeployments({ l2wct: l2wct, adminTimelock: adminTimelock, managerTimelock: managerTimelock });
    }

    function _writeOptimismDeployments(OptimismDeployments memory deps) private {
        _writeDeployments(abi.encode(deps));
    }

    function _readDeploymentParamsFromEnv() private view returns (OptimismDeploymentParams memory) {
        return OptimismDeploymentParams({
            admin: vm.envAddress("ADMIN_ADDRESS"),
            manager: vm.envAddress("MANAGER_ADDRESS"),
            opBridge: vm.envAddress("OP_BRIDGE_ADDRESS"),
            timelockCanceller: vm.envAddress("TIMELOCK_CANCELLER_ADDRESS")
        });
    }
}
