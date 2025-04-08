// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { Timelock } from "src/Timelock.sol";
import { EthereumDeployments, BaseScript } from "script/Base.s.sol";
import { Eip1967Logger } from "script/utils/Eip1967Logger.sol";
import { DeploymentJsonWriter } from "script/utils/DeploymentJsonWriter.sol";
import { WCT } from "src/WCT.sol";

struct EthereumDeploymentParams {
    address admin;
    address timelockCanceller;
    address nttManager;
}

contract EthereumDeploy is BaseScript {
    function run() public broadcast {
        console2.log("Deploying %s contracts", getChain(block.chainid).name);
        if (address(readEthereumDeployments(block.chainid).wct) != address(0)) {
            console2.log("%s contracts already deployed", getChain(block.chainid).name);
            return;
        }

        console2.log("Deploying %s contracts", getChain(block.chainid).name);
        EthereumDeploymentParams memory params = _readDeploymentParamsFromEnv();
        EthereumDeployments memory deps = _deployAll(params);

        if (vm.envOr("BROADCAST", false)) {
            _writeEthereumDeployments(deps);
            // Write JSON deployment file
            DeploymentJsonWriter.writeEthereumDeploymentsToJson(vm, block.chainid, deps);
        }

        logDeployments();
    }

    function logDeployments() public {
        EthereumDeployments memory deps = readEthereumDeployments(block.chainid);
        Eip1967Logger.logEip1967(vm, "WCT", address(deps.wct));
        console2.log("Timelock", address(deps.timelock));

        // Write JSON deployment file
        if (vm.envOr("WRITE_JSON", false)) {
            DeploymentJsonWriter.writeEthereumDeploymentsToJson(vm, block.chainid, deps);
        }
    }

    function _deployAll(EthereumDeploymentParams memory params) private returns (EthereumDeployments memory) {
        Timelock timelock = new Timelock(
            1 weeks, _singleAddressArray(params.admin), _singleAddressArray(params.admin), params.timelockCanceller
        );
        return EthereumDeployments({ wct: WCT(address(0)), timelock: timelock });
    }

    function _writeEthereumDeployments(EthereumDeployments memory deps) internal {
        _writeDeployments(abi.encode(deps));
    }

    function _readDeploymentParamsFromEnv() internal view returns (EthereumDeploymentParams memory) {
        return EthereumDeploymentParams({
            admin: vm.envAddress("ADMIN_ADDRESS"),
            timelockCanceller: vm.envAddress("TIMELOCK_CANCELLER_ADDRESS"),
            nttManager: vm.envAddress("NTT_MANAGER_ADDRESS")
        });
    }
}
