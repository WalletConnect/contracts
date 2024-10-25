// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { BaseHandler } from "./BaseHandler.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { WCT } from "src/WCT.sol";
import { L2WCT } from "src/L2WCT.sol";
import { LockedTokenStaker } from "src/LockedTokenStaker.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { StakeWeightStore, AllocationData } from "../stores/StakeWeightStore.sol";

contract StakeWeightHandler is BaseHandler {
    StakeWeight public stakeWeight;
    LockedTokenStaker public lockedTokenStaker;
    StakeWeightStore public store;
    address public admin;
    address public manager;

    constructor(
        StakeWeight _stakeWeight,
        StakeWeightStore _store,
        address _admin,
        address _manager,
        WCT _wct,
        L2WCT _l2wct,
        LockedTokenStaker _lockedTokenStaker
    )
        BaseHandler(_wct, _l2wct)
    {
        stakeWeight = _stakeWeight;
        store = _store;
        admin = _admin;
        manager = _manager;
        lockedTokenStaker = _lockedTokenStaker;
    }

    function createLock(address user, uint256 amount, uint256 unlockTime) public instrument("createLock") {
        vm.assume(user != address(stakeWeight));
        if (!store.hasLock(user) && l2wct.balanceOf(user) == 0) {
            // Set a reasonable range for initial token amounts
            uint256 minAmount = 100 * 10 ** 18; // 100 tokens
            uint256 maxAmount = 10_000 * 10 ** 18; // 10,000 tokens
            amount = bound(amount, minAmount, maxAmount);
            deal(address(l2wct), user, amount);
        }

        unlockTime = bound(unlockTime, block.timestamp + 1 weeks, block.timestamp + stakeWeight.maxLock());

        uint256 previousBalance = stakeWeight.balanceOf(user);
        StakeWeight.LockedBalance memory previousLock = stakeWeight.locks(user);

        vm.startPrank(user);
        l2wct.approve(address(stakeWeight), amount);
        stakeWeight.createLock(amount, unlockTime);
        vm.stopPrank();

        StakeWeight.LockedBalance memory newLock = stakeWeight.locks(user);

        store.addAddressWithLock(user);
        store.updateLockedAmount(user, newLock.amount);
        store.updatePreviousBalance(user, previousBalance);
        store.updatePreviousEndTime(user, previousLock.end);
    }

    function increaseLockAmount(uint256 amount) public instrument("increaseLockAmount") {
        address user = store.getRandomAddressWithLock();
        // Set a reasonable range for increasing lock amounts
        uint256 minAmount = 10 * 10 ** 18; // 10 tokens
        uint256 maxAmount = 1000 * 10 ** 18; // 1,000 tokens
        amount = bound(amount, minAmount, maxAmount);

        if (l2wct.balanceOf(user) < amount) {
            deal(address(l2wct), user, amount);
        }

        uint256 previousBalance = stakeWeight.balanceOf(user);
        StakeWeight.LockedBalance memory previousLock = stakeWeight.locks(user);

        vm.startPrank(user);
        l2wct.approve(address(stakeWeight), amount);
        stakeWeight.increaseLockAmount(amount);
        vm.stopPrank();

        StakeWeight.LockedBalance memory newLock = stakeWeight.locks(user);
        int128 increasedAmount = newLock.amount - previousLock.amount;

        store.updateLockedAmount(user, increasedAmount);
        store.updatePreviousBalance(user, previousBalance);
        store.updatePreviousEndTime(user, previousLock.end);
    }

    function increaseUnlockTime(uint256 unlockTime) public instrument("increaseUnlockTime") {
        address user = store.getRandomAddressWithLock();
        StakeWeight.LockedBalance memory previousLock = stakeWeight.locks(user);
        unlockTime = bound(unlockTime, previousLock.end + 1, block.timestamp + stakeWeight.maxLock());

        uint256 previousBalance = stakeWeight.balanceOf(user);

        resetPrank(user);
        stakeWeight.increaseUnlockTime(unlockTime);
        vm.stopPrank();

        store.updatePreviousBalance(user, previousBalance);
        store.updatePreviousEndTime(user, previousLock.end);
    }

    function withdrawAll() public instrument("withdrawAll") {
        address user = store.getRandomAddressWithLock();

        StakeWeight.LockedBalance memory lock = stakeWeight.locks(user);

        resetPrank(user);
        stakeWeight.withdrawAll();
        vm.stopPrank();

        uint256 newWithdrawnAmount = uint256(uint128(lock.amount));
        store.updateWithdrawnAmount(user, newWithdrawnAmount);
        store.removeAddressWithLock(user);
    }

    function createLockFor(uint256 amount, uint256 unlockTime) public instrument("createLockFor") {
        AllocationData memory allocation;
        uint256 maxAttempts = 10; // Safety lock to prevent infinite loop
        for (uint256 safetyCounter = 0; safetyCounter < maxAttempts; safetyCounter++) {
            allocation = store.getRandomAllocation(amount);
            if (!store.hasLock(allocation.beneficiary)) {
                break;
            }
            if (safetyCounter == maxAttempts - 1) {
                revert("Max attempts reached, unable to find an address without a lock");
            }
        }

        // 1 Billion / 500 allocations at 25% unlock passed
        uint256 maxAmount = 1e27 / 500 / 4;
        amount = bound(amount, 1, maxAmount);
        unlockTime = bound(unlockTime, block.timestamp + 1, block.timestamp + stakeWeight.maxLock());

        uint256 previousBalance = stakeWeight.balanceOf(allocation.beneficiary);
        StakeWeight.LockedBalance memory previousLock = stakeWeight.locks(allocation.beneficiary);

        vm.prank(allocation.beneficiary);
        lockedTokenStaker.createLockFor(amount, unlockTime, 0, allocation.decodableArgs, allocation.proofs);

        StakeWeight.LockedBalance memory newLock = stakeWeight.locks(allocation.beneficiary);

        store.addAddressWithLock(allocation.beneficiary);
        store.updateNonTransferableBalance(newLock.amount);
        store.updateLockedAmount(allocation.beneficiary, newLock.amount);
        store.updatePreviousBalance(allocation.beneficiary, previousBalance);
        store.updatePreviousEndTime(allocation.beneficiary, previousLock.end);
    }

    function increaseLockAmountFor(uint256 amount) public instrument("increaseLockAmountFor") {
        AllocationData memory allocation;
        uint256 maxAttempts = 10; // Safety lock to prevent infinite loop
        for (uint256 safetyCounter = 0; safetyCounter < maxAttempts; safetyCounter++) {
            allocation = store.getRandomAllocation(amount);
            if (store.hasLock(allocation.beneficiary)) {
                break;
            }
            if (safetyCounter == maxAttempts - 1) return;
        }

        uint256 previousBalance = stakeWeight.balanceOf(allocation.beneficiary);
        StakeWeight.LockedBalance memory previousLock = stakeWeight.locks(allocation.beneficiary);

        uint256 minAmount = 10 * 10 ** 18; // 10 tokens
        // 1 Billion / 500 allocations at 25% unlock passed - already locked amount
        uint256 maxAmount = 1e27 / 500 / 4 - SafeCast.toUint256(previousLock.amount);
        amount = bound(amount, minAmount, maxAmount);

        vm.prank(allocation.beneficiary);
        lockedTokenStaker.increaseLockAmountFor(amount, 0, allocation.decodableArgs, allocation.proofs);

        StakeWeight.LockedBalance memory newLock = stakeWeight.locks(allocation.beneficiary);

        int128 increasedAmount = newLock.amount - previousLock.amount;

        store.updateNonTransferableBalance(increasedAmount);
        store.updateLockedAmount(allocation.beneficiary, increasedAmount);
        store.updatePreviousBalance(allocation.beneficiary, previousBalance);
        store.updatePreviousEndTime(allocation.beneficiary, previousLock.end);
    }

    function checkpoint() public instrument("checkpoint") {
        resetPrank(manager);
        stakeWeight.checkpoint();
        vm.stopPrank();
    }
}
