// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { BaseHandler } from "./BaseHandler.sol";
import { AllocationData } from "../stores/StakingRewardDistributorStore.sol";
import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { StakingRewardDistributorStore } from "../stores/StakingRewardDistributorStore.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { LockedTokenStaker } from "src/LockedTokenStaker.sol";
import { WCT } from "src/WCT.sol";
import { L2WCT } from "src/L2WCT.sol";
import { Eip1967Logger } from "script/utils/Eip1967Logger.sol";

contract StakingRewardDistributorHandler is BaseHandler {
    StakingRewardDistributor public stakingRewardDistributor;
    StakeWeight public stakeWeight;
    LockedTokenStaker public lockedTokenStaker;
    StakingRewardDistributorStore public store;
    address public admin;

    // Global timestamp that only moves forward
    uint256 public globalTimestamp;

    constructor(
        StakingRewardDistributor _stakingRewardDistributor,
        StakingRewardDistributorStore _store,
        LockedTokenStaker _lockedTokenStaker,
        address _admin,
        StakeWeight _stakeWeight,
        WCT _wct,
        L2WCT _l2wct
    )
        BaseHandler(_wct, _l2wct)
    {
        stakingRewardDistributor = _stakingRewardDistributor;
        lockedTokenStaker = _lockedTokenStaker;
        store = _store;
        admin = _admin;
        stakeWeight = _stakeWeight;
    }

    function checkpointToken(uint256 seed) public instrument("checkpointToken") {
        // Don't adjust timestamp for checkpoints - they should happen at current time
        stakingRewardDistributor.checkpointToken();
    }

    function checkpointTotalSupply(uint256 seed) public instrument("checkpointTotalSupply") {
        // Don't adjust timestamp for checkpoints - they should happen at current time
        stakingRewardDistributor.checkpointTotalSupply();
    }

    function claim(uint256 seed) public instrument("claim") {
        // Use very small time jumps to avoid accumulating too much checkpoint work
        // Keep it under 1 day to prevent checkpoint overflow issues
        uint256 timeJump = bound(seed, 1 minutes, 12 hours);
        vm.warp(block.timestamp + timeJump);
        // Safely pick a user with a lock; if none exist, skip to avoid revert under fail_on_revert
        address[] memory usersWithLocks = store.getUsersWithLocks();
        if (usersWithLocks.length == 0) {
            return;
        }
        uint256 idx =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, seed))) % usersWithLocks.length;
        address user = usersWithLocks[idx];
        vm.startPrank(user);
        uint256 claimedAmount = stakingRewardDistributor.claim(user);
        vm.stopPrank();
        store.updateClaimedAmount(user, claimedAmount);
    }

    function setRecipient(uint256 seed, address recipient) public instrument("setRecipient") {
        // Small time adjustments for setRecipient
        uint256 timeJump = bound(seed, 0, 1 hours);
        vm.warp(block.timestamp + timeJump);

        vm.assume(
            recipient != address(0) && recipient != address(stakeWeight)
                && recipient != address(stakingRewardDistributor)
        );
        address[] memory usersWithLocks = store.getUsersWithLocks();
        if (usersWithLocks.length == 0) {
            return;
        }
        uint256 idx =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, seed))) % usersWithLocks.length;
        address user = usersWithLocks[idx];
        vm.startPrank(user);
        stakingRewardDistributor.setRecipient(recipient);
        vm.stopPrank();
        store.setRecipient(user, recipient);
    }

    function injectReward(
        uint256 amount,
        uint256 time,
        uint256 seed
    )
        public
        useNewSender(admin)
        instrument("injectReward")
    {
        // Only adjust time slightly for inject operations
        uint256 timeJump = bound(seed, 0, 30 minutes);
        vm.warp(block.timestamp + timeJump);

        // Set safe bounds for reward amounts
        uint256 minReward = 100 * 1e18;
        uint256 maxReward = 100_000 * 1e18;
        uint256 safeReward = 5000 * 1e18;

        if (amount < minReward || amount > maxReward) {
            amount = safeReward;
        } else {
            amount = bound(amount, minReward, maxReward);
        }
        uint256 nowWeek = (block.timestamp / 1 weeks) * 1 weeks;
        time = bound(time, nowWeek, nowWeek + stakeWeight.maxLock());
        time = (time / 1 weeks) * 1 weeks;
        vm.assume(amount > 0);
        deal(address(l2wct), admin, amount);
        l2wct.approve(address(stakingRewardDistributor), amount);
        stakingRewardDistributor.injectReward({ timestamp: time, amount: amount });
        store.updateTotalInjectedRewards(amount, (time / 1 weeks) * 1 weeks);
        // End admin prank started by useNewSender
        vm.stopPrank();
    }

    function createLock(address user, uint256 amount, uint256 unlockTime) public instrument("createLock") {
        address srdProxyAdmin = Eip1967Logger.getAdmin(vm, address(stakingRewardDistributor));
        address swProxyAdmin = Eip1967Logger.getAdmin(vm, address(stakeWeight));
        vm.assume(
            user != address(stakeWeight) && user != address(stakingRewardDistributor) && user != srdProxyAdmin
                && user != swProxyAdmin && user != address(0)
        );

        // Skip if user already has a lock
        (,,,, bool hasLock,,) = store.userInfo(user);
        if (hasLock) {
            return;
        }

        // Set safe bounds to prevent int128 overflow
        uint256 minTokens = 1e18;
        uint256 maxTokens = 1_000_000 * 1e18;
        uint256 safeAmount = 10_000 * 1e18;

        if (amount < minTokens || amount > maxTokens) {
            amount = safeAmount;
        } else {
            amount = bound(amount, minTokens, maxTokens);
        }

        // Ensure user has enough balance
        uint256 currentBalance = l2wct.balanceOf(user);
        if (currentBalance < amount) {
            deal(address(l2wct), user, amount);
        }

        // Align unlockTime to full week boundaries within [next week, now + maxLock]
        uint256 nowWeek = (block.timestamp / 1 weeks) * 1 weeks;
        uint256 minUnlock = nowWeek + 1 weeks;
        uint256 maxUnlock = nowWeek + stakeWeight.maxLock();
        unlockTime = bound(unlockTime, minUnlock, maxUnlock);
        unlockTime = (unlockTime / 1 weeks) * 1 weeks;
        if (unlockTime <= block.timestamp) {
            unlockTime = minUnlock;
        }

        vm.startPrank(user);
        l2wct.approve(address(stakeWeight), amount);
        stakeWeight.createLock(amount, unlockTime);
        vm.stopPrank();

        store.updateLockedAmount(user, amount);
        store.updateUnlockTime(user, unlockTime);

        // Track lock creation time for ghost variables
        store.addAddressWithLock(user);
        store.setUserLockStartWeek(user, _timestampToFloorWeek(block.timestamp));
    }

    function withdrawAll(uint256 seed) public adjustTimestamp(seed) instrument("withdrawAll") {
        address[] memory usersWithLocks = store.getUsersWithLocks();
        if (usersWithLocks.length == 0) {
            return;
        }
        uint256 idx =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, seed))) % usersWithLocks.length;
        address user = usersWithLocks[idx];
        // Permanent locks are now admin-force-withdrawable; pick any user
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(user);
        if (block.timestamp < lock.end) {
            vm.warp(lock.end + 1);
        }

        vm.startPrank(user);
        stakeWeight.withdrawAll();
        vm.stopPrank();

        store.updateLockedAmount(user, 0);
        store.updateUnlockTime(user, 0);
    }

    function forceWithdrawAll(uint256 seed) public adjustTimestamp(seed) instrument("forceWithdrawAll") {
        address[] memory usersWithLocks = store.getUsersWithLocks();
        if (usersWithLocks.length == 0) {
            return;
        }
        uint256 idx =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, seed))) % usersWithLocks.length;
        address user = usersWithLocks[idx];
        // Skip permanent locks for force withdraw unless protocol supports it
        if (stakeWeight.permanentBaseWeeks(user) > 0) {
            return;
        }

        vm.startPrank(admin);
        stakeWeight.forceWithdrawAll(user);
        vm.stopPrank();

        store.updateLockedAmount(user, 0);
        store.updateUnlockTime(user, 0);
    }

    function createLockFor(
        uint256 seed,
        uint256 amount,
        uint256 unlockTime
    )
        public
        adjustTimestamp(seed)
        instrument("createLockFor")
    {
        AllocationData memory allocation;
        uint256 maxAttempts = 10; // Safety lock to prevent infinite loop
        for (uint256 safetyCounter = 0; safetyCounter < maxAttempts; safetyCounter++) {
            allocation = store.getRandomAllocation(amount);
            (,,,, bool hasLock,,) = store.userInfo(allocation.beneficiary);
            if (!hasLock) {
                break;
            }
            if (safetyCounter == maxAttempts - 1) {
                revert("Max attempts reached, unable to find an address without a lock");
            }
        }

        // Use conservative safe amount to avoid allocation reverts
        // Keep within typical allocation size to reduce merkle/vesting reverts
        uint256 minTokens = 1e18;
        uint256 maxTokens = 100_000 * 1e18; // 100k tokens cap
        uint256 safeAmount = 10_000 * 1e18;
        if (amount < minTokens || amount > maxTokens) {
            amount = safeAmount;
        } else {
            amount = bound(amount, minTokens, maxTokens);
        }
        // Align unlockTime to full week boundaries within [next week, now + maxLock]
        uint256 nowWeek2 = (block.timestamp / 1 weeks) * 1 weeks;
        uint256 minUnlock2 = nowWeek2 + 1 weeks;
        uint256 maxUnlock2 = nowWeek2 + stakeWeight.maxLock();
        unlockTime = bound(unlockTime, minUnlock2, maxUnlock2);
        unlockTime = (unlockTime / 1 weeks) * 1 weeks;
        if (unlockTime <= block.timestamp) {
            unlockTime = minUnlock2;
        }

        vm.startPrank(allocation.beneficiary);
        lockedTokenStaker.createLockFor(amount, unlockTime, 0, allocation.decodableArgs, allocation.proofs);
        vm.stopPrank();

        StakeWeight.LockedBalance memory newLock = stakeWeight.locks(allocation.beneficiary);

        store.addAddressWithLock(allocation.beneficiary);
        store.updateLockedAmount(allocation.beneficiary, SafeCast.toUint256(newLock.amount));
        store.updateUnlockTime(allocation.beneficiary, newLock.end);
    }

    function createPermanentLock(
        address user,
        uint256 amount,
        uint256 duration
    )
        public
        instrument("createPermanentLock")
    {
        address srdProxyAdmin = Eip1967Logger.getAdmin(vm, address(stakingRewardDistributor));
        address swProxyAdmin = Eip1967Logger.getAdmin(vm, address(stakeWeight));
        vm.assume(
            user != address(stakeWeight) && user != address(stakingRewardDistributor) && user != srdProxyAdmin
                && user != swProxyAdmin && user != address(0)
        );

        (,,,, bool hasLock,,) = store.userInfo(user);
        if (hasLock) {
            return; // User already has a lock
        }

        // Set reasonable bounds for amount to prevent int128 overflow
        // Define constants explicitly to avoid evaluation issues
        uint256 minTokens = 1e18; // 1 token
        uint256 maxTokens = 1_000_000 * 1e18; // 1M tokens
        uint256 safeAmount = 10_000 * 1e18; // 10k tokens

        // Directly set to a safe value when input is extreme
        if (amount < minTokens || amount > maxTokens) {
            amount = safeAmount;
        } else {
            // Only use bound() when amount is already in a reasonable range
            amount = bound(amount, minTokens, maxTokens);
        }

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
        // Use modulo to ensure we stay within bounds even with extreme values
        uint256 durationIndex = duration % 7;
        duration = validDurations[durationIndex];

        // Give user tokens
        deal(address(l2wct), user, amount);

        vm.startPrank(user);
        l2wct.approve(address(stakeWeight), amount);
        stakeWeight.createPermanentLock(amount, duration);
        vm.stopPrank();

        store.addAddressWithLock(user);
        store.updateLockedAmount(user, amount);
        store.updateUnlockTime(user, 0); // Permanent locks have no end time
    }

    function convertToPermanent(
        uint256 seed,
        uint256 duration
    )
        public
        adjustTimestamp(seed)
        instrument("convertToPermanent")
    {
        address[] memory usersWithLocks = store.getUsersWithLocks();
        if (usersWithLocks.length == 0) {
            return;
        }
        uint256 idx =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, seed))) % usersWithLocks.length;
        address user = usersWithLocks[idx];
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

        vm.startPrank(user);
        stakeWeight.convertToPermanent(selectedDuration);
        vm.stopPrank();

        store.updateUnlockTime(user, 0); // Now permanent
    }

    function updatePermanentLock(
        uint256 seed,
        uint256 amount,
        uint256 newDuration
    )
        public
        instrument("updatePermanentLock")
    {
        // Small time jumps for updates
        uint256 timeJump = bound(seed, 0, 1 hours);
        vm.warp(block.timestamp + timeJump);

        address[] memory usersWithLocks = store.getUsersWithLocks();
        if (usersWithLocks.length == 0) {
            return;
        }
        uint256 idx =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, seed))) % usersWithLocks.length;
        address user = usersWithLocks[idx];

        // Skip if not permanent
        if (stakeWeight.permanentBaseWeeks(user) == 0) {
            return;
        }

        // Set reasonable bounds for amount to avoid overflow
        uint256 maxUpdate = 100 * 1e18;
        uint256 safeUpdate = 10 * 1e18;

        if (amount > maxUpdate) {
            amount = safeUpdate;
        } else {
            amount = bound(amount, 0, maxUpdate);
        }

        // Select a valid duration >= current
        uint256 selectedDuration = _selectValidDuration(user, newDuration);

        if (amount > 0 && l2wct.balanceOf(user) < amount) {
            deal(address(l2wct), user, amount);
        }

        vm.startPrank(user);
        if (amount > 0) {
            l2wct.approve(address(stakeWeight), amount);
        }
        stakeWeight.updatePermanentLock(amount, selectedDuration);
        vm.stopPrank();

        StakeWeight.LockedBalance memory newLock = stakeWeight.locks(user);
        store.updateLockedAmount(user, SafeCast.toUint256(newLock.amount));
    }

    function _selectValidDuration(address user, uint256 seed) private view returns (uint256) {
        // Valid durations array
        uint256[7] memory validDurations =
            [uint256(4 weeks), 8 weeks, 12 weeks, 26 weeks, 52 weeks, 78 weeks, 104 weeks];

        // Find minimum valid duration >= current
        uint256 currentDuration = stakeWeight.permanentBaseWeeks(user) * 1 weeks;
        uint256 minIndex = 6; // Default to max if none found
        for (uint256 i = 0; i < 7; i++) {
            if (validDurations[i] >= currentDuration) {
                minIndex = i;
                break;
            }
        }

        // Use modulo to select from valid range
        uint256 rangeSize = 7 - minIndex;
        if (rangeSize == 0) return validDurations[6]; // Return max if at max
        uint256 offset = seed % rangeSize;
        return validDurations[minIndex + offset];
    }
}
