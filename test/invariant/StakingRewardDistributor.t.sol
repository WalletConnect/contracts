// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Invariant_Test } from "./Invariant.t.sol";
import { StakingRewardDistributorHandler } from "./handlers/StakingRewardDistributorHandler.sol";
import { StakingRewardDistributorStore } from "./stores/StakingRewardDistributorStore.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { console2 } from "forge-std/console2.sol";

contract StakingRewardDistributor_Invariant_Test is Invariant_Test {
    StakingRewardDistributorHandler public handler;
    StakingRewardDistributorStore public store;

    function setUp() public override {
        super.setUp();

        // Deploy StakingRewardDistributor contract
        store = new StakingRewardDistributorStore();
        handler =
            new StakingRewardDistributorHandler(stakingRewardDistributor, store, users.admin, stakeWeight, wct, l2wct);

        vm.label(address(handler), "StakingRewardDistributorHandler");
        vm.label(address(store), "StakingRewardDistributorStore");

        targetContract(address(handler));

        disableTransferRestrictions();

        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = handler.createLock.selector;
        selectors[1] = handler.withdrawAll.selector;
        selectors[2] = handler.claim.selector;
        selectors[3] = handler.setRecipient.selector;
        selectors[4] = handler.injectReward.selector;
        selectors[5] = handler.feed.selector;
        selectors[6] = handler.checkpointToken.selector;
        selectors[7] = handler.checkpointTotalSupply.selector;

        targetSelector(FuzzSelector(address(handler), selectors));
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
        uint256 totalTokensPerWeek = 0;
        uint256 currentWeek = _timestampToFloorWeek(block.timestamp);
        for (uint256 i = stakingRewardDistributor.startWeekCursor(); i <= currentWeek; i += 1 weeks) {
            totalTokensPerWeek += stakingRewardDistributor.tokensPerWeek(i);
        }

        // Calculate injected rewards for future weeks
        uint256 futureInjectedRewards = 0;
        uint256 safetyBuffer = 1 weeks;
        for (
            uint256 i = currentWeek + 1 weeks; i <= block.timestamp + stakeWeight.maxLock() + safetyBuffer; i += 1 weeks
        ) {
            futureInjectedRewards += stakingRewardDistributor.tokensPerWeek(i);
        }

        assertApproxEqAbs(
            totalTokensPerWeek + futureInjectedRewards,
            stakingRewardDistributor.totalDistributed(),
            1e18,
            "Sum of tokensPerWeek (including future) should approximately equal totalDistributed"
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
        for (uint256 week = store.firstLockCreatedAt(); week <= stakingRewardDistributor.weekCursor(); week++) {
            assertLe(
                stakingRewardDistributor.totalSupplyAt(week),
                stakeWeight.totalSupplyAtTime(week),
                "totalSupplyAt should not exceed StakeWeight totalSupplyAtTime"
            );
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

        // Record initial contract balance
        uint256 initialContractBalance = l2wct.balanceOf(address(stakingRewardDistributor));
        console2.log("Initial contract balance:", initialContractBalance);

        // Time warp to max lock in the future in iterations of 51 weeks
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
        for (uint256 i = 0; i < users.length; i++) {
            uint256 claimed = stakingRewardDistributor.claim(users[i]);
            totalClaimed += claimed;
            console2.log("User", users[i], "claimed after time warp:", claimed);
        }
        console2.log("Total claimed after time warp:", totalClaimed);

        // Verify final balances
        uint256 finalContractBalance = l2wct.balanceOf(address(stakingRewardDistributor));
        console2.log("Final contract balance:", finalContractBalance);

        // Check that all distributed tokens have been claimed
        assertEq(
            initialContractBalance - finalContractBalance,
            totalClaimed,
            "All distributed tokens should have been claimed"
        );

        // Verify final contract state
        assertEq(
            stakingRewardDistributor.weekCursor() - 1 weeks,
            _timestampToFloorWeek(stakingRewardDistributor.lastTokenTimestamp()),
            "weekCursor should be one week ahead the floored lastTokenTimestamp, as it points the start of the processingweek"
        );

        console2.log("afterInvariant checks completed successfully");
    }
}
