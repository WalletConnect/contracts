// SPDX-License-Identifier: MIT

import { StakeWeight } from "src/StakeWeight.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { StakeWeight_Integration_Shared_Test } from "test/integration/shared/StakeWeight.t.sol";

pragma solidity >=0.8.25 <0.9.0;

contract ForceWithdrawAll_StakeWeight_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    uint256 constant LOCK_AMOUNT = 100e18;
    uint256 constant LOCK_DURATION = 1 weeks;

    function setUp() public override {
        super.setUp();
        vm.prank(users.admin);
        l2wct.disableTransferRestrictions();
    }

    function test_RevertWhen_CallerIsNotAdmin() external {
        bytes32 role = stakeWeight.DEFAULT_ADMIN_ROLE();
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", users.alice, role));
        vm.prank(users.alice);
        stakeWeight.forceWithdrawAll(users.bob);
    }

    modifier whenCallerIsAdmin() {
        vm.startPrank(users.admin);
        _;
    }

    function test_RevertWhen_ToAddressIsZero() external whenCallerIsAdmin {
        vm.expectRevert(abi.encodeWithSelector(StakeWeight.InvalidAddress.selector, address(0)));
        stakeWeight.forceWithdrawAll(address(0));
    }

    function test_RevertWhen_UserHasNoLock() external whenCallerIsAdmin {
        vm.expectRevert(StakeWeight.NonExistentLock.selector);
        stakeWeight.forceWithdrawAll(users.bob);
    }

    modifier whenUserHasLock() {
        bytes32 role = stakeWeight.LOCKED_TOKEN_STAKER_ROLE();
        stakeWeight.grantRole(role, users.admin);

        stakeWeight.createLockFor(users.alice, LOCK_AMOUNT, block.timestamp + LOCK_DURATION);

        _;
    }

    function test_ForceWithdrawAll_WithNoTransferredAmount() external whenCallerIsAdmin whenUserHasLock {
        uint256 initialSupply = stakeWeight.supply();
        uint256 initialBalance = l2wct.balanceOf(users.alice);

        vm.expectEmit(true, true, true, true);
        emit Supply(initialSupply, initialSupply - LOCK_AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit ForcedWithdraw(
            users.alice, LOCK_AMOUNT, 0, block.timestamp, _timestampToFloorWeek(block.timestamp + LOCK_DURATION)
        );

        stakeWeight.forceWithdrawAll(users.alice);

        StakeWeight.LockedBalance memory lock = stakeWeight.locks(users.alice);
        assertEq(SafeCast.toUint256(lock.amount), 0, "Lock amount should be zero");
        assertEq(lock.end, 0, "Lock end should be zero");
        assertEq(lock.transferredAmount, 0, "Transferred amount should be zero");
        assertEq(stakeWeight.supply(), initialSupply - LOCK_AMOUNT, "Total supply should be updated");
        assertEq(l2wct.balanceOf(users.alice), initialBalance, "No tokens should be transferred");
    }

    function test_ForceWithdrawAll_WithTransferredAmount() external whenCallerIsAdmin whenUserHasLock {
        // We increase the lock amount to have a transferred amount
        deal(address(l2wct), users.alice, LOCK_AMOUNT);
        resetPrank(users.alice);
        l2wct.approve(address(stakeWeight), LOCK_AMOUNT);
        stakeWeight.increaseLockAmount(LOCK_AMOUNT);

        uint256 initialSupply = stakeWeight.supply();
        uint256 initialBalance = l2wct.balanceOf(users.alice);

        StakeWeight.LockedBalance memory lock = stakeWeight.locks(users.alice);
        uint256 lockAmount = SafeCast.toUint256(lock.amount);

        vm.expectEmit(true, true, true, true);
        emit Supply(initialSupply, initialSupply - lockAmount);

        vm.expectEmit(true, true, true, true);
        emit ForcedWithdraw(
            users.alice,
            lockAmount,
            lock.transferredAmount,
            block.timestamp,
            _timestampToFloorWeek(block.timestamp + LOCK_DURATION)
        );

        resetPrank(users.admin);
        stakeWeight.forceWithdrawAll(users.alice);

        lock = stakeWeight.locks(users.alice);
        assertEq(SafeCast.toUint256(lock.amount), 0, "Lock amount should be zero");
        assertEq(lock.end, 0, "Lock end should be zero");
        assertEq(lock.transferredAmount, 0, "Transferred amount should be zero");
        assertEq(stakeWeight.supply(), initialSupply - LOCK_AMOUNT * 2, "Total supply should be updated");
        assertEq(
            l2wct.balanceOf(users.alice), initialBalance + LOCK_AMOUNT, "Tokens should be transferred to recipient"
        );
    }

    function test_ForceWithdrawAll_PermanentLock_Succeeds() external whenCallerIsAdmin {
        // Create permanent lock for Alice
        deal(address(l2wct), users.alice, LOCK_AMOUNT);
        resetPrank(users.alice);
        l2wct.approve(address(stakeWeight), LOCK_AMOUNT);
        stakeWeight.createPermanentLock(LOCK_AMOUNT, 52 weeks);

        // Sanity: permanent state
        assertGt(stakeWeight.permanentOf(users.alice), 0, "permanent weight should be > 0");

        uint256 initialSupply = stakeWeight.supply();
        uint256 initialBalance = l2wct.balanceOf(users.alice);

        // Admin force withdraw permanent lock
        resetPrank(users.admin);
        stakeWeight.forceWithdrawAll(users.alice);

        // Verify lock cleared
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(users.alice);
        assertEq(SafeCast.toUint256(lock.amount), 0, "Lock amount should be zero");
        assertEq(lock.end, 0, "Lock end should be zero");
        assertEq(lock.transferredAmount, 0, "Transferred amount should be zero");
        assertEq(stakeWeight.permanentOf(users.alice), 0, "permanent weight should be zero");
        assertEq(stakeWeight.supply(), initialSupply - LOCK_AMOUNT, "Total supply should decrease by amount");
        // transferredAmount for permanent path equals amount (transferred on create), but _force path sends only
        // transferredAmount
        // For createPermanentLock, transferredAmount == amount, so user receives their tokens back
        assertEq(l2wct.balanceOf(users.alice), initialBalance + LOCK_AMOUNT, "Tokens returned to user");
    }

    function test_ForceWithdrawAll_WorksDuringPause() external whenCallerIsAdmin whenUserHasLock {
        // Store lock end before time skip
        StakeWeight.LockedBalance memory lockBeforePause = stakeWeight.locks(users.alice);
        uint256 lockEnd = lockBeforePause.end;

        // Pause StakeWeight
        resetPrank(users.pauser);
        pauser.setIsStakeWeightPaused(true);

        // Verify system is paused - normal withdrawal should fail
        resetPrank(users.alice);
        skip(LOCK_DURATION + 1);
        vm.expectRevert(StakeWeight.Paused.selector);
        stakeWeight.withdrawAll();

        // But admin can still force withdraw (critical for handling revoked vestings)
        resetPrank(users.admin);
        uint256 initialSupply = stakeWeight.supply();
        uint256 initialBalance = l2wct.balanceOf(users.alice);

        vm.expectEmit(true, true, true, true);
        emit Supply(initialSupply, initialSupply - LOCK_AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit ForcedWithdraw(users.alice, LOCK_AMOUNT, 0, block.timestamp, lockEnd);

        stakeWeight.forceWithdrawAll(users.alice);

        // Verify withdrawal succeeded
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(users.alice);
        assertEq(SafeCast.toUint256(lock.amount), 0, "Lock amount should be zero");
        assertEq(lock.end, 0, "Lock end should be zero");
        assertEq(stakeWeight.supply(), initialSupply - LOCK_AMOUNT, "Total supply should be updated");
        assertEq(l2wct.balanceOf(users.alice), initialBalance, "No tokens transferred (not user-transferred)");
    }
}
