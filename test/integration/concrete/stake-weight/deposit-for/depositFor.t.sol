// SPDX-License-Identifier: MIT

import { StakeWeight } from "src/StakeWeight.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { StakeWeight_Integration_Shared_Test } from "test/integration/shared/StakeWeight.t.sol";

pragma solidity >=0.8.25 <0.9.0;

contract DepositFor_StakeWeight_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    uint256 amount = 100e18;

    function test_RevertWhen_ContractIsPaused() external {
        _pause();

        vm.expectRevert(StakeWeight.Paused.selector);
        stakeWeight.depositFor(users.alice, 100);
    }

    modifier whenContractIsNotPaused() {
        _;
    }

    function test_RevertWhen_ForAddressIsZero() external whenContractIsNotPaused {
        vm.expectRevert(StakeWeight.InvalidAddress.selector);
        stakeWeight.depositFor(address(0), 100);
    }

    modifier whenForAddressIsNotZero() {
        _;
    }

    function test_WhenRecipientHasNoExistingLock() external whenContractIsNotPaused whenForAddressIsNotZero {
        address recipient = users.alice;

        vm.expectRevert(StakeWeight.InvalidLockState.selector);
        stakeWeight.depositFor(recipient, amount);
    }

    modifier whenRecipientHasExistingLock(address recipient) {
        _createLockForUser(recipient, amount, block.timestamp + 1 weeks);
        vm.startPrank(recipient);
        _;
    }

    function test_RevertGiven_RecipientHasExpiredLock()
        external
        whenContractIsNotPaused
        whenForAddressIsNotZero
        whenRecipientHasExistingLock(users.alice)
    {
        vm.warp(block.timestamp + 2 weeks);

        (, uint256 lockEnd) = stakeWeight.locks(users.alice);

        vm.expectRevert(abi.encodeWithSelector(StakeWeight.ExpiredLock.selector, block.timestamp, lockEnd));
        stakeWeight.depositFor(users.alice, amount);
    }

    function test_RevertWhen_RecipientHasExistingLockAndAmountIsZero()
        external
        whenContractIsNotPaused
        whenForAddressIsNotZero
        whenRecipientHasExistingLock(users.alice)
    {
        vm.expectRevert(abi.encodeWithSelector(StakeWeight.InvalidAmount.selector, 0));
        stakeWeight.depositFor(users.alice, 0);
    }

    function test_WhenRecipientHasExistingLockAndAmountIsGreaterThanZero()
        external
        whenContractIsNotPaused
        whenForAddressIsNotZero
        whenRecipientHasExistingLock(users.alice)
    {
        uint256 additionalAmount = 50e18;
        uint256 initialSupply = stakeWeight.supply();
        deal(address(l2wct), users.bob, additionalAmount + amount);
        uint256 initialBalance = l2wct.balanceOf(address(users.bob));

        (, uint256 lockEnd) = stakeWeight.locks(users.alice);
        resetPrank(users.bob);
        l2wct.approve(address(stakeWeight), additionalAmount);

        vm.expectEmit(true, true, true, true);
        emit Deposit(users.alice, additionalAmount, lockEnd, stakeWeight.ACTION_DEPOSIT_FOR(), block.timestamp);

        vm.expectEmit(true, true, true, true);
        emit Supply(initialSupply, initialSupply + additionalAmount);

        stakeWeight.depositFor(users.alice, additionalAmount);
        vm.stopPrank();

        (int128 lockAmount,) = stakeWeight.locks(users.alice);
        assertEq(SafeCast.toUint256(lockAmount), amount + additionalAmount, "Lock amount should be increased");
        assertEq(stakeWeight.supply(), initialSupply + additionalAmount, "Total supply should be updated");
        assertEq(
            l2wct.balanceOf(address(users.bob)),
            initialBalance - additionalAmount,
            "Tokens should be transferred from caller"
        );
    }
}
