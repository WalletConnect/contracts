// SPDX-License-Identifier: MIT

import { Base_Test } from "test/Base.t.sol";
import { L2BRR } from "src/L2BRR.sol";

pragma solidity >=0.8.25 <0.9.0;

contract Transfer_L2BRR_Unit_Fuzz_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function testFuzz_AllowedFromCanSendAnywhere(address to) public {
        vm.assume(to != address(0) && to != users.alice && to != address(mockBridge));

        vm.prank(users.manager);
        l2brr.setAllowedFrom(users.alice, true);

        vm.prank(address(mockBridge));
        l2brr.mint(users.alice, 1000);

        vm.prank(users.alice);
        l2brr.transfer(to, 500);

        assertEq(l2brr.balanceOf(to), 500);
    }

    function testFuzz_NotAllowedFromCannotSendIfNoAllowedTos(address from, address to) public {
        vm.assume(from != address(0) && from != users.alice && from != address(mockBridge));
        vm.assume(to != address(0) && to != users.alice && to != address(mockBridge));
        vm.assume(from != to);

        vm.prank(address(mockBridge));
        l2brr.mint(from, 1000);

        vm.prank(from);
        vm.expectRevert(L2BRR.TransferRestricted.selector);
        l2brr.transfer(to, 500);
    }

    function testFuzz_DisableTransferRestrictions(address from, address to) public {
        vm.assume(from != address(0) && from != users.alice && from != address(mockBridge));
        vm.assume(to != address(0) && to != users.alice && to != address(mockBridge));
        vm.assume(from != to);

        vm.prank(address(mockBridge));
        l2brr.mint(from, 1000);

        vm.prank(from);
        vm.expectRevert(L2BRR.TransferRestricted.selector);
        l2brr.transfer(to, 500);

        assertEq(l2brr.transferRestrictionsDisabledAfter(), type(uint256).max, "invalid test setup");

        vm.prank(users.admin);
        vm.expectEmit(true, true, true, true);
        emit TransferRestrictionsDisabled();
        l2brr.disableTransferRestrictions();

        assertEq(l2brr.transferRestrictionsDisabledAfter(), 0, "transfer restrictions were not disabled correctly");

        vm.prank(from);
        l2brr.transfer(to, 500);

        assertEq(l2brr.balanceOf(to), 500);
    }
}
