// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { L2BRR } from "src/L2BRR.sol";
import { Base_Test } from "../../../../Base.t.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract SetAllowedFrom_L2BRR_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function test_RevertWhen_CallerNotOwner() external {
        vm.prank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.alice));
        l2brr.setAllowedFrom(users.bob, true);
    }

    modifier whenCallerOwner() {
        vm.prank(users.admin);
        _;
    }

    function test_SetAllowedFrom() external whenCallerOwner {
        vm.expectEmit(true, true, true, true);
        emit SetAllowedFrom(users.bob, true);

        l2brr.setAllowedFrom(users.bob, true);

        assertTrue(l2brr.allowedFrom(users.bob));
    }
}
