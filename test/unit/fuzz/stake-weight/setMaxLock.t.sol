// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakeWeight_Concrete_Test } from "test/unit/concrete/stake-weight/StakeWeight.t.sol";

contract SetMaxLock_StakeWeight_Unit_Fuzz_Test is StakeWeight_Concrete_Test {
    uint256 constant MAX_LOCK = 209 weeks - 1;

    function setUp() public override {
        super.setUp();
    }

    function testFuzz_SetMaxLock(uint256 newMaxLock) public {
        uint256 currentMaxLock = stakeWeight.maxLock();
        newMaxLock = bound(newMaxLock, currentMaxLock, MAX_LOCK);

        vm.prank(users.admin);
        vm.expectEmit(true, true, true, true);
        emit MaxLockUpdated(currentMaxLock, newMaxLock);
        stakeWeight.setMaxLock(newMaxLock);

        assertEq(stakeWeight.maxLock(), newMaxLock, "It should set the new maxLock value");
    }

    function testFuzz_SetMaxLock_RevertWhenCallerIsNotOwner(
        address caller,
        uint256 newMaxLock
    )
        public
        notFromProxyAdmin(caller, address(stakeWeight))
    {
        vm.assume(caller != users.admin);
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", caller));
        stakeWeight.setMaxLock(newMaxLock);
    }

    function testFuzz_SetMaxLock_RevertWhenNewMaxLockIsGreaterThan209Weeks(uint256 newMaxLock) public {
        newMaxLock = bound(newMaxLock, MAX_LOCK + 1, type(uint256).max);
        vm.prank(users.admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidMaxLock(uint256)", newMaxLock));
        stakeWeight.setMaxLock(newMaxLock);
    }

    function testFuzz_SetMaxLock_RevertWhenNewMaxLockIsLessThanCurrentMaxLock(uint256 newMaxLock) public {
        uint256 currentMaxLock = stakeWeight.maxLock();
        newMaxLock = bound(newMaxLock, 0, currentMaxLock - 1);
        vm.prank(users.admin);
        vm.expectRevert(abi.encodeWithSignature("InvalidMaxLock(uint256)", newMaxLock));
        stakeWeight.setMaxLock(newMaxLock);
    }
}
