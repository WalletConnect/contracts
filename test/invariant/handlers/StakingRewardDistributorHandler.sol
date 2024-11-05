// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { BaseHandler } from "./BaseHandler.sol";
import { AllocationData } from "../stores/StakingRewardDistributorStore.sol";
import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { StakingRewardDistributorStore } from "../stores/StakingRewardDistributorStore.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { LockedTokenStaker } from "src/LockedTokenStaker.sol";
import { WCT } from "src/WCT.sol";
import { L2WCT } from "src/L2WCT.sol";

contract StakingRewardDistributorHandler is BaseHandler {
    StakingRewardDistributor public stakingRewardDistributor;
    StakeWeight public stakeWeight;
    LockedTokenStaker public lockedTokenStaker;
    StakingRewardDistributorStore public store;
    address public admin;

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

    function checkpointToken(uint256 seed) public adjustTimestamp(seed) instrument("checkpointToken") {
        stakingRewardDistributor.checkpointToken();
    }

    function checkpointTotalSupply(uint256 seed) public adjustTimestamp(seed) instrument("checkpointTotalSupply") {
        stakingRewardDistributor.checkpointTotalSupply();
    }

    function claim(uint256 seed) public adjustTimestamp(seed) instrument("claim") {
        address user = store.getRandomAddressWithLock();
        uint256 claimedAmount = stakingRewardDistributor.claim(user);
        store.updateClaimedAmount(user, claimedAmount);
    }

    function setRecipient(uint256 seed, address recipient) public adjustTimestamp(seed) instrument("setRecipient") {
        vm.assume(recipient != address(stakeWeight) && recipient != address(stakingRewardDistributor));
        address user = store.getRandomAddressWithLock();
        vm.prank(user);
        stakingRewardDistributor.setRecipient(recipient);
        store.setRecipient(user, recipient);
    }

    function injectReward(
        uint256 amount,
        uint256 time,
        uint256 seed
    )
        public
        useNewSender(admin)
        adjustTimestamp(seed)
        instrument("injectReward")
    {
        uint256 minAmount = 100 * 10 ** 18; // 100 tokens
        uint256 maxAmount = 1_000_000 * 10 ** 18; // 1,000,000 tokens
        amount = bound(amount, minAmount, maxAmount);
        time = bound(time, block.timestamp, block.timestamp + stakeWeight.maxLock());
        vm.assume(amount > 0);
        deal(address(l2wct), admin, amount);
        l2wct.approve(address(stakingRewardDistributor), amount);
        stakingRewardDistributor.injectReward({ timestamp: time, amount: amount });
        store.updateTotalInjectedRewards(amount, (time / 1 weeks) * 1 weeks);
    }

    function feed(uint256 amount, uint256 seed) public useNewSender(admin) adjustTimestamp(seed) instrument("feed") {
        uint256 minAmount = 100 * 10 ** 18; // 100 tokens
        uint256 maxAmount = 1_000_000 * 10 ** 18; // 1,000,000 tokens
        amount = bound(amount, minAmount, maxAmount);
        vm.assume(amount > 0);
        deal(address(l2wct), admin, amount);
        l2wct.approve(address(stakingRewardDistributor), amount);
        stakingRewardDistributor.feed(amount);
        store.updateTotalFedRewards(amount);
    }

    function createLock(address user, uint256 amount, uint256 unlockTime) public instrument("createLock") {
        vm.assume(user != address(stakeWeight) && user != address(stakingRewardDistributor));
        (,,,, bool hasLock) = store.userInfo(user);
        if (!hasLock && l2wct.balanceOf(user) == 0) {
            // Set a reasonable range for initial token amounts
            uint256 minAmount = 100 * 10 ** 18; // 100 tokens
            uint256 maxAmount = 10_000 * 10 ** 18; // 10,000 tokens
            amount = bound(amount, minAmount, maxAmount);
            deal(address(l2wct), user, amount);

            unlockTime = bound(unlockTime, block.timestamp + 1 weeks, block.timestamp + stakeWeight.maxLock());

            vm.startPrank(user);
            l2wct.approve(address(stakeWeight), amount);
            stakeWeight.createLock(amount, unlockTime);
            vm.stopPrank();

            store.updateLockedAmount(user, amount);
            store.updateUnlockTime(user, unlockTime);
        }
    }

    function withdrawAll(uint256 seed) public adjustTimestamp(seed) instrument("withdrawAll") {
        address user = store.getRandomAddressWithLock();

        vm.startPrank(user);
        stakeWeight.withdrawAll();
        vm.stopPrank();

        store.updateLockedAmount(user, 0);
        store.updateUnlockTime(user, 0);
    }

    function forceWithdrawAll(uint256 seed) public adjustTimestamp(seed) instrument("forceWithdrawAll") {
        address user = store.getRandomAddressWithLock();

        vm.prank(admin);
        stakeWeight.forceWithdrawAll(user);

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
            (,,,, bool hasLock) = store.userInfo(allocation.beneficiary);
            if (!hasLock) {
                break;
            }
            if (safetyCounter == maxAttempts - 1) {
                revert("Max attempts reached, unable to find an address without a lock");
            }
        }

        // 1 Billion / 500 allocations at 25% unlock passed
        uint256 maxAmount = 1e27 / 500;
        amount = bound(amount, 1, maxAmount);
        unlockTime = bound(unlockTime, block.timestamp + 1, block.timestamp + stakeWeight.maxLock());

        vm.prank(allocation.beneficiary);
        lockedTokenStaker.createLockFor(amount, unlockTime, 0, allocation.decodableArgs, allocation.proofs);

        StakeWeight.LockedBalance memory newLock = stakeWeight.locks(allocation.beneficiary);

        store.addAddressWithLock(allocation.beneficiary);
        store.updateLockedAmount(allocation.beneficiary, SafeCast.toUint256(newLock.amount));
        store.updateUnlockTime(allocation.beneficiary, newLock.end);
    }
}
