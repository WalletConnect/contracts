// SPDX-License-Identifier: UNLICENSED
import { PermissionedNodeRegistry_Unit_Concrete_Test } from "../PermissionedNodeRegistry.t.sol";
import { PermissionedNodeRegistry } from "src/PermissionedNodeRegistry.sol";

pragma solidity >=0.8.25 <0.9.0;

contract GetWhitelistedNodes_PermissionedNodeRegistry_Unit_Concrete_Test is
    PermissionedNodeRegistry_Unit_Concrete_Test
{
    function test_GivenNodesHaveBeenWhitelisted() external {
        _whitelistNodes(3);
        // it should return a list of whitelisted nodes
        address[] memory whitelistedNodes = permissionedNodeRegistry.getWhitelistedNodes();
        assertEq(whitelistedNodes.length, 3);
        assertEq(whitelistedNodes[0], address(INITIAL_NODE_UINT_160));
        assertEq(whitelistedNodes[1], address(INITIAL_NODE_UINT_160 + 1));
        assertEq(whitelistedNodes[2], address(INITIAL_NODE_UINT_160 + 2));
    }

    function test_GivenNoNodesHaveBeenWhitelisted() external view {
        // it should return an empty list
        address[] memory whitelistedNodes = permissionedNodeRegistry.getWhitelistedNodes();
        assertEq(whitelistedNodes.length, 0);
    }
}
