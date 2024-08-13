// SPDX-License-Identifier: MIT

import { Base_Test } from "test/Base.t.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity >=0.8.25 <0.9.0;

contract SetAllowedFrom_L2BRR_Unit_Fuzz_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function testFuzz_setAllowedFrom(address from, address sender, bool allowed) public {
        vm.startPrank(sender);
        if (sender != l2brr.owner()) {
            vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, sender));
            l2brr.setAllowedFrom(from, allowed);
        } else {
            vm.expectEmit(true, true, true, true);
            emit SetAllowedFrom(from, allowed);
            l2brr.setAllowedFrom(from, allowed);
        }
    }
}
