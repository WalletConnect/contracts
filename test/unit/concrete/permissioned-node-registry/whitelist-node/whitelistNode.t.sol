// SPDX-License-Identifier: MIT

import { PermissionedNodeRegistry_Unit_Concrete_Test } from "../PermissionedNodeRegistry.t.sol";
import { PermissionedNodeRegistry } from "src/PermissionedNodeRegistry.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

pragma solidity >=0.8.25 <0.9.0;

contract WhitelistNode_PermissionedNodeRegistry_Unit_Concrete_Test is PermissionedNodeRegistry_Unit_Concrete_Test {
    function test_RevertWhen_CallerNotOwner() external {
        vm.startPrank(users.attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                users.attacker,
                permissionedNodeRegistry.ADMIN_ROLE()
            )
        );
        permissionedNodeRegistry.whitelistNode(users.attacker);
    }

    modifier whenCallerOwner() {
        vm.startPrank(users.admin);
        _;
    }

    function test_RevertGiven_NodeIsAlreadyWhitelisted() external whenCallerOwner {
        permissionedNodeRegistry.whitelistNode(users.admin);
        vm.expectRevert(abi.encodeWithSelector(PermissionedNodeRegistry.NodeAlreadyWhitelisted.selector, users.admin));
        permissionedNodeRegistry.whitelistNode(users.admin);
    }

    modifier givenNodeIsNotWhitelisted() {
        assertFalse(permissionedNodeRegistry.isNodeWhitelisted(users.nonPermissionedNode));
        _;
    }

    function test_RevertGiven_WhitelistCountEqMaxNodes() external whenCallerOwner givenNodeIsNotWhitelisted {
        for (uint8 i = 0; i < permissionedNodeRegistry.maxNodes(); i++) {
            permissionedNodeRegistry.whitelistNode(address(uint160(i)));
        }
        vm.expectRevert(abi.encodeWithSelector(PermissionedNodeRegistry.WhitelistFull.selector));
        permissionedNodeRegistry.whitelistNode(users.nonPermissionedNode);
    }

    modifier givenWhitelistCountLTMaxNodes() {
        assertTrue(permissionedNodeRegistry.getWhitelistedNodesCount() < permissionedNodeRegistry.maxNodes());
        _;
    }

    function test_GivenWhitelistCountLTMaxNodes()
        external
        whenCallerOwner
        givenNodeIsNotWhitelisted
        givenWhitelistCountLTMaxNodes
    {
        uint256 initialLength = permissionedNodeRegistry.getWhitelistedNodesCount();
        vm.expectEmit({ emitter: address(permissionedNodeRegistry) });
        emit NodeWhitelisted({ node: users.admin });
        permissionedNodeRegistry.whitelistNode(users.admin);
        assertTrue(permissionedNodeRegistry.isNodeWhitelisted(users.admin));
        assertEq(permissionedNodeRegistry.getWhitelistedNodesCount(), initialLength + 1);
    }
}
