// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Base_Test } from "../../../Base.t.sol";

contract PermissionedNodeRegistry_Unit_Concrete_Test is Base_Test {
    uint160 constant INITIAL_NODE_UINT_160 = 123;

    function setUp() public virtual override {
        Base_Test.setUp();
        deployCoreConditionally();
    }

    function _whitelistNodes(uint256 amount) internal {
        vm.startPrank(users.admin);
        for (uint160 i = 0; i < amount; i++) {
            permissionedNodeRegistry.whitelistNode(address(INITIAL_NODE_UINT_160 + i));
        }
        vm.stopPrank();
    }
}
