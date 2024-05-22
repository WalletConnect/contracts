// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

import { BRR } from "src/BRR.sol";
import { Defaults } from "test/utils/Defaults.sol";
import { console2 } from "forge-std/console2.sol";
import { BaseScript, Deployments } from "./Base.s.sol";

contract NodeOperatorsSetup is BaseScript {
    /**
     * @dev This script mints BRR tokens for the node operators. It is useful for setting up
     *      without the need to manually interact with the contract.
     */
    function run() external {
        // 1. Setup
        Defaults defaults = new Defaults();
        uint8 nodeOperatorsLength = 3;
        uint32 initialMnemonicIndexForNodeOperators = lastReservedMnemonicIndex + 1;
        address[] memory nodeOperators = new address[](nodeOperatorsLength);
        for (uint256 i; i < nodeOperatorsLength; i++) {
            address nodeOperatorAddress =
                vm.addr(vm.deriveKey(mnemonic, initialMnemonicIndexForNodeOperators + uint32(i)));
            vm.label(nodeOperatorAddress, string(abi.encodePacked("nodeOperator", i)));
            nodeOperators[i] = nodeOperatorAddress;
        }
        Deployments memory deployments = readDeployments();
        // 2. Broadcast
        vm.startBroadcast(broadcaster);
        for (uint256 i; i < nodeOperatorsLength; i++) {
            console2.log("Minting BRR for ", vm.getLabel(nodeOperators[i]), " at address ", nodeOperators[i]);
            deployments.brr.mint(nodeOperators[i], defaults.MIN_STAKE());
            deployments.registry.whitelistNode(nodeOperators[i]);
        }
        vm.stopBroadcast();
    }
}
