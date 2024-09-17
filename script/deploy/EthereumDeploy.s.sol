// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { WCT } from "src/WCT.sol";
import { Timelock } from "src/Timelock.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { EthereumDeployments, BaseScript } from "script/Base.s.sol";

struct EthereumDeploymentParams {
    address admin;
    address timelockCanceller;
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
        }

        // Mint initial supply to admin (1 billion WCT)
        deps.wct.mint(broadcaster, 1_000_000_000 * 1e18);
        // Send ownership to admin
        deps.wct.transferOwnership(params.admin);

        logDeployments();
    }

    function logDeployments() public {
        EthereumDeployments memory deps = readEthereumDeployments(block.chainid);
        console2.log("WCT:", address(deps.wct));
    }

    function _deployAll(EthereumDeploymentParams memory params) private returns (EthereumDeployments memory) {
        WCT wct = WCT(
            Upgrades.deployTransparentProxy(
                // We deploy with broadcaster as owner to mint initial supply and bridge it
                "WCT.sol:WCT",
                broadcaster,
                abi.encodeCall(WCT.initialize, WCT.Init({ initialOwner: broadcaster }))
            )
        );

        Timelock timelock = new Timelock(
            1 weeks, _singleAddressArray(params.admin), _singleAddressArray(params.admin), params.timelockCanceller
        );

        return EthereumDeployments({ wct: wct, timelock: timelock });
    }

    function _writeEthereumDeployments(EthereumDeployments memory deps) internal {
        _writeDeployments(abi.encode(deps));
    }

    function _readDeploymentParamsFromEnv() internal view returns (EthereumDeploymentParams memory) {
        return EthereumDeploymentParams({
            admin: vm.envAddress("ADMIN_ADDRESS"),
            timelockCanceller: vm.envAddress("TIMELOCK_CANCELLER_ADDRESS")
        });
    }
}
