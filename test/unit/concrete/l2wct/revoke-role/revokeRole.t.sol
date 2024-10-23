// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Base_Test } from "test/Base.t.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

contract RevokeRole_L2WCT_Unit_Concrete_Test is Base_Test {
    bytes32 internal DEFAULT_ADMIN_ROLE;
    bytes32 internal MANAGER_ROLE;

    function setUp() public override {
        super.setUp();
        deployCoreConditionally();

        DEFAULT_ADMIN_ROLE = l2wct.DEFAULT_ADMIN_ROLE();
        MANAGER_ROLE = l2wct.MANAGER_ROLE();
    }

    modifier whenRevokingDefaultAdminRole() {
        _;
    }

    function test_RevertWhen_CallerNotDefaultAdmin() external whenRevokingDefaultAdminRole {
        vm.startPrank(users.attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.attacker, DEFAULT_ADMIN_ROLE
            )
        );
        l2wct.revokeRole(DEFAULT_ADMIN_ROLE, users.admin);
    }

    modifier whenRevokingManagerRole() {
        _;
    }

    function test_RevertWhen_AttackerNotDefaultAdmin() external whenRevokingManagerRole {
        vm.startPrank(users.attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.attacker, DEFAULT_ADMIN_ROLE
            )
        );
        l2wct.revokeRole(MANAGER_ROLE, users.manager);
    }

    modifier whenCallerDefaultAdmin() {
        vm.startPrank(users.admin);
        _;
    }

    function test_WhenRevokingDefaultAdminRole() external whenCallerDefaultAdmin whenRevokingDefaultAdminRole {
        assertTrue(l2wct.hasRole(DEFAULT_ADMIN_ROLE, users.admin));
        vm.expectEmit(true, true, true, true);
        emit RoleRevoked(DEFAULT_ADMIN_ROLE, users.admin, users.admin);
        l2wct.revokeRole(DEFAULT_ADMIN_ROLE, users.admin);
        assertFalse(l2wct.hasRole(DEFAULT_ADMIN_ROLE, users.admin));
    }

    function test_WhenRevokingDefaultAdminRoleFromNonHolder()
        external
        whenCallerDefaultAdmin
        whenRevokingDefaultAdminRole
    {
        assertTrue(!l2wct.hasRole(DEFAULT_ADMIN_ROLE, users.attacker));
        l2wct.revokeRole(DEFAULT_ADMIN_ROLE, users.attacker);
        // No state change, but should not revert
    }

    function test_WhenRevokingManagerRole() external whenCallerDefaultAdmin whenRevokingManagerRole {
        assertTrue(l2wct.hasRole(MANAGER_ROLE, users.manager));
        vm.expectEmit(true, true, true, true);
        emit RoleRevoked(MANAGER_ROLE, users.manager, users.admin);
        l2wct.revokeRole(MANAGER_ROLE, users.manager);
        assertFalse(l2wct.hasRole(MANAGER_ROLE, users.manager));
    }

    function test_WhenRevokingManagerRoleFromNonHolder() external whenCallerDefaultAdmin whenRevokingManagerRole {
        assertTrue(!l2wct.hasRole(MANAGER_ROLE, users.attacker));
        l2wct.revokeRole(MANAGER_ROLE, users.attacker);
        // No state change, but should not revert
    }
}
