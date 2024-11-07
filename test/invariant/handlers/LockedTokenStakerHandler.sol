// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { BaseHandler } from "./BaseHandler.sol";
import { LockedTokenStaker } from "src/LockedTokenStaker.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { WCT } from "src/WCT.sol";
import { L2WCT } from "src/L2WCT.sol";
import { MerkleVester, IERC20 } from "src/interfaces/MerkleVester.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IPostClaimHandler } from "src/interfaces/MerkleVester.sol";
import { LockedTokenStakerStore, AllocationData } from "../stores/LockedTokenStakerStore.sol";

contract LockedTokenStakerHandler is BaseHandler {
    LockedTokenStaker public lockedTokenStaker;
    StakeWeight public stakeWeight;
    MerkleVester public vester;
    LockedTokenStakerStore public store;
    address public admin;

    constructor(
        LockedTokenStaker _lockedTokenStaker,
        StakeWeight _stakeWeight,
        MerkleVester _vester,
        LockedTokenStakerStore _store,
        address _admin,
        WCT _wct,
        L2WCT _l2wct
    )
        BaseHandler(_wct, _l2wct)
    {
        lockedTokenStaker = _lockedTokenStaker;
        stakeWeight = _stakeWeight;
        vester = _vester;
        store = _store;
        admin = _admin;
    }

    function createLockFor(
        uint256 amount,
        uint256 unlockTime,
        uint256 seed
    )
        public
        adjustTimestamp(seed)
        instrument("createLockFor")
    {
        AllocationData memory allocation;
        uint256 maxAttempts = 10;
        for (uint256 i = 0; i < maxAttempts; i++) {
            allocation = store.getRandomAllocation(seed);
            if (!store.hasLock(allocation.beneficiary) && !store.hasEverLocked(allocation.beneficiary)) {
                break;
            }
            if (i == maxAttempts - 1) {
                revert("Max attempts reached");
            }
        }

        // Bound the amount and unlock time
        uint256 maxAmount = 1e27 / 500 / 4; // Similar to StakeWeightHandler
        amount = bound(amount, 1, maxAmount);
        unlockTime = bound(unlockTime, block.timestamp + 1 weeks, block.timestamp + stakeWeight.maxLock());

        uint256 previousBalance = stakeWeight.balanceOf(allocation.beneficiary);
        StakeWeight.LockedBalance memory previousLock = stakeWeight.locks(allocation.beneficiary);

        vm.prank(allocation.beneficiary);
        lockedTokenStaker.createLockFor(
            amount,
            unlockTime,
            0, // rootIndex
            allocation.decodableArgs,
            allocation.proofs
        );

        StakeWeight.LockedBalance memory newLock = stakeWeight.locks(allocation.beneficiary);

        store.addAddressWithLock(allocation.beneficiary);
        store.updateLockedAmount(allocation.beneficiary, newLock.amount);
        store.updatePreviousBalance(allocation.beneficiary, previousBalance);
        store.updatePreviousEndTime(allocation.beneficiary, previousLock.end);
    }

    function increaseLockAmountFor(
        uint256 amount,
        uint256 seed
    )
        public
        adjustTimestamp(seed)
        instrument("increaseLockAmountFor")
    {
        AllocationData memory allocation;
        uint256 maxAttempts = 10;
        for (uint256 i = 0; i < maxAttempts; i++) {
            allocation = store.getRandomAllocation(seed);
            if (store.hasLock(allocation.beneficiary)) {
                break;
            }
            if (i == maxAttempts - 1) return;
        }

        StakeWeight.LockedBalance memory previousLock = stakeWeight.locks(allocation.beneficiary);
        uint256 previousBalance = stakeWeight.balanceOf(allocation.beneficiary);

        // Bound the amount
        uint256 minAmount = 10 * 10 ** 18;
        uint256 maxAmount = 1e27 / 500 / 4 - SafeCast.toUint256(previousLock.amount);
        amount = bound(amount, minAmount, maxAmount);

        vm.prank(allocation.beneficiary);
        lockedTokenStaker.increaseLockAmountFor(
            amount,
            0, // rootIndex
            allocation.decodableArgs,
            allocation.proofs
        );

        StakeWeight.LockedBalance memory newLock = stakeWeight.locks(allocation.beneficiary);
        int128 increasedAmount = newLock.amount - previousLock.amount;

        store.updateLockedAmount(allocation.beneficiary, increasedAmount);
        store.updatePreviousBalance(allocation.beneficiary, previousBalance);
        store.updatePreviousEndTime(allocation.beneficiary, previousLock.end);
    }

    function withdraw(uint256 claimAmount, uint256 seed) public adjustTimestamp(seed) instrument("withdraw") {
        AllocationData memory allocation = store.getRandomAllocation(seed);

        uint256 maxAmount = 1e27 / 500;
        claimAmount = bound(claimAmount, 1, maxAmount);

        bytes memory extraData = abi.encode(0, allocation.decodableArgs, allocation.proofs);

        IPostClaimHandler postClaimHandler = IPostClaimHandler(address(lockedTokenStaker));

        vm.prank(allocation.beneficiary);
        vester.withdraw(
            claimAmount,
            0, // rootIndex
            allocation.decodableArgs,
            allocation.proofs,
            postClaimHandler,
            extraData
        );

        store.updateClaimedAmount(allocation.beneficiary, claimAmount);

        StakeWeight.LockedBalance memory lockedBalance = stakeWeight.locks(allocation.beneficiary);

        if (lockedBalance.amount == 0) {
            store.removeAddressWithLock(allocation.beneficiary);
        }
    }

    function withdrawAll(uint256 seed) public adjustTimestamp(seed) instrument("withdrawAll") {
        address user = store.getRandomAddressWithLock();
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(user);

        if (lock.end > block.timestamp) {
            // Time warp to after lock expiration
            vm.warp(lock.end + 1);
        }

        vm.prank(user);
        stakeWeight.withdrawAll();

        store.updateWithdrawnAmount(user, uint256(uint128(lock.amount)));
        store.removeAddressWithLock(user);
    }
}
