// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { BRR } from "src/BRR.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { EthereumDeployments, BaseScript } from "script/Base.s.sol";

struct EthereumDeploymentParams {
    address admin;
}

contract EthereumDeploy is BaseScript {
    function run() public broadcast {
        console2.log("Deploying %s contracts", getChain(block.chainid).name);
        if (address(readEthereumDeployments(block.chainid).brr) != address(0)) {
            console2.log("%s contracts already deployed", getChain(block.chainid).name);
            return;
        }

        console2.log("Deploying %s contracts", getChain(block.chainid).name);
        EthereumDeploymentParams memory params = _readDeploymentParamsFromEnv();
        EthereumDeployments memory deps = _deployAll(params);

        if (vm.envOr("BROADCAST", false)) {
            _writeEthereumDeployments(deps);
        }

        // Mint initial supply to admin (1 billion BRR)
        deps.brr.mint(broadcaster, 1_000_000_000 * 1e18);
        // Send ownership to admin
        deps.brr.transferOwnership(params.admin);

        logDeployments();
    }

    function logDeployments() public {
        EthereumDeployments memory deps = readEthereumDeployments(block.chainid);
        console2.log("BRR:", address(deps.brr));
    }

    function _deployAll(EthereumDeploymentParams memory params) private returns (EthereumDeployments memory) {
        BRR brr = BRR(
            Upgrades.deployTransparentProxy(
                // We deploy with broadcaster as owner to mint initial supply and bridge it
                "BRR.sol:BRR",
                broadcaster,
                abi.encodeCall(BRR.initialize, BRR.Init({ initialOwner: params.admin }))
            )
        );

        return EthereumDeployments({ brr: brr });
    }

    function _writeEthereumDeployments(EthereumDeployments memory deps) internal {
        _writeDeployments(abi.encode(deps));
    }

    function _readDeploymentParamsFromEnv() internal view returns (EthereumDeploymentParams memory) {
        return EthereumDeploymentParams({ admin: vm.envAddress("ADMIN_ADDRESS") });
    }
}
