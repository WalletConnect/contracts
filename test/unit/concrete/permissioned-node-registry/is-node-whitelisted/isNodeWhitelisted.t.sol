// SPDX-License-Identifier: UNLICENSED
import { PermissionedNodeRegistry_Unit_Concrete_Test } from "../PermissionedNodeRegistry.t.sol";
import { PermissionedNodeRegistry } from "src/PermissionedNodeRegistry.sol";

pragma solidity >=0.8.25 <0.9.0;

contract IsNodeWhitelisted_PermissionedNodeRegistry_Unit_Concrete_Test is
    PermissionedNodeRegistry_Unit_Concrete_Test
{
    function test_GivenANodesIsWhitelisted() external {
        vm.prank(users.admin);
        permissionedNodeRegistry.whitelistNode(users.admin);
        assertTrue(permissionedNodeRegistry.isNodeWhitelisted(users.admin));
    }

    function test_GivenANodeIsNotWhitelisted() external view {
        assertFalse(permissionedNodeRegistry.isNodeWhitelisted(users.admin));
    }
}
