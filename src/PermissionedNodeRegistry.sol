// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title PermissionedNodeRegistry
/// @notice Contract for managing a whitelist of permissioned nodes
/// @author BakersSyndicate
contract PermissionedNodeRegistry is AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Error thrown when attempting to interact with a non-whitelisted node
    error NodeNotWhitelisted(address node);

    /// @notice Error thrown when attempting to whitelist an already whitelisted node
    error NodeAlreadyWhitelisted(address node);

    /// @notice Error thrown when the whitelist is full
    error WhitelistFull();

    /// @notice Error thrown when attempting to set an unchanged state
    error UnchangedState();

    /// @notice Emitted when a node is whitelisted
    /// @param node The address of the whitelisted node
    event NodeWhitelisted(address indexed node);

    /// @notice Emitted when a node is removed from the whitelist
    /// @param node The address of the removed node
    event NodeRemovedFromWhitelist(address indexed node);

    /// @notice Emitted when the maximum number of nodes is set
    /// @param maxNodes The new maximum number of nodes
    event MaxNodesSet(uint8 maxNodes);

    /// @notice Role for administrative actions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Maximum number of nodes allowed in the whitelist
    uint8 public maxNodes;

    /// @notice Set of whitelisted node addresses
    EnumerableSet.AddressSet private _stakingAllowlist;

    /// @notice Initializes the contract
    /// @param initialAdmin The address of the initial admin
    /// @param maxNodes_ The initial maximum number of nodes
    constructor(address initialAdmin, uint8 maxNodes_) {
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(ADMIN_ROLE, initialAdmin);
        maxNodes = maxNodes_;
    }

    /// @notice Whitelists a node
    /// @param node The address of the node to whitelist
    function whitelistNode(address node) external onlyRole(ADMIN_ROLE) {
        if (_stakingAllowlist.length() == maxNodes) {
            revert WhitelistFull();
        }
        if (_stakingAllowlist.contains(node)) {
            revert NodeAlreadyWhitelisted({ node: node });
        }
        _stakingAllowlist.add(node);
        emit NodeWhitelisted({ node: node });
    }

    /// @notice Removes a node from the whitelist
    /// @param node The address of the node to remove
    function removeNodeFromWhitelist(address node) external onlyRole(ADMIN_ROLE) {
        if (!_stakingAllowlist.contains(node)) {
            revert NodeNotWhitelisted({ node: node });
        }
        _stakingAllowlist.remove(node);
        emit NodeRemovedFromWhitelist({ node: node });
    }

    /// @notice Checks if a node is whitelisted
    /// @param node The address of the node to check
    /// @return True if the node is whitelisted, false otherwise
    function isNodeWhitelisted(address node) external view returns (bool) {
        return _stakingAllowlist.contains(node);
    }

    /// @notice Gets all whitelisted nodes
    /// @return An array of whitelisted node addresses
    function getWhitelistedNodes() external view returns (address[] memory) {
        return _stakingAllowlist.values();
    }

    /// @notice Gets the count of whitelisted nodes
    /// @return The number of whitelisted nodes
    function getWhitelistedNodesCount() external view returns (uint256) {
        return _stakingAllowlist.length();
    }

    /// @notice Gets a whitelisted node at a specific index
    /// @param index The index of the node in the whitelist
    /// @return The address of the node at the given index
    function getWhitelistedNodeAtIndex(uint256 index) external view returns (address) {
        return _stakingAllowlist.at(index);
    }

    /// @notice Sets the maximum number of nodes allowed in the whitelist
    /// @param maxNodes_ The new maximum number of nodes
    function setMaxNodes(uint8 maxNodes_) external onlyRole(ADMIN_ROLE) {
        if (maxNodes == maxNodes_) {
            revert UnchangedState();
        }
        if (maxNodes_ < _stakingAllowlist.length()) {
            revert WhitelistFull();
        }
        maxNodes = maxNodes_;
        emit MaxNodesSet({ maxNodes: maxNodes_ });
    }
}
