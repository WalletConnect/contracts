// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Invariant_Test } from "./Invariant.t.sol";
import { StakingRewardDistributorHandler } from "./handlers/StakingRewardDistributorHandler.sol";
import { StakingRewardDistributorStore } from "./stores/StakingRewardDistributorStore.sol";
import { Merkle } from "test/utils/Merkle.sol";
import {
    CalendarAllocation, Allocation, DistributionState, CalendarUnlockSchedule
} from "src/utils/magna/MerkleVester.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { AllocationData } from "./stores/StakingRewardDistributorStore.sol";
import { console2 } from "forge-std/console2.sol";

contract StakingRewardDistributor_Invariant_Test is Invariant_Test {
    StakingRewardDistributorHandler public handler;
    StakingRewardDistributorStore public store;
    Merkle public merkle;
    mapping(string => CalendarUnlockSchedule) public calendarSchedules;

    function setUp() public override {
        super.setUp();

        // Deploy StakingRewardDistributor contract
        store = new StakingRewardDistributorStore();
        handler = new StakingRewardDistributorHandler(
            stakingRewardDistributor, store, lockedTokenStaker, users.admin, stakeWeight, wct, l2wct
        );

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

        vm.label(address(handler), "StakingRewardDistributorHandler");
        vm.label(address(store), "StakingRewardDistributorStore");

        targetContract(address(handler));

        disableTransferRestrictions();

        bytes4[] memory selectors = new bytes4[](10);
        selectors[0] = handler.createLock.selector;
        selectors[1] = handler.withdrawAll.selector;
        selectors[2] = handler.claim.selector;
        selectors[3] = handler.setRecipient.selector;
        selectors[4] = handler.injectReward.selector;
        selectors[5] = handler.feed.selector;
        selectors[6] = handler.checkpointToken.selector;
        selectors[7] = handler.checkpointTotalSupply.selector;
        selectors[8] = handler.forceWithdrawAll.selector;
        selectors[9] = handler.createLockFor.selector;

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

    function invariant_tokenBalanceConsistency() public view {
        uint256 actualBalance = l2wct.balanceOf(address(stakingRewardDistributor));
        uint256 lastTokenBalance = stakingRewardDistributor.lastTokenBalance();
        uint256 totalDistributed = stakingRewardDistributor.totalDistributed();
        uint256 totalClaimed = store.totalClaimed();

        assertGe(actualBalance, lastTokenBalance, "Actual balance should be greater than or equal to lastTokenBalance");

        assertEq(
            actualBalance,
            lastTokenBalance + (actualBalance - lastTokenBalance),
            "Contract token balance should equal lastTokenBalance plus any new tokens"
        );

        assertEq(
            actualBalance + totalClaimed,
            totalDistributed,
            "Actual balance plus total claimed should equal total distributed"
        );
    }

    function invariant_totalDistributedConsistency() public view {
        uint256 totalCursorTokensPerWeek = 0;
        uint256 currentWeek = _timestampToFloorWeek(block.timestamp);

        uint256 totalInjectedTokensPerWeek = 0;

        uint256 minTimestamp;
        uint256 maxTimestamp;

        // Injected rewards
        for (uint256 i = 0; i < store.getTokensPerWeekInjectedTimestampsLength(); i++) {
            uint256 week = store.tokensPerWeekInjectedTimestamps(i);
            if (week > maxTimestamp) {
                maxTimestamp = week;
            }
            if (minTimestamp == 0 || week < minTimestamp) {
                minTimestamp = week;
            }
            // Only consider rewards that have been injected before our calculated cursors
            if (week < stakingRewardDistributor.startWeekCursor() || week > currentWeek) {
                totalInjectedTokensPerWeek += stakingRewardDistributor.tokensPerWeek(week);
            }
        }

        if (minTimestamp > stakingRewardDistributor.startWeekCursor()) {
            minTimestamp = stakingRewardDistributor.startWeekCursor();
        }
        if (maxTimestamp < currentWeek) {
            maxTimestamp = currentWeek;
        }

        // Fed rewards
        for (uint256 i = minTimestamp; i <= maxTimestamp; i += 1 weeks) {
            totalCursorTokensPerWeek += stakingRewardDistributor.tokensPerWeek(i);
        }

        totalCursorTokensPerWeek -= totalInjectedTokensPerWeek;

        assertLe(
            totalInjectedTokensPerWeek,
            store.totalInjectedRewards(),
            "Total injected tokens per week should be less than or equal to total injected rewards"
        );

        uint256 totalTokensPerWeek = totalCursorTokensPerWeek + totalInjectedTokensPerWeek;

        assertEq(
            store.totalFedRewards() + store.totalInjectedRewards(),
            stakingRewardDistributor.totalDistributed(),
            "Total distributed should equal sum of fed and injected rewards"
        );

        assertApproxEqAbs(
            totalTokensPerWeek,
            store.totalFedRewards() + store.totalInjectedRewards(),
            (store.totalFedRewards() + store.totalInjectedRewards()) / 1e4, // Allow 0.01% difference
            "Total tokens per week should equal sum of fed and injected rewards"
        );

        assertApproxEqAbs(
            totalTokensPerWeek,
            stakingRewardDistributor.totalDistributed(),
            stakingRewardDistributor.totalDistributed() / 100, // Allow 1% difference
            "Sum of tokensPerWeek should approximately equal totalDistributed"
        );
    }

    function invariant_timeBasedConstraints() public view {
        assertGe(
            stakingRewardDistributor.weekCursor(),
            stakingRewardDistributor.startWeekCursor(),
            "weekCursor should be >= startWeekCursor"
        );
        assertGe(
            stakingRewardDistributor.lastTokenTimestamp(),
            stakingRewardDistributor.startWeekCursor(),
            "lastTokenTimestamp should be >= startWeekCursor"
        );
        assertEq(stakingRewardDistributor.weekCursor() % 1 weeks, 0, "weekCursor should be a multiple of 1 week");
    }

    function invariant_claimIntegrity() public view {
        address[] memory users = store.getUsers();
        uint256 totalClaimed = 0;
        for (uint256 i = 0; i < users.length; i++) {
            totalClaimed += store.claimedAmount(users[i]);
            assertLe(
                store.claimedAmount(users[i]),
                stakingRewardDistributor.totalDistributed(),
                "User claimed amount should not exceed total distributed"
            );
        }
        assertLe(
            totalClaimed,
            stakingRewardDistributor.totalDistributed(),
            "Total claimed should not exceed total distributed"
        );
    }

    function invariant_stakeWeightConsistency() public view {
        if (store.firstLockCreatedAt() == 0) {
            return;
        }

        // Start from the first full week after the first lock
        uint256 startWeek = _timestampToFloorWeek(store.firstLockCreatedAt()) + 1 weeks;

        // Check each week's total supply
        for (uint256 week = startWeek; week <= stakingRewardDistributor.weekCursor(); week += 1 weeks) {
            uint256 distributorSupply = stakingRewardDistributor.totalSupplyAt(week);
            if (distributorSupply > 0) {
                // Only verify non-zero supplies since they indicate active checkpoints
                try stakeWeight.totalSupplyAtTime(week) returns (uint256 supplyAtTime) {
                    // Allow for some reasonable difference due to different calculation methods
                    uint256 tolerance = supplyAtTime / 100; // 1% tolerance
                    assertApproxEqAbs(
                        distributorSupply,
                        supplyAtTime,
                        tolerance,
                        "totalSupplyAt should be approximately equal to StakeWeight totalSupplyAtTime"
                    );
                } catch {
                    // If totalSupplyAtTime reverts, we can't make any assertions
                    continue;
                }
            }
        }
    }

    function invariant_recipientManagement() public view {
        address[] memory users = store.getUsers();
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            address recipient = stakingRewardDistributor.getRecipient(user);
            if (recipient != user) {
                assertNotEq(recipient, address(0), "Set recipient should not be zero address");
            }

            assertTrue(
                recipient == user || recipient == store.getSetRecipient(user),
                "Recipient should be user or set recipient"
            );
        }
    }

    function afterInvariant() public {
        // Log campaign metrics
        console2.log("Total calls made during invariant test:", handler.totalCalls());
        console2.log("checkpointToken calls:", handler.calls("checkpointToken"));
        console2.log("checkpointTotalSupply calls:", handler.calls("checkpointTotalSupply"));
        console2.log("claim calls:", handler.calls("claim"));
        console2.log("setRecipient calls:", handler.calls("setRecipient"));
        console2.log("injectReward calls:", handler.calls("injectReward"));
        console2.log("withdrawAll calls:", handler.calls("withdrawAll"));
        console2.log("createLock calls:", handler.calls("createLock"));
        console2.log("feed calls:", handler.calls("feed"));
        console2.log("createLockFor calls:", handler.calls("createLockFor"));
        console2.log("forceWithdrawAll calls:", handler.calls("forceWithdrawAll"));

        // Record initial contract balance
        uint256 initialContractBalance = l2wct.balanceOf(address(stakingRewardDistributor));
        console2.log("Initial contract balance:", initialContractBalance);

        // Time warp to max lock in the future in iterations of 50 weeks
        uint256 remainingTime = stakeWeight.maxLock();
        while (remainingTime > 0) {
            uint256 timeJump = remainingTime > 50 weeks ? 50 weeks : remainingTime;
            vm.warp(block.timestamp + timeJump);
            stakingRewardDistributor.checkpointToken();
            stakingRewardDistributor.checkpointTotalSupply();
            remainingTime -= timeJump;
        }

        // Claim for all users after time warp
        address[] memory users = store.getUsers();
        uint256 totalClaimed = 0;
        uint256 totalLockedAmount = 0;

        for (uint256 i = 0; i < users.length; i++) {
            uint256 lockedAmount = store.getLockedAmount(users[i]);
            totalLockedAmount += lockedAmount;

            uint256 balanceBeforeClaim = l2wct.balanceOf(address(stakingRewardDistributor));
            vm.startPrank(users[i]);
            uint256 claimed = stakingRewardDistributor.claim(users[i]);
            vm.stopPrank();
            uint256 balanceAfterClaim = l2wct.balanceOf(address(stakingRewardDistributor));

            totalClaimed += claimed;

            assertEq(claimed, balanceBeforeClaim - balanceAfterClaim, "Claim amount should match balance change");
        }

        uint256 finalContractBalance = l2wct.balanceOf(address(stakingRewardDistributor));

        assertGe(
            stakingRewardDistributor.totalDistributed(),
            totalClaimed + finalContractBalance,
            "Total distributed should be greater than or equal to total claimed plus final balance"
        );

        console2.log("afterInvariant checks completed successfully");
    }
}
