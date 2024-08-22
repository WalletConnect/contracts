// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { L2CNKT } from "src/L2CNKT.sol";
import { Base_Test } from "../../../../Base.t.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

contract DisableTransferRestrictions_L2CNKT_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function test_RevertWhen_CallerNotAdmin() external {
        vm.startPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.alice, l2cnkt.DEFAULT_ADMIN_ROLE()
            )
        );
        l2cnkt.disableTransferRestrictions();
    }

    modifier whenCallerAdmin() {
        vm.startPrank(users.admin);
        _;
    }

    function test_RevertGiven_RestrictionsDisabled() external whenCallerAdmin {
        l2cnkt.disableTransferRestrictions();

        vm.expectRevert(L2CNKT.TransferRestrictionsAlreadyDisabled.selector);
        l2cnkt.disableTransferRestrictions();
    }

    modifier givenRestrictionsEnabled() {
        _;
    }

    function test_SetTransferRestrictionsDisabled() external whenCallerAdmin givenRestrictionsEnabled {
        vm.expectEmit(true, true, true, true);
        emit TransferRestrictionsDisabled();

        l2cnkt.disableTransferRestrictions();

        assertEq(l2cnkt.transferRestrictionsDisabledAfter(), 0);
    }
}
