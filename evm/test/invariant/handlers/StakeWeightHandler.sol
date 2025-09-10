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
        
        // Skip permanent locks (cannot withdraw)
        if (stakeWeight.permanentBaseWeeks(user) > 0) {
            return;
        }

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

        // 100M tokens / 500 allocations at 25% unlock passed
        // 100M / 500 / 4 = 50k tokens per allocation
        uint256 maxAmount = 1e26 / 500 / 4;
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
        // 100M tokens / 500 allocations / 4 unlock periods - existing amount
        uint256 maxAmount = 1e26 / 500 / 4;
        if (SafeCast.toUint256(previousLock.amount) >= maxAmount) {
            return; // Already at max, skip
        }
        maxAmount = maxAmount - SafeCast.toUint256(previousLock.amount);
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

    function forceWithdrawAll() public instrument("forceWithdrawAll") {
        address user = store.getRandomAddressWithLock();
        uint256 previousBalance = stakeWeight.balanceOf(user);
        StakeWeight.LockedBalance memory previousLock = stakeWeight.locks(user);

        resetPrank(admin);
        stakeWeight.forceWithdrawAll(user);
        vm.stopPrank();

        uint256 newWithdrawnAmount = uint256(uint128(previousLock.amount));
        store.removeAddressWithLock(user);
        store.updateWithdrawnAmount(user, newWithdrawnAmount);
        store.updateNonTransferableBalance(
            -int128(previousLock.amount - int128(int256(previousLock.transferredAmount)))
        );
        store.updateLockedAmount(user, -int128(previousLock.amount));
        store.updatePreviousBalance(user, previousBalance);
        store.updatePreviousEndTime(user, previousLock.end);
        store.setHasBeenForcedWithdrawn(user, true);
    }

    function updateLock(uint256 amount, uint256 unlockTime) public instrument("updateLock") {
        address user = store.getRandomAddressWithLock();
        uint256 previousBalance = stakeWeight.balanceOf(user);
        StakeWeight.LockedBalance memory previousLock = stakeWeight.locks(user);

        resetPrank(user);
        stakeWeight.updateLock(amount, unlockTime);
        vm.stopPrank();

        StakeWeight.LockedBalance memory newLock = stakeWeight.locks(user);
        int128 increasedAmount = newLock.amount - previousLock.amount;

        store.updateLockedAmount(user, increasedAmount);
        store.updatePreviousBalance(user, previousBalance);
        store.updatePreviousEndTime(user, previousLock.end);
    }

    function checkpoint() public instrument("checkpoint") {
        resetPrank(manager);
        stakeWeight.checkpoint();
        vm.stopPrank();
    }

    function createPermanentLock(address user, uint256 amount, uint256 duration) public instrument("createPermanentLock") {
        // Filter out invalid addresses
        vm.assume(user != address(stakeWeight) && user != address(0));
        
        // Check if user already has a lock
        if (store.hasLock(user)) {
            return;
        }
        
        // Set reasonable bounds for amount
        uint256 minAmount = 100 * 10 ** 18; // 100 tokens
        uint256 maxAmount = 10_000 * 10 ** 18; // 10,000 tokens
        amount = bound(amount, minAmount, maxAmount);
        
        // Valid durations per StakeWeight._isValidDuration
        uint256[] memory validDurations = new uint256[](7);
        validDurations[0] = 4 weeks;
        validDurations[1] = 8 weeks;
        validDurations[2] = 12 weeks;
        validDurations[3] = 26 weeks;
        validDurations[4] = 52 weeks;
        validDurations[5] = 78 weeks;
        validDurations[6] = 104 weeks;
        
        // Bound duration to valid index range and pick a valid duration
        uint256 durationIndex = bound(duration, 0, 6);
        duration = validDurations[durationIndex];
        
        // Give user tokens
        deal(address(l2wct), user, amount);
        
        uint256 previousBalance = stakeWeight.balanceOf(user);
        
        vm.startPrank(user);
        l2wct.approve(address(stakeWeight), amount);
        stakeWeight.createPermanentLock(amount, duration);
        vm.stopPrank();
        
        StakeWeight.LockedBalance memory newLock = stakeWeight.locks(user);
        
        store.addAddressWithLock(user);
        store.updateLockedAmount(user, newLock.amount);
        store.updatePreviousBalance(user, previousBalance);
        store.updatePreviousEndTime(user, 0); // Permanent locks have no end time
    }

    function convertToPermanent(uint256 duration) public instrument("convertToPermanent") {
        address user = store.getRandomAddressWithLock();
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(user);
        
        // Skip if already permanent or expired
        if (stakeWeight.permanentBaseWeeks(user) > 0 || lock.end <= block.timestamp) {
            return;
        }
        
        // Valid durations for permanent locks
        uint256[] memory validDurations = new uint256[](7);
        validDurations[0] = 4 weeks;
        validDurations[1] = 8 weeks;
        validDurations[2] = 12 weeks;
        validDurations[3] = 26 weeks;
        validDurations[4] = 52 weeks;
        validDurations[5] = 78 weeks;
        validDurations[6] = 104 weeks;
        
        // Pick a duration that's at least as long as remaining lock time
        uint256 remainingTime = lock.end - block.timestamp;
        uint256 selectedDuration;
        for (uint256 i = 0; i < validDurations.length; i++) {
            if (validDurations[i] >= remainingTime) {
                selectedDuration = validDurations[i];
                break;
            }
        }
        if (selectedDuration == 0) {
            selectedDuration = validDurations[6]; // Use max if none found
        }
        
        uint256 previousBalance = stakeWeight.balanceOf(user);
        
        resetPrank(user);
        stakeWeight.convertToPermanent(selectedDuration);
        vm.stopPrank();
        
        store.updatePreviousBalance(user, previousBalance);
        store.updatePreviousEndTime(user, 0); // Now permanent
    }

    function triggerUnlock() public instrument("triggerUnlock") {
        address user = store.getRandomAddressWithLock();
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(user);
        
        // Skip if not permanent
        if (stakeWeight.permanentBaseWeeks(user) == 0) {
            return;
        }
        
        uint256 previousBalance = stakeWeight.balanceOf(user);
        
        resetPrank(user);
        stakeWeight.triggerUnlock();
        vm.stopPrank();
        
        // Calculate new end time
        uint256 newEnd = (block.timestamp / 1 weeks) * 1 weeks + stakeWeight.permanentBaseWeeks(user) * 1 weeks;
        
        store.updatePreviousBalance(user, previousBalance);
        store.updatePreviousEndTime(user, newEnd);
    }

    function updatePermanentLock(uint256 amount, uint256 newDuration) public instrument("updatePermanentLock") {
        address user = store.getRandomAddressWithLock();
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(user);
        
        // Skip if not permanent
        if (stakeWeight.permanentBaseWeeks(user) == 0) {
            return;
        }
        
        // Set reasonable bounds for amount
        amount = bound(amount, 0, 1000 * 10 ** 18);
        
        // Valid durations (must be >= current)
        uint256[] memory validDurations = new uint256[](7);
        validDurations[0] = 4 weeks;
        validDurations[1] = 8 weeks;
        validDurations[2] = 12 weeks;
        validDurations[3] = 26 weeks;
        validDurations[4] = 52 weeks;
        validDurations[5] = 78 weeks;
        validDurations[6] = 104 weeks;
        
        // Find valid durations >= current
        uint256 minIndex = 0;
        uint256 currentDuration = stakeWeight.permanentBaseWeeks(user) * 1 weeks;
        for (uint256 i = 0; i < validDurations.length; i++) {
            if (validDurations[i] >= currentDuration) {
                minIndex = i;
                break;
            }
        }
        
        // Bound to valid range and pick a duration >= current
        uint256 durationIndex = bound(newDuration, minIndex, 6);
        uint256 selectedDuration = validDurations[durationIndex];
        
        if (amount > 0 && l2wct.balanceOf(user) < amount) {
            deal(address(l2wct), user, amount);
        }
        
        uint256 previousBalance = stakeWeight.balanceOf(user);
        
        vm.startPrank(user);
        if (amount > 0) {
            l2wct.approve(address(stakeWeight), amount);
        }
        stakeWeight.updatePermanentLock(amount, selectedDuration);
        vm.stopPrank();
        
        StakeWeight.LockedBalance memory newLock = stakeWeight.locks(user);
        int128 increasedAmount = newLock.amount - lock.amount;
        
        store.updateLockedAmount(user, increasedAmount);
        store.updatePreviousBalance(user, previousBalance);
    }

    function increasePermanentLockDuration(uint256 newDuration) public instrument("increasePermanentLockDuration") {
        address user = store.getRandomAddressWithLock();
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(user);
        
        // Skip if not permanent
        if (stakeWeight.permanentBaseWeeks(user) == 0) {
            return;
        }
        
        // Valid durations (must be > current)
        uint256[] memory validDurations = new uint256[](7);
        validDurations[0] = 4 weeks;
        validDurations[1] = 8 weeks;
        validDurations[2] = 12 weeks;
        validDurations[3] = 26 weeks;
        validDurations[4] = 52 weeks;
        validDurations[5] = 78 weeks;
        validDurations[6] = 104 weeks;
        
        // Pick a duration > current
        uint256 selectedDuration = 0;
        uint256 currentDuration = stakeWeight.permanentBaseWeeks(user) * 1 weeks;
        for (uint256 i = 0; i < validDurations.length; i++) {
            if (validDurations[i] > currentDuration) {
                selectedDuration = validDurations[i];
                break;
            }
        }
        
        if (selectedDuration == 0) {
            return; // Already at max
        }
        
        uint256 previousBalance = stakeWeight.balanceOf(user);
        
        resetPrank(user);
        stakeWeight.increasePermanentLockDuration(selectedDuration);
        vm.stopPrank();
        
        store.updatePreviousBalance(user, previousBalance);
    }
}
