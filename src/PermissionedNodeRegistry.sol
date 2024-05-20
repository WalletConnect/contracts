// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.25;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract PermissionedNodeRegistry is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    // errors
    error NodeNotWhitelisted(address node);
    error NodeAlreadyWhitelisted(address node);

    // events
    event NodeWhitelisted(address indexed node);
    event NodeRemovedFromWhitelist(address indexed node);

    EnumerableSet.AddressSet private stakingAllowlist; // set of nodes to iterate over

    constructor(address initialOwner) Ownable(initialOwner) { }

    function whitelistNode(address node) external onlyOwner {
        if (stakingAllowlist.contains(node)) {
            revert NodeAlreadyWhitelisted(node);
        }
        stakingAllowlist.add(node);
        emit NodeWhitelisted(node);
    }

    function removeNodeFromWhitelist(address node) external onlyOwner {
        if (!stakingAllowlist.contains(node)) {
            revert NodeNotWhitelisted(node);
        }
        stakingAllowlist.remove(node);
        emit NodeRemovedFromWhitelist(node);
    }

    function isNodeWhitelisted(address node) external view returns (bool) {
        return stakingAllowlist.contains(node);
    }

    function getWhitelistedNodes() external view returns (address[] memory) {
        address[] memory nodes = new address[](stakingAllowlist.length());
        for (uint256 i = 0; i < stakingAllowlist.length(); i++) {
            nodes[i] = stakingAllowlist.at(i);
        }
        return nodes;
    }

    function getWhitelistedNodesCount() external view returns (uint256) {
        return stakingAllowlist.length();
    }

    function getWhitelistedNodeAtIndex(uint256 index) external view returns (address) {
        return stakingAllowlist.at(index);
    }
}
