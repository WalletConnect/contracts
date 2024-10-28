// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { L2WCT } from "src/L2WCT.sol";
import { Base_Test } from "../../../../Base.t.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

contract SetAllowedFrom_L2WCT_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function test_RevertWhen_CallerNotManager() external {
        vm.startPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.alice, l2wct.MANAGER_ROLE()
            )
        );
        l2wct.setAllowedFrom(users.bob, true);
    }

    modifier whenCallerManager() {
        vm.prank(users.manager);
        _;
    }

    function test_SetAllowedFrom() external whenCallerManager {
        vm.expectEmit(true, true, true, true);
        emit SetAllowedFrom(users.bob, true);

        l2wct.setAllowedFrom(users.bob, true);

        assertTrue(l2wct.allowedFrom(users.bob));
    }
}
