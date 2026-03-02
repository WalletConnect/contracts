// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { StakeWeight_Integration_Shared_Test } from "test/integration/shared/StakeWeight.t.sol";
import { OldPermanentLockStakeWeight } from "src/OldPermanentLockStakeWeight.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { console2 } from "forge-std/console2.sol";

/**
 * @title UpdatePermanentLockBug_Test
 * @notice This test demonstrates a critical bug in updatePermanentLock and increasePermanentLockDuration
 *
 * THE BUG:
 * Both functions set userPermanentWeightAtEpoch[userEpoch] BEFORE calling _checkpoint.
 * The _checkpoint call creates a NEW epoch (N+1), but the permanent weight was set at epoch N.
 * This leaves epoch N+1 with permanentWeight = 0, causing users to receive 0 rewards.
 *
 * This test uses OldPermanentLockStakeWeight (old code) to demonstrate the bug exists,
 * and compares against the fixed StakeWeight to show the fix works.
 */
contract UpdatePermanentLockBug_Test is StakeWeight_Integration_Shared_Test {
    address alice = address(0x1);
    address bob = address(0x2);

    // The old version of StakeWeight for demonstrating the bug
    OldPermanentLockStakeWeight public oldStakeWeight;

    function setUp() public virtual override {
        super.setUp();

        // Disable transfer restrictions for testing
        vm.prank(users.admin);
        l2wct.disableTransferRestrictions();

        // Deploy buggy StakeWeight for bug demonstration
        OldPermanentLockStakeWeight oldImpl = new OldPermanentLockStakeWeight();
        ERC1967Proxy oldProxy = new ERC1967Proxy(
            address(oldImpl),
            abi.encodeCall(
                OldPermanentLockStakeWeight.initialize,
                OldPermanentLockStakeWeight.Init({ admin: users.admin, config: address(walletConnectConfig) })
            )
        );
        oldStakeWeight = OldPermanentLockStakeWeight(address(oldProxy));

        // Give test users tokens
        deal(address(l2wct), alice, 100_000e18);
        deal(address(l2wct), bob, 100_000e18);
    }

    /*//////////////////////////////////////////////////////////////////////////
                        BUG DEMONSTRATION (using OldPermanentLockStakeWeight)
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Demonstrates the bug in updatePermanentLock
     */
    function test_BUG_UpdatePermanentLockSetsWeightAtWrongEpoch() public {
        uint256 initialAmount = 1000e18;
        uint256 additionalAmount = 500e18;
        uint256 duration = 52 weeks;

        // Step 1: Create permanent lock (works correctly)
        vm.startPrank(alice);
        l2wct.approve(address(oldStakeWeight), type(uint256).max);
        oldStakeWeight.createPermanentLock(initialAmount, duration);
        vm.stopPrank();

        uint256 epochAfterCreate = oldStakeWeight.userPointEpoch(alice);
        uint256 weightAfterCreate = oldStakeWeight.userPermanentAt(alice, epochAfterCreate);

        console2.log("=== OldPermanentLockStakeWeight: After createPermanentLock ===");
        console2.log("User epoch:", epochAfterCreate);
        console2.log("Weight at epoch:", weightAfterCreate);

        assertGt(weightAfterCreate, 0, "createPermanentLock correctly sets weight");

        // Step 2: Call updatePermanentLock - THIS TRIGGERS THE BUG
        vm.startPrank(alice);
        oldStakeWeight.updatePermanentLock(additionalAmount, duration);
        vm.stopPrank();

        uint256 epochAfterUpdate = oldStakeWeight.userPointEpoch(alice);
        uint256 weightAfterUpdate = oldStakeWeight.userPermanentAt(alice, epochAfterUpdate);

        console2.log("\n=== OldPermanentLockStakeWeight: After updatePermanentLock ===");
        console2.log("User epoch:", epochAfterUpdate);
        console2.log("Weight at NEW epoch:", weightAfterUpdate);

        // THE BUG: New epoch has 0 weight!
        assertGt(epochAfterUpdate, epochAfterCreate, "Epoch should increase");
        assertEq(weightAfterUpdate, 0, "BUG CONFIRMED: Weight at new epoch is 0");

        // Old epoch still has weight (stale data)
        uint256 weightAtOldEpoch = oldStakeWeight.userPermanentAt(alice, epochAfterCreate);
        console2.log("Weight at OLD epoch:", weightAtOldEpoch);
        assertGt(weightAtOldEpoch, 0, "Old epoch has stale weight");
    }

    /**
     * @notice Demonstrates the bug in increasePermanentLockDuration
     */
    function test_BUG_IncreasePermanentLockDurationSetsWeightAtWrongEpoch() public {
        uint256 amount = 1000e18;
        uint256 initialDuration = 26 weeks;
        uint256 newDuration = 52 weeks;

        // Step 1: Create permanent lock
        vm.startPrank(alice);
        l2wct.approve(address(oldStakeWeight), type(uint256).max);
        oldStakeWeight.createPermanentLock(amount, initialDuration);
        vm.stopPrank();

        uint256 epochAfterCreate = oldStakeWeight.userPointEpoch(alice);
        uint256 weightAfterCreate = oldStakeWeight.userPermanentAt(alice, epochAfterCreate);

        assertGt(weightAfterCreate, 0, "createPermanentLock correctly sets weight");

        // Step 2: Increase duration - THIS TRIGGERS THE BUG
        vm.startPrank(alice);
        oldStakeWeight.increasePermanentLockDuration(newDuration);
        vm.stopPrank();

        uint256 epochAfterIncrease = oldStakeWeight.userPointEpoch(alice);
        uint256 weightAfterIncrease = oldStakeWeight.userPermanentAt(alice, epochAfterIncrease);

        console2.log("=== OldPermanentLockStakeWeight: increasePermanentLockDuration ===");
        console2.log("Epoch after create:", epochAfterCreate);
        console2.log("Epoch after increase:", epochAfterIncrease);
        console2.log("Weight at new epoch:", weightAfterIncrease);

        // THE BUG: New epoch has 0 weight!
        assertGt(epochAfterIncrease, epochAfterCreate, "Epoch should increase");
        assertEq(weightAfterIncrease, 0, "BUG CONFIRMED: Weight at new epoch is 0");
    }

    /**
     * @notice Shows checkpoint() doesn't heal the bug
     */
    function test_BUG_CheckpointDoesNotHeal() public {
        uint256 amount = 1000e18;
        uint256 duration = 52 weeks;

        // Create and trigger bug
        vm.startPrank(alice);
        l2wct.approve(address(oldStakeWeight), type(uint256).max);
        oldStakeWeight.createPermanentLock(amount, duration);
        oldStakeWeight.updatePermanentLock(500e18, duration);
        vm.stopPrank();

        uint256 epochAfterBug = oldStakeWeight.userPointEpoch(alice);
        uint256 weightAfterBug = oldStakeWeight.userPermanentAt(alice, epochAfterBug);
        assertEq(weightAfterBug, 0, "Bug confirmed");

        // Try checkpoint - doesn't help
        oldStakeWeight.checkpoint();

        uint256 epochAfterCheckpoint = oldStakeWeight.userPointEpoch(alice);
        uint256 weightAfterCheckpoint = oldStakeWeight.userPermanentAt(alice, epochAfterCheckpoint);

        // User epoch doesn't change from global checkpoint
        assertEq(epochAfterCheckpoint, epochAfterBug, "User epoch unchanged by global checkpoint");
        assertEq(weightAfterCheckpoint, 0, "Weight still 0 after checkpoint");
    }

    /**
     * @notice Shows increaseLockAmount reverted in old version for permanent locks
     */
    function test_BUG_IncreaseLockAmountRevertedForPermanentLocks() public {
        uint256 amount = 1000e18;
        uint256 duration = 52 weeks;

        vm.startPrank(alice);
        l2wct.approve(address(oldStakeWeight), type(uint256).max);
        oldStakeWeight.createPermanentLock(amount, duration);

        // In old version, increaseLockAmount reverts for permanent locks (end = 0)
        vm.expectRevert(abi.encodeWithSelector(OldPermanentLockStakeWeight.ExpiredLock.selector, block.timestamp, 0));
        oldStakeWeight.increaseLockAmount(100e18);
        vm.stopPrank();
    }

    /**
     * @notice Demonstrates globalPermanentSupplyAtEpoch is retroactively overwritten in old version
     * @dev The old code sets globalPermanentSupplyAtEpoch[OLD epoch] = NEW supply BEFORE checkpoint,
     *      which retroactively inflates the old epoch's global supply.
     */
    function test_BUG_GlobalPermanentSupplyRetroactivelyOverwritten() public {
        uint256 initialAmount = 1000e18;
        uint256 additionalAmount = 500e18;
        uint256 duration = 52 weeks;

        // Step 1: Create permanent lock
        vm.startPrank(alice);
        l2wct.approve(address(oldStakeWeight), type(uint256).max);
        oldStakeWeight.createPermanentLock(initialAmount, duration);
        vm.stopPrank();

        // Record global epoch and supply after create
        uint256 globalEpochAfterCreate = oldStakeWeight.epoch();
        uint256 globalSupplyAfterCreate = oldStakeWeight.permanentSupplyByEpoch(globalEpochAfterCreate);

        console2.log("=== OldPermanentLockStakeWeight: globalPermanentSupplyAtEpoch Bug ===");
        console2.log("Global epoch after create:", globalEpochAfterCreate);
        console2.log("Global supply at epoch (after create):", globalSupplyAfterCreate);

        // Step 2: Call updatePermanentLock - triggers the bug
        vm.startPrank(alice);
        oldStakeWeight.updatePermanentLock(additionalAmount, duration);
        vm.stopPrank();

        uint256 globalEpochAfterUpdate = oldStakeWeight.epoch();

        // Check the OLD epoch's supply - it should have been overwritten!
        uint256 oldEpochSupplyNow = oldStakeWeight.permanentSupplyByEpoch(globalEpochAfterCreate);
        uint256 newEpochSupply = oldStakeWeight.permanentSupplyByEpoch(globalEpochAfterUpdate);

        console2.log("Global epoch after update:", globalEpochAfterUpdate);
        console2.log("OLD epoch supply (retroactively changed!):", oldEpochSupplyNow);
        console2.log("NEW epoch supply:", newEpochSupply);

        // BUG: The old epoch's supply was retroactively overwritten to the new (higher) value
        // This happens because line 1388 in old code: globalPermanentSupplyAtEpoch[pointHistory.length - 1] =
        // permanentTotalSupply runs BEFORE checkpoint, overwriting the old epoch's value
        assertGt(globalEpochAfterUpdate, globalEpochAfterCreate, "Global epoch should increase");
        assertGt(oldEpochSupplyNow, globalSupplyAfterCreate, "BUG: Old epoch supply retroactively inflated");
        assertEq(oldEpochSupplyNow, newEpochSupply, "BUG: Old and new epoch have same supply (retroactive overwrite)");
    }

    /*//////////////////////////////////////////////////////////////////////////
                        FIX VERIFICATION (using fixed StakeWeight)
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies updatePermanentLock is fixed
     */
    function test_FIXED_UpdatePermanentLockSetsWeightAtCorrectEpoch() public {
        uint256 initialAmount = 1000e18;
        uint256 additionalAmount = 500e18;
        uint256 duration = 52 weeks;

        // Use fixed stakeWeight
        vm.startPrank(bob);
        l2wct.approve(address(stakeWeight), type(uint256).max);
        stakeWeight.createPermanentLock(initialAmount, duration);

        uint256 epochAfterCreate = stakeWeight.userPointEpoch(bob);
        uint256 weightAfterCreate = stakeWeight.userPermanentAt(bob, epochAfterCreate);

        stakeWeight.updatePermanentLock(additionalAmount, duration);
        vm.stopPrank();

        uint256 epochAfterUpdate = stakeWeight.userPointEpoch(bob);
        uint256 weightAfterUpdate = stakeWeight.userPermanentAt(bob, epochAfterUpdate);

        // Check old epoch weight is PRESERVED (not retroactively inflated)
        uint256 oldEpochWeightAfterUpdate = stakeWeight.userPermanentAt(bob, epochAfterCreate);

        console2.log("=== Fixed StakeWeight: updatePermanentLock ===");
        console2.log("Epoch after create:", epochAfterCreate);
        console2.log("Epoch after update:", epochAfterUpdate);
        console2.log("Weight at OLD epoch (should be unchanged):", oldEpochWeightAfterUpdate);
        console2.log("Weight at NEW epoch:", weightAfterUpdate);

        // FIXED: New epoch has correct weight
        assertGt(epochAfterUpdate, epochAfterCreate, "Epoch should increase");
        assertGt(weightAfterUpdate, 0, "FIX VERIFIED: Weight at new epoch is non-zero");
        assertGt(weightAfterUpdate, weightAfterCreate, "Weight should increase with more tokens");

        // FIXED: Old epoch is NOT retroactively inflated
        assertEq(oldEpochWeightAfterUpdate, weightAfterCreate, "FIX VERIFIED: Old epoch weight unchanged");
    }

    /**
     * @notice Verifies increasePermanentLockDuration is fixed
     */
    function test_FIXED_IncreasePermanentLockDurationSetsWeightAtCorrectEpoch() public {
        uint256 amount = 1000e18;
        uint256 initialDuration = 26 weeks;
        uint256 newDuration = 52 weeks;

        vm.startPrank(bob);
        l2wct.approve(address(stakeWeight), type(uint256).max);
        stakeWeight.createPermanentLock(amount, initialDuration);

        uint256 epochAfterCreate = stakeWeight.userPointEpoch(bob);
        uint256 weightAfterCreate = stakeWeight.userPermanentAt(bob, epochAfterCreate);

        stakeWeight.increasePermanentLockDuration(newDuration);
        vm.stopPrank();

        uint256 epochAfterIncrease = stakeWeight.userPointEpoch(bob);
        uint256 weightAfterIncrease = stakeWeight.userPermanentAt(bob, epochAfterIncrease);

        console2.log("=== Fixed StakeWeight: increasePermanentLockDuration ===");
        console2.log("Epoch after create:", epochAfterCreate);
        console2.log("Epoch after increase:", epochAfterIncrease);
        console2.log("Weight at new epoch:", weightAfterIncrease);

        // FIXED: New epoch has correct weight
        assertGt(epochAfterIncrease, epochAfterCreate, "Epoch should increase");
        assertGt(weightAfterIncrease, 0, "FIX VERIFIED: Weight at new epoch is non-zero");
        assertGt(weightAfterIncrease, weightAfterCreate, "Weight should increase with longer duration");
    }

    /**
     * @notice Verifies globalPermanentSupplyAtEpoch is correctly preserved in fixed version
     * @dev The fix ensures old epoch keeps its original supply, and only new epoch gets updated supply
     */
    function test_FIXED_GlobalPermanentSupplyNotRetroactivelyOverwritten() public {
        uint256 initialAmount = 1000e18;
        uint256 additionalAmount = 500e18;
        uint256 duration = 52 weeks;

        // Step 1: Create permanent lock
        vm.startPrank(bob);
        l2wct.approve(address(stakeWeight), type(uint256).max);
        stakeWeight.createPermanentLock(initialAmount, duration);
        vm.stopPrank();

        // Record global epoch and supply after create
        uint256 globalEpochAfterCreate = stakeWeight.epoch();
        uint256 globalSupplyAfterCreate = stakeWeight.permanentSupplyByEpoch(globalEpochAfterCreate);

        console2.log("=== Fixed StakeWeight: globalPermanentSupplyAtEpoch ===");
        console2.log("Global epoch after create:", globalEpochAfterCreate);
        console2.log("Global supply at epoch (after create):", globalSupplyAfterCreate);

        // Step 2: Call updatePermanentLock
        vm.startPrank(bob);
        stakeWeight.updatePermanentLock(additionalAmount, duration);
        vm.stopPrank();

        uint256 globalEpochAfterUpdate = stakeWeight.epoch();

        // Check the OLD epoch's supply - should be UNCHANGED in fixed version
        uint256 oldEpochSupplyNow = stakeWeight.permanentSupplyByEpoch(globalEpochAfterCreate);
        uint256 newEpochSupply = stakeWeight.permanentSupplyByEpoch(globalEpochAfterUpdate);

        console2.log("Global epoch after update:", globalEpochAfterUpdate);
        console2.log("OLD epoch supply (should be unchanged):", oldEpochSupplyNow);
        console2.log("NEW epoch supply:", newEpochSupply);

        // FIX VERIFIED: Old epoch keeps its original supply, new epoch has updated supply
        assertGt(globalEpochAfterUpdate, globalEpochAfterCreate, "Global epoch should increase");
        assertEq(oldEpochSupplyNow, globalSupplyAfterCreate, "FIX: Old epoch supply unchanged");
        assertGt(newEpochSupply, oldEpochSupplyNow, "FIX: New epoch has higher supply");
    }
}
