// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { L2BRR } from "src/L2BRR.sol";
import { Base_Test } from "../../../../Base.t.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

contract SetAllowedTo_L2BRR_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function test_RevertWhen_CallerNotManager() external {
        vm.startPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.alice, l2brr.MANAGER_ROLE()
            )
        );
        l2brr.setAllowedTo(users.bob, true);
    }

    modifier whenCallerManager() {
        vm.startPrank(users.manager);
        _;
    }

    function test_SetAllowedTo() external whenCallerManager {
        vm.expectEmit(true, true, true, true);
        emit SetAllowedTo(users.bob, true);

        l2brr.setAllowedTo(users.bob, true);

        assertTrue(l2brr.allowedTo(users.bob));
    }
}
