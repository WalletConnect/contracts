// SPDX-License-Identifier: MIT

import { Base_Test } from "test/Base.t.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

pragma solidity >=0.8.25 <0.9.0;

contract SetAllowedTo_L2WCT_Unit_Fuzz_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function testFuzz_setAllowedTo(address to, address sender, bool allowed) public {
        vm.startPrank(sender);
        if (sender != users.manager) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IAccessControl.AccessControlUnauthorizedAccount.selector, sender, l2wct.MANAGER_ROLE()
                )
            );
            l2wct.setAllowedTo(to, allowed);
        } else {
            vm.expectEmit(true, true, true, true);
            emit SetAllowedTo(to, allowed);
            l2wct.setAllowedTo(to, allowed);
        }
    }
}
