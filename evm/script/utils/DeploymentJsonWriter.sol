// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { EthereumDeployments, OptimismDeployments } from "script/Base.s.sol";
import { Eip1967Logger } from "script/utils/Eip1967Logger.sol";

/**
 * @title DeploymentJsonWriter
 * @notice Utility library for writing deployment information to JSON files
 */
library DeploymentJsonWriter {
    /**
     * @notice Writes Ethereum deployment information to a JSON file
     * @param vm The Forge VM instance
     * @param chainId The chain ID
     * @param deps The Ethereum deployments
     */
    function writeEthereumDeploymentsToJson(VmSafe vm, uint256 chainId, EthereumDeployments memory deps) internal {
        string memory json = "{}";

        // Add chain ID
        json = stdJson.serialize("json", "chainId", chainId);

        // Add WCT information
        if (address(deps.wct) != address(0)) {
            address implementation = Eip1967Logger.getImplementation(vm, address(deps.wct));
            address admin = Eip1967Logger.getAdmin(vm, address(deps.wct));

            // Create nested WCT object
            string memory wctJson = "{}";
            wctJson = stdJson.serialize("wctJson", "address", address(deps.wct));
            wctJson = stdJson.serialize("wctJson", "implementation", implementation);
            wctJson = stdJson.serialize("wctJson", "admin", admin);

            // Add WCT object to main JSON
            json = stdJson.serialize("json", "WCT", wctJson);
        }

        // Add Timelock information
        if (address(deps.timelock) != address(0)) {
            // Create nested Timelock object
            string memory timelockJson = "{}";
            timelockJson = stdJson.serialize("timelockJson", "address", address(deps.timelock));

            // Add Timelock object to main JSON
            json = stdJson.serialize("json", "Timelock", timelockJson);
        }

        // Write to file
        string memory deploymentsPath = string.concat(vm.projectRoot(), "/deployments/");
        vm.createDir(deploymentsPath, true);
        string memory filePath = string.concat(deploymentsPath, vm.toString(chainId), ".json");
        vm.writeFile(filePath, json);

        console2.log("Ethereum deployments written to %s", filePath);
    }

    /**
     * @notice Writes Optimism deployment information to a JSON file
     * @param vm The Forge VM instance
     * @param chainId The chain ID
     * @param deps The Optimism deployments
     */
    function writeOptimismDeploymentsToJson(VmSafe vm, uint256 chainId, OptimismDeployments memory deps) internal {
        string memory json = "{}";

        // Add chain ID
        json = stdJson.serialize("json", "chainId", chainId);

        // Add proxy contracts
        json = _addProxyContractToJsonNested(vm, json, "L2WCT", address(deps.l2wct));
        json = _addProxyContractToJsonNested(vm, json, "WalletConnectConfig", address(deps.config));
        json = _addProxyContractToJsonNested(vm, json, "Pauser", address(deps.pauser));
        json = _addProxyContractToJsonNested(vm, json, "StakeWeight", address(deps.stakeWeight));
        json =
            _addProxyContractToJsonNested(vm, json, "StakingRewardDistributor", address(deps.stakingRewardDistributor));

        // Add Timelock information
        if (address(deps.adminTimelock) != address(0)) {
            string memory timelockJson = "{}";
            timelockJson = stdJson.serialize("timelockJson", "address", address(deps.adminTimelock));
            json = stdJson.serialize("json", "AdminTimelock", timelockJson);
        }

        if (address(deps.managerTimelock) != address(0)) {
            string memory timelockJson = "{}";
            timelockJson = stdJson.serialize("timelockJson", "address", address(deps.managerTimelock));
            json = stdJson.serialize("json", "ManagerTimelock", timelockJson);
        }

        // Add Airdrop information
        if (address(deps.airdrop) != address(0)) {
            string memory airdropJson = "{}";
            airdropJson = stdJson.serialize("airdropJson", "address", address(deps.airdrop));
            json = stdJson.serialize("json", "Airdrop", airdropJson);
        }

        // Add MerkleVester information
        if (address(deps.merkleVesterReown) != address(0)) {
            string memory vesterJson = "{}";
            vesterJson = stdJson.serialize("vesterJson", "address", address(deps.merkleVesterReown));
            json = stdJson.serialize("json", "MerkleVesterReown", vesterJson);
        }

        if (address(deps.merkleVesterWalletConnect) != address(0)) {
            string memory vesterJson = "{}";
            vesterJson = stdJson.serialize("vesterJson", "address", address(deps.merkleVesterWalletConnect));
            json = stdJson.serialize("json", "MerkleVesterWalletConnect", vesterJson);
        }

        if (address(deps.merkleVesterBackers) != address(0)) {
            string memory vesterJson = "{}";
            vesterJson = stdJson.serialize("vesterJson", "address", address(deps.merkleVesterBackers));
            json = stdJson.serialize("json", "MerkleVesterBackers", vesterJson);
        }

        // Add LockedTokenStaker information
        if (address(deps.lockedTokenStakerReown) != address(0)) {
            string memory stakerJson = "{}";
            stakerJson = stdJson.serialize("stakerJson", "address", address(deps.lockedTokenStakerReown));
            json = stdJson.serialize("json", "LockedTokenStakerReown", stakerJson);
        }

        if (address(deps.lockedTokenStakerWalletConnect) != address(0)) {
            string memory stakerJson = "{}";
            stakerJson = stdJson.serialize("stakerJson", "address", address(deps.lockedTokenStakerWalletConnect));
            json = stdJson.serialize("json", "LockedTokenStakerWalletConnect", stakerJson);
        }

        if (address(deps.lockedTokenStakerBackers) != address(0)) {
            string memory stakerJson = "{}";
            stakerJson = stdJson.serialize("stakerJson", "address", address(deps.lockedTokenStakerBackers));
            json = stdJson.serialize("json", "LockedTokenStakerBackers", stakerJson);
        }

        // Add StakingRewardsCalculator information
        if (address(deps.stakingRewardsCalculator) != address(0)) {
            string memory calculatorJson = "{}";
            calculatorJson = stdJson.serialize("calculatorJson", "address", address(deps.stakingRewardsCalculator));
            json = stdJson.serialize("json", "StakingRewardsCalculator", calculatorJson);
        }

        // Write to file
        string memory deploymentsPath = string.concat(vm.projectRoot(), "/deployments/");
        vm.createDir(deploymentsPath, true);
        string memory filePath = string.concat(deploymentsPath, vm.toString(chainId), ".json");
        vm.writeFile(filePath, json);

        console2.log("Optimism deployments written to %s", filePath);
    }

    /**
     * @notice Helper function to add proxy contract information to JSON with proper nesting
     * @param vm The Forge VM instance
     * @param json The JSON string
     * @param name The contract name
     * @param proxyAddress The proxy address
     * @return The updated JSON string
     */
    function _addProxyContractToJsonNested(
        VmSafe vm,
        string memory json,
        string memory name,
        address proxyAddress
    )
        private
        returns (string memory)
    {
        if (proxyAddress != address(0)) {
            address implementation = Eip1967Logger.getImplementation(vm, address(proxyAddress));
            address admin = Eip1967Logger.getAdmin(vm, address(proxyAddress));

            // Create a nested JSON object for this contract
            string memory contractJson = "{}";
            string memory jsonKey = string.concat(name, "Json");

            contractJson = stdJson.serialize(jsonKey, "address", proxyAddress);
            contractJson = stdJson.serialize(jsonKey, "implementation", implementation);
            contractJson = stdJson.serialize(jsonKey, "admin", admin);

            // Add the nested object to the main JSON
            json = stdJson.serialize("json", name, contractJson);
        }
        return json;
    }
}
