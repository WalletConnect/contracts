// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { LockedTokenStaker_Integration_Shared_Test } from "test/integration/shared/LockedTokenStaker.t.sol";
import { LockedTokenStaker } from "src/LockedTokenStaker.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IPostClaimHandler, IERC20 } from "src/utils/magna/MerkleVester.sol";
import { console2 } from "forge-std/console2.sol";

/**
 * @title POC Test for Auditor's transferredAmount Concern
 * @notice This test validates whether the auditor's concern about mixing
 *         LockedTokenStaker locks with direct StakeWeight.increaseLockAmount is valid
 */
contract HandlePostClaimMixed_LockedTokenStaker_Integration_Test is LockedTokenStaker_Integration_Shared_Test {
    uint256 constant VESTING_ALLOCATION = 100 ether;
    uint256 constant VESTING_LOCKED_AMOUNT = 30 ether;
    uint256 constant OWN_TOKENS_AMOUNT = 20 ether;
    uint256 constant LOCK_DURATION = 52 weeks;

    bytes decodableArgs;
    bytes32[] proof;
    IPostClaimHandler postClaimHandler;

    function setUp() public override {
        super.setUp();

        // Create vesting allocation for Alice
        (decodableArgs, proof) = _createAllocation(users.alice, VESTING_ALLOCATION);

        // Fast forward past vesting start
        skip(90 days);

        postClaimHandler = IPostClaimHandler(address(lockedTokenStaker));

        vm.startPrank(users.admin);
        vester.addPostClaimHandlerToWhitelist(postClaimHandler);
        vm.stopPrank();
    }

    /**
     * @notice POC: User creates lock via LockedTokenStaker, then adds own tokens via StakeWeight
     * @dev This is the exact scenario the auditor is concerned about
     */
    function test_POC_MixedLockSources_CurrentBehavior() external {
        console2.log("\n=== POC: Mixed Lock Sources (Current Implementation) ===");

        // STEP 1: Alice locks 30 ETH from vesting via LockedTokenStaker
        console2.log("\n1. Alice locks 30 ETH from vesting allocation via LockedTokenStaker");
        _createLockForUser(users.alice, VESTING_LOCKED_AMOUNT, block.timestamp + LOCK_DURATION, decodableArgs, proof);

        StakeWeight.LockedBalance memory lock1 = stakeWeight.locks(users.alice);
        console2.log("   lock.amount:", SafeCast.toUint256(lock1.amount) / 1e18, "ETH");
        console2.log("   lock.transferredAmount:", lock1.transferredAmount / 1e18, "ETH");

        assertEq(SafeCast.toUint256(lock1.amount), VESTING_LOCKED_AMOUNT, "Lock amount should be 30 ETH");
        assertEq(lock1.transferredAmount, 0, "No tokens transferred yet");

        // STEP 2: Alice adds 20 ETH of her own tokens via StakeWeight.increaseLockAmount
        console2.log("\n2. Alice adds 20 ETH of her own tokens via StakeWeight.increaseLockAmount");

        // Give Alice tokens and approve
        vm.startPrank(users.alice);
        deal(address(l2wct), users.alice, OWN_TOKENS_AMOUNT);
        l2wct.approve(address(stakeWeight), OWN_TOKENS_AMOUNT);

        stakeWeight.increaseLockAmount(OWN_TOKENS_AMOUNT);
        vm.stopPrank();

        StakeWeight.LockedBalance memory lock2 = stakeWeight.locks(users.alice);
        console2.log("   lock.amount:", SafeCast.toUint256(lock2.amount) / 1e18, "ETH");
        console2.log("   lock.transferredAmount:", lock2.transferredAmount / 1e18, "ETH");

        assertEq(SafeCast.toUint256(lock2.amount), VESTING_LOCKED_AMOUNT + OWN_TOKENS_AMOUNT, "Lock amount should be 50 ETH");
        assertEq(lock2.transferredAmount, OWN_TOKENS_AMOUNT, "Transferred amount should be 20 ETH");

        // STEP 3: Try to claim 40 ETH from vesting
        console2.log("\n3. Alice tries to claim 40 ETH from vesting allocation");
        console2.log("   Vesting remaining: 100 ETH");
        console2.log("   Vesting-locked: 30 ETH (should block)");
        console2.log("   Own tokens locked: 20 ETH (should NOT block vesting claims)");

        uint256 claimAmount = 40 ether;
        bytes memory extraData = abi.encode(uint32(0), decodableArgs, proof);

        uint256 balanceBefore = l2wct.balanceOf(users.alice);

        // Current implementation check (line 218 in LockedTokenStaker.sol):
        // if (remainingAllocation < lockedAmount + claimAmount)
        // 100 ETH < 50 ETH + 40 ETH = 90 ETH? NO -> Should ALLOW

        vm.prank(users.alice);
        vester.withdraw(
            claimAmount,
            0,
            decodableArgs,
            proof,
            postClaimHandler,
            extraData
        );

        uint256 balanceAfter = l2wct.balanceOf(users.alice);
        console2.log("\n   [SUCCESS] Claim succeeded!");
        console2.log("   Alice received:", (balanceAfter - balanceBefore) / 1e18, "ETH");

        assertEq(balanceAfter - balanceBefore, claimAmount, "Should receive 40 ETH from vesting");

        // STEP 4: Verify Alice can later withdraw her own 20 ETH from StakeWeight
        console2.log("\n4. Fast forward to lock expiry and withdraw from StakeWeight");

        skip(LOCK_DURATION + 1);

        uint256 stakeWeightBalanceBefore = l2wct.balanceOf(users.alice);

        vm.prank(users.alice);
        stakeWeight.withdrawAll();

        uint256 stakeWeightBalanceAfter = l2wct.balanceOf(users.alice);
        uint256 withdrawnFromStakeWeight = stakeWeightBalanceAfter - stakeWeightBalanceBefore;

        console2.log("   Withdrawn from StakeWeight:", withdrawnFromStakeWeight / 1e18, "ETH");
        console2.log("   Expected (transferredAmount):", OWN_TOKENS_AMOUNT / 1e18, "ETH");

        // StakeWeight only returns transferredAmount (line 1188-1189)
        assertEq(withdrawnFromStakeWeight, OWN_TOKENS_AMOUNT, "Should only get back own tokens (20 ETH)");

        console2.log("\n=== Summary ===");
        console2.log("Total Alice received:");
        console2.log("  From vesting: 40 ETH");
        console2.log("  From StakeWeight: 20 ETH (her own tokens back)");
        console2.log("  Total: 60 ETH");
        console2.log("\nVesting allocation status:");
        console2.log("  Started with: 100 ETH");
        console2.log("  Vesting-locked: 30 ETH (still in vesting, locked for staking)");
        console2.log("  Claimed: 40 ETH");
        console2.log("  Remaining claimable: 30 ETH (100 - 30 locked - 40 claimed)");
    }

    /**
     * @notice POC: What the auditor thinks SHOULD happen
     * @dev This test shows what would happen with the auditor's proposed fix
     */
    function test_POC_MixedLockSources_AuditorProposedFix() external {
        console2.log("\n=== POC: Auditor's Proposed Fix (Testing Logic) ===");

        // Same setup as above
        _createLockForUser(users.alice, VESTING_LOCKED_AMOUNT, block.timestamp + LOCK_DURATION, decodableArgs, proof);

        vm.startPrank(users.alice);
        deal(address(l2wct), users.alice, OWN_TOKENS_AMOUNT);
        l2wct.approve(address(stakeWeight), OWN_TOKENS_AMOUNT);
        stakeWeight.increaseLockAmount(OWN_TOKENS_AMOUNT);
        vm.stopPrank();

        StakeWeight.LockedBalance memory lock = stakeWeight.locks(users.alice);
        uint256 lockedAmount = SafeCast.toUint256(lock.amount);
        uint256 transferredAmount = lock.transferredAmount;
        uint256 remainingAllocation = VESTING_ALLOCATION;
        uint256 claimAmount = 40 ether;

        console2.log("\nAuditor's proposed check:");
        console2.log("  remainingAllocation + transferredAmount < lockedAmount + claimAmount");
        console2.log("  100 ETH + 20 ETH < 50 ETH + 40 ETH");
        console2.log("  120 ETH < 90 ETH?");

        bool wouldRevert = (remainingAllocation + transferredAmount) < (lockedAmount + claimAmount);
        console2.log("  Result:", wouldRevert ? "REVERT" : "ALLOW");

        assertFalse(wouldRevert, "Auditor's fix would also ALLOW the claim (correctly)");

        // Alternative interpretation: Only count vesting-backed locks
        uint256 vestingLockedAmount = lockedAmount - transferredAmount;
        console2.log("\nAlternative check (only vesting-backed locks):");
        console2.log("  remainingAllocation < vestingLockedAmount + claimAmount");
        console2.log("  100 ETH < 30 ETH + 40 ETH");
        console2.log("  100 ETH < 70 ETH?");

        bool wouldRevertAlt = remainingAllocation < (vestingLockedAmount + claimAmount);
        console2.log("  Result:", wouldRevertAlt ? "REVERT" : "ALLOW");

        assertFalse(wouldRevertAlt, "Alternative also ALLOWS the claim (correctly)");
    }

    /**
     * @notice POC: Prove that current implementation doesn't have the bug
     * @dev Shows that the "issue" the auditor found doesn't actually break anything
     */
    function test_POC_CurrentImplementationIsCorrect() external {
        console2.log("\n=== POC: Current Implementation Correctness ===");

        // Setup: 100 ETH vesting, lock 30 ETH from vesting, add 20 ETH own tokens
        _createLockForUser(users.alice, VESTING_LOCKED_AMOUNT, block.timestamp + LOCK_DURATION, decodableArgs, proof);

        vm.startPrank(users.alice);
        deal(address(l2wct), users.alice, OWN_TOKENS_AMOUNT);
        l2wct.approve(address(stakeWeight), OWN_TOKENS_AMOUNT);
        stakeWeight.increaseLockAmount(OWN_TOKENS_AMOUNT);
        vm.stopPrank();

        // Verify token locations
        console2.log("\nToken accounting:");
        console2.log("  Tokens in MerkleVester:", l2wct.balanceOf(address(vester)) / 1e18, "ETH");
        console2.log("  Tokens in StakeWeight:", l2wct.balanceOf(address(stakeWeight)) / 1e18, "ETH");

        assertEq(l2wct.balanceOf(address(vester)), VESTING_ALLOCATION, "Vester should hold 100 ETH");
        assertEq(l2wct.balanceOf(address(stakeWeight)), OWN_TOKENS_AMOUNT, "StakeWeight should only hold 20 ETH");

        // Claim maximum possible
        uint256 maxClaim = VESTING_ALLOCATION - VESTING_LOCKED_AMOUNT; // 100 - 30 = 70 ETH
        bytes memory extraData = abi.encode(uint32(0), decodableArgs, proof);

        console2.log("\nAttempt to claim maximum (70 ETH):");
        console2.log("  = Total allocation (100) - Vesting-locked (30)");

        vm.prank(users.alice);
        vester.withdraw(maxClaim, 0, decodableArgs, proof, postClaimHandler, extraData);

        console2.log("  [SUCCESS] Claimed 70 ETH");

        // Now trying to claim more should fail
        console2.log("\nAttempt to claim 1 more ETH (should fail):");

        vm.expectRevert(); // Will revert because remainingAllocation (30) < lockedAmount (50) + claimAmount (1)
        vm.prank(users.alice);
        vester.withdraw(1 ether, 0, decodableArgs, proof, postClaimHandler, extraData);

        console2.log("  [SUCCESS] Correctly reverted!");

        // After lock expires, withdraw own tokens
        skip(LOCK_DURATION + 1);

        uint256 balanceBefore = l2wct.balanceOf(users.alice);
        vm.prank(users.alice);
        stakeWeight.withdrawAll();
        uint256 balanceAfter = l2wct.balanceOf(users.alice);

        console2.log("\nAfter lock expiry, withdrew from StakeWeight:", (balanceAfter - balanceBefore) / 1e18, "ETH");
        assertEq(balanceAfter - balanceBefore, OWN_TOKENS_AMOUNT, "Got back own 20 ETH");

        console2.log("\n[CONCLUSION] Current implementation is CORRECT");
        console2.log("   - User can claim up to (allocation - vesting_locked)");
        console2.log("   - User's own transferred tokens don't block vesting claims");
        console2.log("   - User gets back own tokens from StakeWeight separately");
    }

    /**
     * @notice POC: Verify where the vesting-locked tokens go after lock expires
     * @dev This test shows that vesting-locked tokens remain claimable from MerkleVester
     */
    function test_POC_VestingLockedTokensFlow() external {
        console2.log("\n=== POC: Where do vesting-locked tokens go? ===");

        // Setup: 100 ETH vesting, lock 30 ETH from vesting, add 20 ETH own tokens
        _createLockForUser(users.alice, VESTING_LOCKED_AMOUNT, block.timestamp + LOCK_DURATION, decodableArgs, proof);

        vm.startPrank(users.alice);
        deal(address(l2wct), users.alice, OWN_TOKENS_AMOUNT);
        l2wct.approve(address(stakeWeight), OWN_TOKENS_AMOUNT);
        stakeWeight.increaseLockAmount(OWN_TOKENS_AMOUNT);
        vm.stopPrank();

        // Claim 40 ETH from vesting
        bytes memory extraData = abi.encode(uint32(0), decodableArgs, proof);
        vm.prank(users.alice);
        vester.withdraw(40 ether, 0, decodableArgs, proof, postClaimHandler, extraData);

        console2.log("\nAfter claiming 40 ETH from vesting:");
        console2.log("  Alice balance:", l2wct.balanceOf(users.alice) / 1e18, "ETH");
        console2.log("  MerkleVester balance:", l2wct.balanceOf(address(vester)) / 1e18, "ETH");
        console2.log("  StakeWeight balance:", l2wct.balanceOf(address(stakeWeight)) / 1e18, "ETH");

        // Fast forward and withdraw from StakeWeight
        skip(LOCK_DURATION + 1);

        vm.prank(users.alice);
        stakeWeight.withdrawAll();

        console2.log("\nAfter withdrawing from StakeWeight:");
        console2.log("  Alice balance:", l2wct.balanceOf(users.alice) / 1e18, "ETH");
        console2.log("  MerkleVester balance:", l2wct.balanceOf(address(vester)) / 1e18, "ETH");
        console2.log("  StakeWeight balance:", l2wct.balanceOf(address(stakeWeight)) / 1e18, "ETH");

        // Now Alice should be able to claim the remaining 30 ETH from vesting
        console2.log("\nNow claiming the remaining 30 ETH (vesting-locked amount) from vesting:");

        uint256 aliceBalanceBefore = l2wct.balanceOf(users.alice);

        vm.prank(users.alice);
        vester.withdraw(30 ether, 0, decodableArgs, proof, postClaimHandler, extraData);

        uint256 aliceBalanceAfter = l2wct.balanceOf(users.alice);

        console2.log("  Alice received:", (aliceBalanceAfter - aliceBalanceBefore) / 1e18, "ETH");
        console2.log("\nFinal state:");
        console2.log("  Alice total received: 90 ETH (40 vesting + 20 own + 30 vesting)");
        console2.log("  Claimed from vesting: 70 ETH (40 + 30)");
        console2.log("  MerkleVester remaining:", l2wct.balanceOf(address(vester)) / 1e18, "ETH (should be 30 ETH)");
        console2.log("\n[CONCLUSION] Vesting-locked tokens remain in vester and can be claimed after lock expires");

        assertEq(aliceBalanceAfter - aliceBalanceBefore, 30 ether, "Should receive 30 ETH from vesting");
        assertEq(l2wct.balanceOf(address(vester)), 30 ether, "Vester should have 30 ETH left (100 - 70 claimed)");
    }
}
