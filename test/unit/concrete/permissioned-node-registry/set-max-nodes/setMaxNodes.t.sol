// SPDX-License-Identifier: MIT

import { PermissionedNodeRegistry } from "src/PermissionedNodeRegistry.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { PermissionedNodeRegistry_Unit_Concrete_Test } from "../PermissionedNodeRegistry.t.sol";

pragma solidity >=0.8.25 <0.9.0;

contract SetMaxNodes_PermissionedNodeRegistry_Unit_Concrete_Test is PermissionedNodeRegistry_Unit_Concrete_Test {
    function test_RevertWhen_CallerNotOwner() external {
        // Make the attacker the caller
        vm.startPrank(users.attacker);

        // Run the test
        uint8 newMaxCount = permissionedNodeRegistry.maxNodes() + 1;
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.attacker));
        permissionedNodeRegistry.setMaxNodes(newMaxCount);
    }

    modifier whenCallerOwner() {
        vm.startPrank(users.admin);
        _;
    }

    function test_RevertWhen_NewMaxNodesIsLTWhitelistCount() external whenCallerOwner {
        uint8 currentMaxNodes = permissionedNodeRegistry.maxNodes();
        for (uint8 i; i < currentMaxNodes; i++) {
            permissionedNodeRegistry.whitelistNode(address(uint160(i)));
        }
        uint8 newMaxCount = currentMaxNodes - 1;
        vm.expectRevert(abi.encodeWithSelector(PermissionedNodeRegistry.WhitelistFull.selector));
        permissionedNodeRegistry.setMaxNodes(newMaxCount);
    }

    function test_RevertWhen_NewMaxNodesEqCurrentMaxNodes() external whenCallerOwner {
        uint8 currentMaxNodes = permissionedNodeRegistry.maxNodes();
        vm.expectRevert(abi.encodeWithSelector(PermissionedNodeRegistry.UnchangedState.selector));
        permissionedNodeRegistry.setMaxNodes(currentMaxNodes);
    }

    function test_WhenNewMaxNodesIsGTWhitelistCount() external whenCallerOwner {
        uint8 currentMaxNodes = permissionedNodeRegistry.maxNodes();
        vm.expectEmit({ emitter: address(permissionedNodeRegistry) });
        uint8 newMaxCount = currentMaxNodes + 1;
        emit MaxNodesSet({ maxNodes: newMaxCount });
        permissionedNodeRegistry.setMaxNodes(newMaxCount);
        assertEq(permissionedNodeRegistry.maxNodes(), newMaxCount);
    }
}
