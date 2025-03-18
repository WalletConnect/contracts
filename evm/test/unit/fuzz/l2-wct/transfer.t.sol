// SPDX-License-Identifier: MIT

import { Base_Test } from "test/Base.t.sol";
import { L2WCT } from "src/L2WCT.sol";

pragma solidity >=0.8.25 <0.9.0;

contract Transfer_L2WCT_Unit_Fuzz_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function testFuzz_AllowedFromCanSendAnywhere(address to) public {
        vm.assume(to != address(0) && to != users.alice && to != address(mockBridge));

        vm.prank(users.manager);
        l2wct.setAllowedFrom(users.alice, true);

        deal(address(l2wct), users.alice, 1000);

        vm.prank(users.alice);
        l2wct.transfer(to, 500);

        assertEq(l2wct.balanceOf(to), 500);
    }

    function testFuzz_NotAllowedFromCannotSendIfNoAllowedTos(
        address from,
        address to
    )
        public
        notFromProxyAdmin(from, address(l2wct))
    {
        vm.assume(from != address(0) && from != users.alice && from != address(mockBridge));
        vm.assume(to != address(0) && to != users.alice && to != address(mockBridge));
        vm.assume(from != to);

        deal(address(l2wct), from, 1000);

        vm.prank(from);
        vm.expectRevert(L2WCT.TransferRestricted.selector);
        l2wct.transfer(to, 500);
    }

    function testFuzz_DisableTransferRestrictions(
        address from,
        address to
    )
        public
        notFromProxyAdmin(from, address(l2wct))
    {
        vm.assume(from != address(0) && from != users.alice && from != address(mockBridge));
        vm.assume(to != address(0) && to != users.alice && to != address(mockBridge));
        vm.assume(from != to);

        deal(address(l2wct), from, 1000);

        vm.prank(from);
        vm.expectRevert(L2WCT.TransferRestricted.selector);
        l2wct.transfer(to, 500);

        assertEq(l2wct.transferRestrictionsDisabledAfter(), type(uint256).max, "invalid test setup");

        vm.prank(users.admin);
        vm.expectEmit(true, true, true, true);
        emit TransferRestrictionsDisabled();
        l2wct.disableTransferRestrictions();

        assertEq(l2wct.transferRestrictionsDisabledAfter(), 0, "transfer restrictions were not disabled correctly");

        vm.prank(from);
        l2wct.transfer(to, 500);

        assertEq(l2wct.balanceOf(to), 500);
    }
}
