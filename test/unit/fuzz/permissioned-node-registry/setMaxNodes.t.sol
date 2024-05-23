// SPDX-License-Identifier: MIT

import { Base_Test } from "../../../Base.t.sol";
import { PermissionedNodeRegistry } from "src/PermissionedNodeRegistry.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity >=0.8.25 <0.9.0;

contract SetMaxNodes_PermissionedNodeRegistry_Unit_Fuzz_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function testFuzz_RevertWhen_CallerNotOwner(address attacker, uint8 newMaxNodes) external {
        vm.assume(attacker != address(0) && attacker != users.admin);
        assumeNotPrecompile(attacker);

        uint8 currentMaxNodes = permissionedNodeRegistry.maxNodes();
        vm.assume(newMaxNodes != currentMaxNodes);

        // Make the attacker the caller
        vm.startPrank(attacker);

        // Run the test
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        permissionedNodeRegistry.setMaxNodes(newMaxNodes);
    }

    modifier whenCallerOwner() {
        vm.startPrank(users.admin);
        _;
    }

    function testFuzz_RevertWhen_NewMaxNodesIsLTWhitelistCount(
        uint8 initialLength,
        uint8 newMaxCount
    )
        external
        whenCallerOwner
    {
        uint8 currentMaxNodes = permissionedNodeRegistry.maxNodes();
        initialLength = uint8(bound(initialLength, 1, currentMaxNodes));
        newMaxCount = uint8(bound(newMaxCount, 1, initialLength));
        vm.assume(newMaxCount < initialLength && newMaxCount != currentMaxNodes);
        for (uint8 i; i < initialLength; i++) {
            permissionedNodeRegistry.whitelistNode(address(uint160(i)));
        }
        vm.expectRevert(abi.encodeWithSelector(PermissionedNodeRegistry.WhitelistFull.selector));
        permissionedNodeRegistry.setMaxNodes(newMaxCount);
    }

    function testFuzz_WhenNewMaxNodesIsGTWhitelistCount(uint8 newMaxCount) external whenCallerOwner {
        uint8 currentMaxNodes = permissionedNodeRegistry.maxNodes();
        vm.assume(newMaxCount != currentMaxNodes);
        vm.expectEmit({ emitter: address(permissionedNodeRegistry) });
        emit MaxNodesSet({ maxNodes: newMaxCount });
        permissionedNodeRegistry.setMaxNodes(newMaxCount);
        assertEq(permissionedNodeRegistry.maxNodes(), newMaxCount);
    }
}
