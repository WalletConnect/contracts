// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { L2WCT } from "src/L2WCT.sol";
import { Base_Test } from "../../../../Base.t.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

contract DisableTransferRestrictions_L2WCT_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function test_RevertWhen_CallerNotAdmin() external {
        vm.startPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.alice, l2wct.DEFAULT_ADMIN_ROLE()
            )
        );
        l2wct.disableTransferRestrictions();
    }

    modifier whenCallerAdmin() {
        vm.startPrank(users.admin);
        _;
    }

    function test_RevertGiven_RestrictionsDisabled() external whenCallerAdmin {
        l2wct.disableTransferRestrictions();

        vm.expectRevert(L2WCT.TransferRestrictionsAlreadyDisabled.selector);
        l2wct.disableTransferRestrictions();
    }

    modifier givenRestrictionsEnabled() {
        _;
    }

    function test_SetTransferRestrictionsDisabled() external whenCallerAdmin givenRestrictionsEnabled {
        vm.expectEmit(true, true, true, true);
        emit TransferRestrictionsDisabled();

        l2wct.disableTransferRestrictions();

        assertEq(l2wct.transferRestrictionsDisabledAfter(), 0);
    }
}
