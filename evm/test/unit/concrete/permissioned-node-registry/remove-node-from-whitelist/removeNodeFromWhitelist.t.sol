// SPDX-License-Identifier: MIT
import { PermissionedNodeRegistry_Unit_Concrete_Test } from "../PermissionedNodeRegistry.t.sol";
import { PermissionedNodeRegistry } from "src/PermissionedNodeRegistry.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

pragma solidity >=0.8.25 <0.9.0;

contract RemoveNodeFromWhitelist_PermissionedNodeRegistry_Unit_Concrete_Test is
    PermissionedNodeRegistry_Unit_Concrete_Test
{
    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        vm.startPrank(users.attacker);
        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                users.attacker,
                permissionedNodeRegistry.ADMIN_ROLE()
            )
        );
        permissionedNodeRegistry.removeNodeFromWhitelist(users.admin);
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(users.admin);
        _;
    }

    function test_RevertGiven_TheNodeIsNotInTheWhitelist() external whenTheCallerIsTheOwner {
        // it should revert
        vm.expectRevert(abi.encodeWithSelector(PermissionedNodeRegistry.NodeNotWhitelisted.selector, users.admin));
        permissionedNodeRegistry.removeNodeFromWhitelist({ node: users.admin });
    }

    function test_GivenTheNodeIsInTheWhitelist() external whenTheCallerIsTheOwner {
        // setup the state
        permissionedNodeRegistry.whitelistNode(users.admin);
        uint256 initialLength = permissionedNodeRegistry.getWhitelistedNodesCount();
        assertTrue(permissionedNodeRegistry.isNodeWhitelisted(users.admin));
        // it should emit a NodeRemoved event
        vm.expectEmit({ emitter: address(permissionedNodeRegistry) });
        emit NodeRemovedFromWhitelist({ node: users.admin });
        // it should remove the node from the whitelist
        permissionedNodeRegistry.removeNodeFromWhitelist(users.admin);
        assertFalse(permissionedNodeRegistry.isNodeWhitelisted(users.admin));
        // it should decrement the node count
        assertEq(permissionedNodeRegistry.getWhitelistedNodesCount(), initialLength - 1);
    }
}
