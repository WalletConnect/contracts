// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Invariant_Test } from "./Invariant.t.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { Merkle } from "test/utils/Merkle.sol";
import {
    CalendarAllocation, Allocation, DistributionState, CalendarUnlockSchedule
} from "src/interfaces/MerkleVester.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { StakeWeightHandler } from "./handlers/StakeWeightHandler.sol";
import { StakeWeightStore, AllocationData } from "./stores/StakeWeightStore.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { console2 } from "forge-std/console2.sol";

contract StakeWeight_Invariant_Test is Invariant_Test {
    StakeWeightHandler public handler;
    StakeWeightStore public store;
    Merkle public merkle;
    mapping(string => CalendarUnlockSchedule) public calendarSchedules;

    function setUp() public override {
        super.setUp();

        // Deploy StakeWeight store and handler
        store = new StakeWeightStore();
        handler = new StakeWeightHandler(stakeWeight, store, users.admin, users.manager, wct, l2wct, lockedTokenStaker);

        bytes32 role = stakeWeight.LOCKED_TOKEN_STAKER_ROLE();
        vm.prank(users.admin);
        stakeWeight.grantRole(role, address(lockedTokenStaker));

        merkle = new Merkle();

        // start vester
        uint256 amountToFund = 1e27; // 1 billion tokens
        vm.startPrank(users.admin);
        (,, bytes32 root) = createAllocationsAndMerkleTree("id1", true, true, false, false, amountToFund);
        vester.addAllocationRoot(root);
        deal(address(l2wct), address(vester), amountToFund);
        vm.stopPrank();

        skip(30 days);

        vm.label(address(merkle), "Merkle");
        vm.label(address(handler), "StakeWeightHandler");
        vm.label(address(store), "StakeWeightStore");

        targetContract(address(handler));

        disableTransferRestrictions();

        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = handler.createLock.selector;
        selectors[1] = handler.increaseLockAmount.selector;
        selectors[2] = handler.increaseUnlockTime.selector;
        selectors[3] = handler.withdrawAll.selector;
        selectors[4] = handler.checkpoint.selector;
        selectors[5] = handler.createLockFor.selector;
        selectors[6] = handler.increaseLockAmountFor.selector;
        selectors[7] = handler.forceWithdrawAll.selector;

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

    function invariant_totalSupplyConsistency() public view {
        uint256 calculatedTotalSupply = 0;
        address[] memory users = store.getAddressesWithLock();
        for (uint256 i = 0; i < users.length; i++) {
            calculatedTotalSupply += stakeWeight.balanceOf(users[i]);
        }
        assertEq(calculatedTotalSupply, stakeWeight.totalSupply(), "Total supply should equal sum of balances");
    }

    function invariant_lockTimeNeverExceedsMaxTime() public view {
        address[] memory users = store.getAddressesWithLock();
        for (uint256 i = 0; i < users.length; i++) {
            StakeWeight.LockedBalance memory lock = stakeWeight.locks(users[i]);
            if (lock.amount > 0) {
                assertLe(lock.end, block.timestamp + stakeWeight.maxLock(), "Lock time should never exceed MAXTIME");
            }
        }
    }

    function invariant_withdrawnAmountNeverExceedsLocked() public view {
        address[] memory users = store.getAddressesWithLock();
        for (uint256 i = 0; i < users.length; i++) {
            uint256 withdrawnAmount = store.withdrawnAmount(users[i]);
            int128 lockedAmount = store.userTotalLockedAmount(users[i]);
            assertLe(
                withdrawnAmount,
                SafeCast.toUint256((int256(lockedAmount))),
                "Withdrawn amount should never exceed locked amount"
            );
        }
        assertLe(
            store.totalWithdrawnAmount(),
            SafeCast.toUint256((int256(store.totalLockedAmount()))),
            "Total withdrawn amount should never exceed total locked amount"
        );
    }

    function invariant_slopeChangesConsistency() public view {
        int128 totalSlope = 0;
        for (uint256 week = block.timestamp / 1 weeks; week < block.timestamp / 1 weeks + 255; week++) {
            totalSlope += stakeWeight.slopeChanges(week);
        }
        assertEq(totalSlope, 0, "Sum of slope changes should be zero");
    }

    function invariant_userBalanceNeverExceedsLocked() public view {
        address[] memory users = store.getAddressesWithLock();
        for (uint256 i = 0; i < users.length; i++) {
            uint256 stakeWeightBalance = stakeWeight.balanceOf(users[i]);
            StakeWeight.LockedBalance memory lock = stakeWeight.locks(users[i]);
            assertLe(
                stakeWeightBalance,
                SafeCast.toUint256((int256(lock.amount))),
                "User's stakeWeight balance should never exceed their locked amount"
            );
        }
    }

    function invariant_lockExtension() public view {
        address[] memory users = store.getAddressesWithLock();
        for (uint256 i = 0; i < users.length; i++) {
            uint256 currentBalance = stakeWeight.balanceOf(users[i]);
            uint256 previousBalance = store.getPreviousBalance(users[i]);
            uint256 previousEndTime = store.getPreviousEndTime(users[i]);
            StakeWeight.LockedBalance memory lock = stakeWeight.locks(users[i]);
            if (lock.end > previousEndTime) {
                assertGe(currentBalance, previousBalance, "Lock extension should increase balance");
            }
        }
    }

    function invariant_depositIncrease() public view {
        address[] memory users = store.getAddressesWithLock();
        for (uint256 i = 0; i < users.length; i++) {
            uint256 currentBalance = stakeWeight.balanceOf(users[i]);
            uint256 previousBalance = store.getPreviousBalance(users[i]);
            StakeWeight.LockedBalance memory lock = stakeWeight.locks(users[i]);
            int128 previousAmount = store.getPreviousLockedAmount(users[i]);
            if (lock.amount > previousAmount) {
                assertGe(currentBalance, previousBalance, "Deposit should increase balance");
            }
        }
    }

    function invariant_globalSupplyConsistency() public view {
        uint256 totalSupply = stakeWeight.totalSupply();
        uint256 calculatedSupply = 0;

        address[] memory users = store.getAddressesWithLock();
        for (uint256 i = 0; i < users.length; i++) {
            calculatedSupply += stakeWeight.balanceOf(users[i]);
        }

        assertEq(totalSupply, calculatedSupply, "Total supply should equal sum of all balances");

        // Check that the current supply matches the supply at the current timestamp
        uint256 currentSupply = stakeWeight.totalSupplyAtTime(block.timestamp);
        assertEq(totalSupply, currentSupply, "Total supply should equal supply at current timestamp");
    }

    function invariant_supplyMatchesTransferredAmount() public view {
        assertEq(
            stakeWeight.supply() - SafeCast.toUint256(store.nonTransferableBalance()),
            l2wct.balanceOf(address(stakeWeight)),
            "Total supply should equal non-transferable balance"
        );
    }

    function invariant_balanceChanges() public view {
        address[] memory users = store.getAddressesWithLock();
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            uint256 currentBalance = stakeWeight.balanceOf(user);
            StakeWeight.LockedBalance memory lock = stakeWeight.locks(user);
            uint256 previousBalance = store.getPreviousBalance(user);
            uint256 previousEndTime = store.getPreviousEndTime(user);
            int128 previousLockedAmount = store.getPreviousLockedAmount(user);

            // If the lock is still active and has a non-zero amount
            if (block.timestamp < lock.end && lock.amount > 0) {
                // If the lock time was increased
                if (lock.end > previousEndTime) {
                    assertGe(
                        currentBalance,
                        previousBalance,
                        "Balance should increase or stay the same when lock time is increased"
                    );
                } else if (lock.amount > previousLockedAmount) {
                    // Lock amount was increased
                    assertGt(currentBalance, previousBalance, "Balance should increase when lock amount is increased");
                } else {
                    // No changes to lock time or amount
                    assertLe(
                        currentBalance,
                        previousBalance,
                        "Balance should decrease or stay the same over time if no changes were made"
                    );
                }
            }
        }
    }

    function invariant_withdrawalOnlyAfterExpiration() public view {
        address[] memory users = store.getAddressesWithLock();
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            uint256 withdrawnAmount = store.withdrawnAmount(user);
            StakeWeight.LockedBalance memory lock = stakeWeight.locks(user);

            if (withdrawnAmount > 0 && !store.hasBeenForcedWithdrawn(user)) {
                assertTrue(
                    block.timestamp >= lock.end,
                    "Withdrawal should only be possible after lock expiration or if re-locked"
                );
            }
        }
    }

    function afterInvariant() public {
        // 1. Calculate total value locked and total balance
        int128 totalValueLocked = 0;
        uint256 totalBalance = 0;
        address[] memory users = store.getAddressesWithLock();
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            StakeWeight.LockedBalance memory lock = stakeWeight.locks(user);
            totalValueLocked += lock.amount;
            totalBalance += stakeWeight.balanceOf(user);
        }

        // check no repeated users
        for (uint256 i = 0; i < users.length; i++) {
            for (uint256 j = i + 1; j < users.length; j++) {
                assertNotEq(users[i], users[j], "No repeated users");
            }
        }

        assertEq(
            totalValueLocked, store.currentLockedAmount(), "Total value locked should equal the stored locked amount"
        );
        assertEq(
            SafeCast.toUint256(totalValueLocked) - SafeCast.toUint256(store.nonTransferableBalance()),
            l2wct.balanceOf(address(stakeWeight)),
            "Total value locked should equal the held tokens"
        );

        // 2. Perform withdrawals for all users (waiting for lock expiration)
        uint256 totalWithdrawn = 0;
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            StakeWeight.LockedBalance memory lock = stakeWeight.locks(user);
            if (block.timestamp < lock.end) {
                vm.warp(lock.end);
            }
            uint256 balanceBefore = l2wct.balanceOf(user);
            resetPrank(user);
            stakeWeight.withdrawAll();
            vm.stopPrank();
            uint256 balanceAfter = l2wct.balanceOf(user);
            totalWithdrawn += balanceAfter - balanceBefore;
        }

        // 3. Assert contract is emptied
        assertEq(stakeWeight.totalSupply(), 0, "StakeWeight should be empty after all withdrawals");
        assertEq(l2wct.balanceOf(address(stakeWeight)), 0, "StakeWeight contract should have no L2WCT balance");

        // 4. Assert total withdrawn matches total value locked (within rounding error)
        uint256 roundingError = 1e6; // Allow for some rounding error
        assertApproxEqAbs(
            SafeCast.toUint256(totalValueLocked) - SafeCast.toUint256(store.nonTransferableBalance()),
            totalWithdrawn,
            roundingError,
            "Total withdrawn should match total value locked minus non-transferable balance"
        );

        // 5. Assert total balance was lower than total value locked
        if (totalValueLocked > 0) {
            assertLt(
                totalBalance,
                SafeCast.toUint256(totalValueLocked),
                "Total balance should be lower than total value locked"
            );
        } else {
            assertEq(totalValueLocked, 0, "Total value locked should be zero");
            assertEq(totalBalance, 0, "Total balance should be zero if total value locked is zero");
        }

        // 6. Check for any remaining locks
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            StakeWeight.LockedBalance memory lock = stakeWeight.locks(user);
            assertEq(uint256(uint128(lock.amount)), 0, "User should have no remaining locked amount");
            assertEq(stakeWeight.balanceOf(user), 0, "User should have no remaining balance");
        }

        // 7. Verify total supply consistency
        assertEq(stakeWeight.totalSupply(), 0, "Total supply should be zero after all withdrawals");

        // 8. Log campaign metrics
        console2.log("Total calls made during invariant test:", handler.totalCalls());
        console2.log("createLock calls:", handler.calls("createLock"));
        console2.log("increaseLockAmount calls:", handler.calls("increaseLockAmount"));
        console2.log("increaseUnlockTime calls:", handler.calls("increaseUnlockTime"));
        console2.log("withdrawAll calls:", handler.calls("withdrawAll"));
        console2.log("checkpoint calls:", handler.calls("checkpoint"));
        console2.log("createLockFor calls:", handler.calls("createLockFor"));
        console2.log("increaseLockAmountFor calls:", handler.calls("increaseLockAmountFor"));
        console2.log("increaseUnlockTimeFor calls:", handler.calls("increaseUnlockTimeFor"));
        console2.log("withdrawAllFor calls:", handler.calls("withdrawAllFor"));
    }
}
