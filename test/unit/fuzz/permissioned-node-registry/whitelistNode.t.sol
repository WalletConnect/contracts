// SPDX-License-Identifier: MIT
import { Base_Test } from "../../../Base.t.sol";
import { PermissionedNodeRegistry } from "src/PermissionedNodeRegistry.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity >=0.8.25 <0.9.0;

contract WhitelistNode_PermissionedNodeRegistry_Unit_Fuzz_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function testFuzz_RevertWhen_CallerNotOwner(address attacker) external {
        vm.assume(attacker != address(0) && attacker != users.admin);
        assumeNotPrecompile(attacker);

        // Make the attacker the caller
        vm.startPrank(attacker);

        // Run the test
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        permissionedNodeRegistry.whitelistNode(attacker);
    }

    modifier whenCallerOwner() {
        vm.startPrank(users.admin);
        _;
    }

    function testFuzz_RevertGiven_NodeIsAlreadyWhitelisted(address nodeToWhitelist) external whenCallerOwner {
        uint256 initialLength = permissionedNodeRegistry.getWhitelistedNodesCount();
        vm.expectEmit({ emitter: address(permissionedNodeRegistry) });
        emit NodeWhitelisted({ node: nodeToWhitelist });
        permissionedNodeRegistry.whitelistNode(nodeToWhitelist);
        assertTrue(permissionedNodeRegistry.isNodeWhitelisted(nodeToWhitelist));
        assertEq(permissionedNodeRegistry.getWhitelistedNodesCount(), initialLength + 1);
    }
}
