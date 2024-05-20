// SPDX-License-Identifier: UNLICENSED

import { PermissionedNodeRegistry_Unit_Concrete_Test } from "../PermissionedNodeRegistry.t.sol";
import { PermissionedNodeRegistry } from "src/PermissionedNodeRegistry.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity >=0.8.25 <0.9.0;

contract WhitelistNode_PermissionedNodeRegistry_Unit_Concrete_Test is PermissionedNodeRegistry_Unit_Concrete_Test {
    function test_RevertWhen_CallerNotOwner() external {
        vm.startPrank(users.attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.attacker));
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

    function test_GivenTheNodeIsNotWhitelisted() external whenCallerOwner {
        uint256 initialLength = permissionedNodeRegistry.getWhitelistedNodesCount();
        vm.expectEmit({ emitter: address(permissionedNodeRegistry) });
        emit NodeWhitelisted({ node: users.admin });
        permissionedNodeRegistry.whitelistNode(users.admin);
        assertTrue(permissionedNodeRegistry.isNodeWhitelisted(users.admin));
        assertEq(permissionedNodeRegistry.getWhitelistedNodesCount(), initialLength + 1);
    }
}
