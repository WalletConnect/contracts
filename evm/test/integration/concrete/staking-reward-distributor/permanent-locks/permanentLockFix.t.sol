// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { StakeWeight_Integration_Shared_Test } from "test/integration/shared/StakeWeight.t.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { StakeWeightHealer } from "src/StakeWeightHealer.sol";
import { Eip1967Logger } from "script/utils/Eip1967Logger.sol";
import { console2 } from "forge-std/console2.sol";

/**
 * @title PermanentLockFix_Test
 * @notice Tests verifying the fixes for the permanent lock reward bug
 *
 * FIXES VERIFIED:
 * 1. updatePermanentLock now sets weight at NEW epoch (after checkpoint)
 * 2. increasePermanentLockDuration now sets weight at NEW epoch (after checkpoint)
 * 3. batchHealPermanentWeights allows admin to batch heal users
 */
contract PermanentLockFix_Test is StakeWeight_Integration_Shared_Test {
    address alice = address(0x1);
    address bob = address(0x2);

    // ERC1967 implementation slot
    bytes32 internal constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    function setUp() public virtual override {
        super.setUp();

        vm.prank(users.admin);
        l2wct.disableTransferRestrictions();

        deal(address(l2wct), alice, 100_000e18);
        deal(address(l2wct), bob, 100_000e18);
    }

    /// @notice Simulates upgrading to StakeWeightHealer by setting implementation slot
    function _upgradeToHealer() internal returns (StakeWeightHealer healer, address oldImpl) {
        // Store old implementation using Eip1967Logger
        oldImpl = Eip1967Logger.getImplementation(vm, address(stakeWeight));

        // Deploy healer
        healer = new StakeWeightHealer();

        // Set new implementation (simulates proxy upgrade)
        vm.store(address(stakeWeight), IMPLEMENTATION_SLOT, bytes32(uint256(uint160(address(healer)))));
    }

    /// @notice Restores the original StakeWeight implementation
    function _restoreStakeWeight(address oldImpl) internal {
        vm.store(address(stakeWeight), IMPLEMENTATION_SLOT, bytes32(uint256(uint160(oldImpl))));
    }

    /*//////////////////////////////////////////////////////////////////////////
                            FIX VERIFICATION TESTS
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies updatePermanentLock now correctly sets weight at new epoch
     */
    function test_FIXED_UpdatePermanentLockSetsWeightAtNewEpoch() public {
        uint256 initialAmount = 1000e18;
        uint256 additionalAmount = 500e18;
        uint256 duration = 52 weeks;

        // Step 1: Create permanent lock
        vm.startPrank(alice);
        l2wct.approve(address(stakeWeight), type(uint256).max);
        stakeWeight.createPermanentLock(initialAmount, duration);
        vm.stopPrank();

        uint256 epochAfterCreate = stakeWeight.userPointEpoch(alice);
        uint256 weightAfterCreate = stakeWeight.userPermanentAt(alice, epochAfterCreate);

        console2.log("=== After createPermanentLock ===");
        console2.log("Epoch:", epochAfterCreate);
        console2.log("Weight:", weightAfterCreate);

        assertGt(weightAfterCreate, 0, "Weight should be set after create");

        // Step 2: Call updatePermanentLock
        vm.startPrank(alice);
        stakeWeight.updatePermanentLock(additionalAmount, duration);
        vm.stopPrank();

        uint256 epochAfterUpdate = stakeWeight.userPointEpoch(alice);
        uint256 weightAfterUpdate = stakeWeight.userPermanentAt(alice, epochAfterUpdate);

        console2.log("\n=== After updatePermanentLock (FIXED) ===");
        console2.log("Epoch:", epochAfterUpdate);
        console2.log("Weight at new epoch:", weightAfterUpdate);

        // FIX VERIFIED: New epoch has correct permanent weight
        assertGt(epochAfterUpdate, epochAfterCreate, "Epoch should increase");
        assertGt(weightAfterUpdate, 0, "FIX: Weight should be set at new epoch");
        assertGt(weightAfterUpdate, weightAfterCreate, "Weight should increase with more tokens");
    }

    /**
     * @notice Verifies increasePermanentLockDuration now correctly sets weight at new epoch
     */
    function test_FIXED_IncreasePermanentLockDurationSetsWeightAtNewEpoch() public {
        uint256 amount = 1000e18;
        uint256 initialDuration = 26 weeks;
        uint256 newDuration = 52 weeks;

        // Step 1: Create permanent lock
        vm.startPrank(alice);
        l2wct.approve(address(stakeWeight), type(uint256).max);
        stakeWeight.createPermanentLock(amount, initialDuration);
        vm.stopPrank();

        uint256 epochAfterCreate = stakeWeight.userPointEpoch(alice);
        uint256 weightAfterCreate = stakeWeight.userPermanentAt(alice, epochAfterCreate);

        // Step 2: Increase duration
        vm.startPrank(alice);
        stakeWeight.increasePermanentLockDuration(newDuration);
        vm.stopPrank();

        uint256 epochAfterIncrease = stakeWeight.userPointEpoch(alice);
        uint256 weightAfterIncrease = stakeWeight.userPermanentAt(alice, epochAfterIncrease);

        console2.log("=== After increasePermanentLockDuration (FIXED) ===");
        console2.log("Epoch:", epochAfterIncrease);
        console2.log("Weight at new epoch:", weightAfterIncrease);

        // FIX VERIFIED: New epoch has correct permanent weight
        assertGt(epochAfterIncrease, epochAfterCreate, "Epoch should increase");
        assertGt(weightAfterIncrease, 0, "FIX: Weight should be set at new epoch");
        assertGt(weightAfterIncrease, weightAfterCreate, "Weight should increase with longer duration");
    }

    /**
     * @notice Verifies rewards work correctly after updatePermanentLock (end-to-end)
     */
    function test_FIXED_RewardsWorkAfterUpdatePermanentLock() public {
        uint256 initialAmount = 1000e18;
        uint256 additionalAmount = 500e18;
        uint256 duration = 52 weeks;

        // Step 1: Create and update permanent lock
        vm.startPrank(alice);
        l2wct.approve(address(stakeWeight), type(uint256).max);
        stakeWeight.createPermanentLock(initialAmount, duration);
        stakeWeight.updatePermanentLock(additionalAmount, duration);
        vm.stopPrank();

        // Step 2: Move forward and inject rewards
        _mineBlocks(1 weeks / defaults.SECONDS_PER_BLOCK());

        uint256 rewardAmount = 100e18;
        uint256 currentWeek = (block.timestamp / 1 weeks) * 1 weeks;

        deal(address(l2wct), users.admin, rewardAmount);
        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), rewardAmount);
        stakingRewardDistributor.injectReward(currentWeek, rewardAmount);
        vm.stopPrank();

        stakingRewardDistributor.checkpointTotalSupply();

        _mineBlocks(1 weeks / defaults.SECONDS_PER_BLOCK());
        stakingRewardDistributor.checkpointTotalSupply();

        // Step 3: Verify distributor sees balance
        uint256 balanceFromDistributor = stakingRewardDistributor.balanceOfAt(alice, currentWeek);
        console2.log("balanceOfAt from distributor:", balanceFromDistributor);

        assertGt(balanceFromDistributor, 0, "FIX: Distributor should see non-zero balance");

        // Step 4: Claim rewards
        vm.startPrank(alice);
        uint256 claimed = stakingRewardDistributor.claim(alice);
        vm.stopPrank();

        console2.log("Claimed:", claimed);

        // FIX VERIFIED: User receives rewards
        assertGt(claimed, 0, "FIX: User should receive rewards after updatePermanentLock");
    }

    /*//////////////////////////////////////////////////////////////////////////
                            HEALING FUNCTION TESTS
                    (Using StakeWeightHealer - sandwich upgrade pattern)
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies batchHealPermanentWeights works for admin
     */
    function test_BatchHealPermanentWeights_AdminCanBatchHeal() public {
        uint256 amount = 1000e18;
        uint256 duration = 52 weeks;

        vm.startPrank(alice);
        l2wct.approve(address(stakeWeight), type(uint256).max);
        stakeWeight.createPermanentLock(amount, duration);
        vm.stopPrank();

        vm.startPrank(bob);
        l2wct.approve(address(stakeWeight), type(uint256).max);
        stakeWeight.createPermanentLock(amount, duration);
        vm.stopPrank();

        address[] memory users_ = new address[](2);
        users_[0] = alice;
        users_[1] = bob;

        // Simulate sandwich upgrade
        (, address oldImpl) = _upgradeToHealer();

        vm.prank(users.admin);
        StakeWeightHealer(address(stakeWeight)).batchHealPermanentWeights(users_);

        // Restore original implementation
        _restoreStakeWeight(oldImpl);

        assertGt(stakeWeight.userPermanentAt(alice, stakeWeight.userPointEpoch(alice)), 0, "Alice weight preserved");
        assertGt(stakeWeight.userPermanentAt(bob, stakeWeight.userPointEpoch(bob)), 0, "Bob weight preserved");
    }

    /**
     * @notice Verifies batchHealPermanentWeights reverts for non-admin
     */
    function test_BatchHealPermanentWeights_RevertsForNonAdmin() public {
        // Simulate upgrade to healer
        (, address oldImpl) = _upgradeToHealer();

        address[] memory users_ = new address[](1);
        users_[0] = alice;

        vm.prank(alice);
        vm.expectRevert();
        StakeWeightHealer(address(stakeWeight)).batchHealPermanentWeights(users_);

        // Restore original implementation
        _restoreStakeWeight(oldImpl);
    }

    /**
     * @notice Verifies batchHealPermanentWeights skips non-permanent users gracefully
     */
    function test_BatchHealPermanentWeights_SkipsNonPermanentUsers() public {
        uint256 amount = 1000e18;

        vm.startPrank(alice);
        l2wct.approve(address(stakeWeight), type(uint256).max);
        stakeWeight.createPermanentLock(amount, 52 weeks);
        vm.stopPrank();

        vm.startPrank(bob);
        l2wct.approve(address(stakeWeight), type(uint256).max);
        stakeWeight.createLock(amount, block.timestamp + 52 weeks);
        vm.stopPrank();

        address[] memory users_ = new address[](2);
        users_[0] = alice;
        users_[1] = bob;

        // Simulate sandwich upgrade
        (, address oldImpl) = _upgradeToHealer();

        vm.prank(users.admin);
        StakeWeightHealer(address(stakeWeight)).batchHealPermanentWeights(users_);

        // Restore original implementation
        _restoreStakeWeight(oldImpl);

        assertGt(stakeWeight.userPermanentAt(alice, stakeWeight.userPointEpoch(alice)), 0, "Alice weight preserved");
    }
}
