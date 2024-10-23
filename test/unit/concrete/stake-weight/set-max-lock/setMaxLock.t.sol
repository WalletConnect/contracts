// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakeWeight } from "src/StakeWeight.sol";
import { Base_Test } from "test/Base.t.sol";

contract SetMaxLock_StakeWeight_Unit_Concrete_Test is Base_Test {
    address public admin;
    address public nonAdmin;
    uint256 public currentMaxLock;
    uint256 public newMaxLock;

    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
        admin = users.admin;
        nonAdmin = users.bob;
        currentMaxLock = stakeWeight.maxLock();
        newMaxLock = currentMaxLock + 1 weeks;
    }

    function test_WhenCallerIsNotAdmin() public {
        bytes32 role = stakeWeight.DEFAULT_ADMIN_ROLE();
        vm.prank(nonAdmin);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", nonAdmin, role));
        stakeWeight.setMaxLock(newMaxLock);
    }

    function test_WhenNewMaxLockIsGreaterThan209Weeks() public {
        uint256 invalidMaxLock = 209 weeks;
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidMaxLock(uint256)", invalidMaxLock));
        stakeWeight.setMaxLock(invalidMaxLock);
    }

    function test_WhenNewMaxLockIsLessThanCurrentMaxLock() public {
        uint256 invalidMaxLock = currentMaxLock - 1 weeks;
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidMaxLock(uint256)", invalidMaxLock));
        stakeWeight.setMaxLock(invalidMaxLock);
    }

    function test_WhenNewMaxLockIsValid() public {
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit MaxLockUpdated(currentMaxLock, newMaxLock);
        stakeWeight.setMaxLock(newMaxLock);

        assertEq(stakeWeight.maxLock(), newMaxLock, "It should set the new maxLock value");
    }
}
