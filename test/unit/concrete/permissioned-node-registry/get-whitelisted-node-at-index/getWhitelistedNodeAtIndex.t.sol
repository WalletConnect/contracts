// SPDX-License-Identifier: MIT
import { PermissionedNodeRegistry_Unit_Concrete_Test } from "../PermissionedNodeRegistry.t.sol";
import { PermissionedNodeRegistry } from "src/PermissionedNodeRegistry.sol";

pragma solidity >=0.8.25 <0.9.0;

contract GetWhitelistedNodeAtIndex_PermissionedNodeRegistry_Unit_Concrete_Test is
    PermissionedNodeRegistry_Unit_Concrete_Test
{
    function test_GivenThereIsANodeAtASpecificIndex() external {
        _whitelistNodes(3);
        // it should return the node at the specified index
        address whitelistedNode = permissionedNodeRegistry.getWhitelistedNodeAtIndex(1);
        assertEq(whitelistedNode, address(INITIAL_NODE_UINT_160 + 1));
    }

    function test_RevertGiven_ThereIsNoNodeAtASpecificIndex() external {
        // it should revert with panic: array out-of-bounds access (0x32)
        vm.expectRevert();
        permissionedNodeRegistry.getWhitelistedNodeAtIndex(0);
    }
}
