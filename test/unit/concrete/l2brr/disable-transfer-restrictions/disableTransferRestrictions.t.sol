// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { L2BRR } from "src/L2BRR.sol";
import { Base_Test } from "../../../../Base.t.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract DisableTransferRestrictions_L2BRR_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function test_RevertWhen_CallerNotOwner() external {
        vm.prank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.alice));
        l2brr.disableTransferRestrictions();
    }

    modifier whenCallerOwner() {
        vm.startPrank(users.admin);
        _;
    }

    function test_RevertGiven_RestrictionsDisabled() external whenCallerOwner {
        l2brr.disableTransferRestrictions();

        vm.expectRevert(L2BRR.TransferRestrictionsAlreadyDisabled.selector);
        l2brr.disableTransferRestrictions();
    }

    modifier givenRestrictionsEnabled() {
        _;
    }

    function test_SetTransferRestrictionsDisabled() external whenCallerOwner givenRestrictionsEnabled {
        vm.expectEmit(true, true, true, true);
        emit TransferRestrictionsDisabled();

        l2brr.disableTransferRestrictions();

        assertEq(l2brr.transferRestrictionsDisabledAfter(), 0);
    }
}
