// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Base_Test } from "test/Base.t.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

contract GrantRole_L2BRR_Unit_Concrete_Test is Base_Test {
    bytes32 internal DEFAULT_ADMIN_ROLE;
    bytes32 internal MANAGER_ROLE;

    function setUp() public override {
        super.setUp();
        deployCoreConditionally();

        DEFAULT_ADMIN_ROLE = l2brr.DEFAULT_ADMIN_ROLE();
        MANAGER_ROLE = l2brr.MANAGER_ROLE();
    }

    modifier whenGrantingDefaultAdminRole() {
        _;
    }

    function test_RevertWhen_CallerNotDefaultAdmin() external whenGrantingDefaultAdminRole {
        vm.startPrank(users.attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.attacker, DEFAULT_ADMIN_ROLE
            )
        );
        l2brr.grantRole(DEFAULT_ADMIN_ROLE, users.alice);
    }

    modifier whenGrantingManagerRole() {
        _;
    }

    function test_RevertWhen_AttackerNotDefaultAdmin() external whenGrantingManagerRole {
        vm.startPrank(users.attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.attacker, DEFAULT_ADMIN_ROLE
            )
        );
        l2brr.grantRole(MANAGER_ROLE, users.alice);
    }

    modifier whenCallerDefaultAdmin() {
        vm.startPrank(users.admin);
        _;
    }

    function test_WhenGrantingDefaultAdminRole() external whenCallerDefaultAdmin whenGrantingDefaultAdminRole {
        assertTrue(!l2brr.hasRole(DEFAULT_ADMIN_ROLE, users.alice));
        vm.expectEmit(true, true, true, true);
        emit RoleGranted(DEFAULT_ADMIN_ROLE, users.alice, users.admin);
        l2brr.grantRole(DEFAULT_ADMIN_ROLE, users.alice);
        assertTrue(l2brr.hasRole(DEFAULT_ADMIN_ROLE, users.alice));
    }

    function test_WhenGrantingDefaultAdminRoleToExistingHolder()
        external
        whenCallerDefaultAdmin
        whenGrantingDefaultAdminRole
    {
        assertTrue(l2brr.hasRole(DEFAULT_ADMIN_ROLE, users.admin));
        l2brr.grantRole(DEFAULT_ADMIN_ROLE, users.admin);
        // No state change, but should not revert
    }

    function test_WhenGrantingManagerRole() external whenCallerDefaultAdmin whenGrantingManagerRole {
        assertTrue(!l2brr.hasRole(MANAGER_ROLE, users.alice));
        vm.expectEmit(true, true, true, true);
        emit RoleGranted(MANAGER_ROLE, users.alice, users.admin);
        l2brr.grantRole(MANAGER_ROLE, users.alice);
        assertTrue(l2brr.hasRole(MANAGER_ROLE, users.alice));
    }

    function test_WhenGrantingManagerRoleToExistingHolder() external whenCallerDefaultAdmin whenGrantingManagerRole {
        assertTrue(l2brr.hasRole(MANAGER_ROLE, users.manager));
        l2brr.grantRole(MANAGER_ROLE, users.manager);
        // No state change, but should not revert
    }
}
