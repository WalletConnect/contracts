// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Invariant_Test } from "./Invariant.t.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { Merkle } from "test/utils/Merkle.sol";
import {
    CalendarAllocation,
    Allocation,
    DistributionState,
    CalendarUnlockSchedule,
    IPostClaimHandler
} from "src/interfaces/MerkleVester.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { LockedTokenStakerStore, AllocationData } from "./stores/LockedTokenStakerStore.sol";
import { LockedTokenStakerHandler } from "./handlers/LockedTokenStakerHandler.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { console2 } from "forge-std/console2.sol";

contract LockedTokenStaker_Invariant_Test is Invariant_Test {
    LockedTokenStakerHandler public handler;
    LockedTokenStakerStore public store;
    Merkle public merkle;
    mapping(string => CalendarUnlockSchedule) public calendarSchedules;

    function setUp() public override {
        super.setUp();

        // Deploy StakeWeight store and handler
        store = new LockedTokenStakerStore();
        handler = new LockedTokenStakerHandler(lockedTokenStaker, stakeWeight, vester, store, users.admin, wct, l2wct);

        bytes32 role = stakeWeight.LOCKED_TOKEN_STAKER_ROLE();
        vm.prank(users.admin);
        stakeWeight.grantRole(role, address(lockedTokenStaker));

        merkle = new Merkle();

        // start vester
        uint256 amountToFund = 1e27; // 1 billion tokens
        vm.startPrank(users.admin);
        (,, bytes32 root) = createAllocationsAndMerkleTree("id1", true, true, false, false, amountToFund);
        vester.addAllocationRoot(root);
        vester.addPostClaimHandlerToWhitelist(IPostClaimHandler(address(lockedTokenStaker)));
        deal(address(l2wct), address(vester), amountToFund);
        vm.stopPrank();

        skip(30 days);

        vm.label(address(merkle), "Merkle");
        vm.label(address(handler), "LockedTokenStakerHandler");
        vm.label(address(store), "LockedTokenStakerStore");

        targetContract(address(handler));

        disableTransferRestrictions();

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = handler.createLockFor.selector;
        selectors[1] = handler.increaseLockAmountFor.selector;
        selectors[2] = handler.withdraw.selector;
        selectors[3] = handler.withdrawAll.selector;

        targetSelector(FuzzSelector(address(handler), selectors));
    }

    function createAllocationsAndMerkleTree(
        string memory id,
        bool cancelable,
        bool revokable,
        bool transferableByAdmin,
        bool transferableByBeneficiary,
        uint256 fundedAmount
    )
        internal
        returns (CalendarAllocation[] memory allocations, bytes32[] memory hashes, bytes32 root)
    {
        createUnlockSchedule(id);

        allocations = new CalendarAllocation[](500);

        for (uint256 i = 0; i < 500; i++) {
            address beneficiary =
                address(uint160(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, i)))));

            allocations[i] = createAllocation(
                string(abi.encodePacked("alloc", Strings.toString(i))),
                beneficiary,
                fundedAmount / 500,
                id,
                cancelable,
                revokable,
                transferableByAdmin,
                transferableByBeneficiary
            );
        }

        hashes = createHashes(allocations);
        root = merkle.getRoot(hashes);

        for (uint256 i = 0; i < allocations.length; i++) {
            if (!store.hasAllocation(allocations[i].allocation.originalBeneficiary)) {
                store.addAllocation(
                    AllocationData(
                        allocations[i].allocation.originalBeneficiary,
                        abi.encode("calendar", allocations[i].allocation, calendarSchedules[id]),
                        merkle.getProof(hashes, i)
                    )
                );
            }
        }
    }

    function createAllocation(
        string memory allocId,
        address beneficiary,
        uint256 amount,
        string memory scheduleId,
        bool cancelable,
        bool revokable,
        bool transferableByAdmin,
        bool transferableByBeneficiary
    )
        internal
        pure
        returns (CalendarAllocation memory)
    {
        return CalendarAllocation(
            Allocation(
                allocId, beneficiary, amount, cancelable, revokable, transferableByAdmin, transferableByBeneficiary
            ),
            scheduleId,
            DistributionState(beneficiary, 0, 0, 0, 0, 0)
        );
    }

    function createUnlockSchedule(string memory id) internal {
        uint32[] memory unlockTimestamps = new uint32[](4);
        uint256[] memory unlockPercents = new uint256[](4);
        uint256 fraction = 250_000; // 25% each time
        for (uint256 i = 0; i < 4; i++) {
            unlockTimestamps[i] = uint32(block.timestamp + (i + 1) * 30 days);
            unlockPercents[i] = fraction;
        }
        calendarSchedules[id] = CalendarUnlockSchedule(id, unlockTimestamps, unlockPercents);
    }

    function createHashes(CalendarAllocation[] memory allocations) internal view returns (bytes32[] memory hashes) {
        hashes = new bytes32[](allocations.length);
        for (uint256 i = 0; i < allocations.length; i++) {
            hashes[i] = vester.getCalendarLeafHash(
                "calendar", allocations[i].allocation, calendarSchedules[allocations[i].calendarUnlockScheduleId]
            );
        }
    }

    function invariant_activeStakeCannotBeWithdrawn() public view {
        address[] memory stakers = store.getAddressesWithLock();

        for (uint256 i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            StakeWeight.LockedBalance memory lock = stakeWeight.locks(staker);

            if (lock.end > block.timestamp) {
                // For active locks, ensure the allocation - withdrawn amount is not greater than the lock amount
                AllocationData memory allocation = store.getAllocation(staker);
                Allocation memory alloc =
                    vester.getLeafJustAllocationData(0, allocation.decodableArgs, allocation.proofs);
                (,,,,,, uint256 withdrawnAmount) = store.userInfo(staker);
                uint256 lockedAmount = uint256(uint128(lock.amount));
                assertGe(alloc.totalAllocation - withdrawnAmount, lockedAmount, "Withdrawn amount exceeds allocation");
            }
        }
    }

    function invariant_withdrawalAfterFirstVestingOnly() public view {
        address[] memory stakers = store.getAddressesWithLock();

        for (uint256 i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            uint256 withdrawnAmount = store.withdrawnAmount(staker);

            if (withdrawnAmount > 0) {
                AllocationData memory allocation = store.getAllocation(staker);
                (,, CalendarUnlockSchedule memory schedule) =
                    abi.decode(allocation.decodableArgs, (string, Allocation, CalendarUnlockSchedule));

                assertTrue(block.timestamp >= schedule.unlockTimestamps[0], "Withdrawal before first vesting");
            }
        }
    }

    function invariant_lockedAmountNotExceedAllocation() public view {
        address[] memory stakers = store.getAddressesWithLock();

        for (uint256 i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            int128 nonTransferableBalance = store.nonTransferableBalance();

            if (nonTransferableBalance > 0) {
                AllocationData memory allocation = store.getAllocation(staker);
                Allocation memory alloc =
                    vester.getLeafJustAllocationData(0, allocation.decodableArgs, allocation.proofs);

                assertTrue(
                    uint256(uint128(nonTransferableBalance)) <= alloc.totalAllocation,
                    "Locked amount exceeds allocation"
                );
            }
        }
    }

    function invariant_withdrawalsFollowVestingSchedule() public view {
        address[] memory stakers = store.getAddressesWithLock();

        for (uint256 i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            uint256 withdrawnAmount = store.withdrawnAmount(staker);

            if (withdrawnAmount > 0) {
                AllocationData memory allocation = store.getAllocation(staker);
                (, Allocation memory alloc, CalendarUnlockSchedule memory schedule) =
                    abi.decode(allocation.decodableArgs, (string, Allocation, CalendarUnlockSchedule));

                uint256 maxAllowedWithdrawal = _calculateVestedAmount(alloc, schedule);
                assertTrue(withdrawnAmount <= maxAllowedWithdrawal, "Withdrawal exceeds vesting schedule");
            }
        }
    }

    function invariant_terminatedAllocationsCannotLock() public view {
        address[] memory stakers = store.getAddressesWithLock();

        for (uint256 i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            StakeWeight.LockedBalance memory lock = stakeWeight.locks(staker);

            if (lock.amount > 0) {
                AllocationData memory allocation = store.getAllocation(staker);
                Allocation memory alloc =
                    vester.getLeafJustAllocationData(0, allocation.decodableArgs, allocation.proofs);

                (, uint32 terminatedTimestamp,,,,) = vester.schedules(alloc.id);
                assertTrue(terminatedTimestamp == 0, "Terminated allocation has active lock");
            }
        }
    }

    function invariant_cumulativeWithdrawalsNotExceedAllocation() public view {
        address[] memory stakers = store.getAddressesWithLock();

        for (uint256 i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            uint256 totalWithdrawn = store.withdrawnAmount(staker);
            StakeWeight.LockedBalance memory lock = stakeWeight.locks(staker);

            if (totalWithdrawn > 0 || lock.amount > 0) {
                AllocationData memory allocation = store.getAllocation(staker);
                Allocation memory alloc =
                    vester.getLeafJustAllocationData(0, allocation.decodableArgs, allocation.proofs);

                uint256 totalUsed = totalWithdrawn + uint256(uint128(lock.amount));
                assertTrue(
                    totalUsed <= alloc.totalAllocation, "Total of withdrawals and locked amount exceeds allocation"
                );
            }
        }
    }

    // Helper function to calculate vested amount based on schedule
    function _calculateVestedAmount(
        Allocation memory alloc,
        CalendarUnlockSchedule memory schedule
    )
        internal
        view
        returns (uint256)
    {
        uint256 vestedAmount = 0;
        uint256 totalPercent = 0;

        for (uint256 i = 0; i < schedule.unlockTimestamps.length; i++) {
            if (block.timestamp >= schedule.unlockTimestamps[i]) {
                totalPercent += schedule.unlockPercents[i];
            }
        }

        vestedAmount = (alloc.totalAllocation * totalPercent) / 1_000_000;
        return vestedAmount;
    }

    function afterInvariant() public {
        address[] memory users = store.getAddressesWithLock();

        // 1. Check for duplicate users
        for (uint256 i = 0; i < users.length; i++) {
            for (uint256 j = i + 1; j < users.length; j++) {
                assertNotEq(users[i], users[j], "No repeated users");
            }
        }

        // 2. Verify all allocations and locks
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            StakeWeight.LockedBalance memory lock = stakeWeight.locks(user);

            if (lock.amount > 0) {
                AllocationData memory allocation = store.getAllocation(user);
                Allocation memory alloc =
                    vester.getLeafJustAllocationData(0, allocation.decodableArgs, allocation.proofs);

                // Verify total used amount (locked + withdrawn) doesn't exceed allocation
                (,,,,,, uint256 totalUserWithdrawn) = store.userInfo(user);
                uint256 totalUsed = totalUserWithdrawn + uint256(uint128(lock.amount));
                assertLe(totalUsed, alloc.totalAllocation, "Total used exceeds allocation");

                // Verify vesting schedule compliance
                (,, CalendarUnlockSchedule memory schedule) =
                    abi.decode(allocation.decodableArgs, (string, Allocation, CalendarUnlockSchedule));
                uint256 maxAllowedWithdrawal = _calculateVestedAmount(alloc, schedule);
                assertLe(totalUserWithdrawn, maxAllowedWithdrawal, "Withdrawals exceed vesting schedule");
            }
        }

        // 3. Force expire all locks and verify withdrawals
        uint256 totalWithdrawn;
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            StakeWeight.LockedBalance memory lock = stakeWeight.locks(user);

            if (lock.amount > 0) {
                if (block.timestamp < lock.end) {
                    vm.warp(lock.end);
                }
                uint256 balanceBefore = l2wct.balanceOf(user);
                vm.prank(user);
                stakeWeight.withdrawAll();
                uint256 balanceAfter = l2wct.balanceOf(user);
                totalWithdrawn += balanceAfter - balanceBefore;
            }
        }

        // 4. Verify final state
        assertEq(stakeWeight.totalSupply(), 0, "StakeWeight should be empty after all withdrawals");

        // 5. Verify all users have no remaining locks
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            StakeWeight.LockedBalance memory lock = stakeWeight.locks(user);
            assertEq(uint256(uint128(lock.amount)), 0, "User should have no remaining locked amount");
        }

        // 6. Log test metrics
        console2.log("Total handler calls:", handler.totalCalls());
        console2.log("createLockFor calls:", handler.calls("createLockFor"));
        console2.log("increaseLockAmountFor calls:", handler.calls("increaseLockAmountFor"));
        console2.log("withdraw calls:", handler.calls("withdraw"));
        console2.log("withdrawAll calls:", handler.calls("withdrawAll"));
    }
}
