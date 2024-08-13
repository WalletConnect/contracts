// SPDX-License-Identifier: MIT

import { Base_Test } from "test/Base.t.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity >=0.8.25 <0.9.0;

contract SetAllowedTo_L2BRR_Unit_Fuzz_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function testFuzz_setAllowedTo(address to, address sender, bool allowed) public {
        vm.startPrank(sender);
        if (sender != l2brr.owner()) {
            vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, sender));
            l2brr.setAllowedTo(to, allowed);
        } else {
            vm.expectEmit(true, true, true, true);
            emit SetAllowedTo(to, allowed);
            l2brr.setAllowedTo(to, allowed);
        }
    }
}
