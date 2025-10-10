// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { LockedTokenStaker_Integration_Shared_Test } from "test/integration/shared/LockedTokenStaker.t.sol";
import { LockedTokenStaker } from "src/LockedTokenStaker.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IPostClaimHandler, IERC20 } from "src/utils/magna/MerkleVester.sol";

/**
 * @title Test suite for multiple allocations per beneficiary scenario (CANTINA-12)
 *
 * @dev OPERATIONAL CONSTRAINT DOCUMENTATION:
 *      LockedTokenStaker.sol tracks aggregate locked amounts per address, not per allocation.
 *        Check at line 218: `if (remainingAllocation < lockedAmount - lock.transferredAmount + claimAmount)`
 *
 *      This design means locks from allocation A reduce claimable amounts from allocation B
 *      on the same address.
 *
 *      TESTS DOCUMENTING LIMITATION:
 *      - test_WhenLocksFromA1Only_ThenClaimsFromA2 (shows cross-allocation blocking)
 *      - test_GivenLockEqualsAllocation_WhenClaimsFromLockedAllocation_ThenCannotClaim (edge case)
 *
 *      MITIGATION: Issue only one allocation per wallet across vesters calling LockedTokenStaker.
 *      No contract fix planned; existing stakes lack allocation identifiers needed for migration.
 */
contract HandlePostClaimMultipleAllocations_LockedTokenStaker_Integration_Test is
    LockedTokenStaker_Integration_Shared_Test
{
    uint256 constant ALLOCATION_A1_AMOUNT = 100 ether;
    uint256 constant ALLOCATION_A2_AMOUNT = 200 ether;
    uint256 constant LOCK_DURATION = 4 weeks;

    bytes decodableArgsA1;
    bytes32[] proofA1;
    bytes decodableArgsA2;
    bytes32[] proofA2;

    IPostClaimHandler postClaimHandler;

    function setUp() public override {
        super.setUp();

        // Create two distinct allocations for Alice
        (decodableArgsA1, proofA1) = _createAllocationWithId(users.alice, ALLOCATION_A1_AMOUNT, "allocation_A1");
        (decodableArgsA2, proofA2) = _createAllocationWithId(users.alice, ALLOCATION_A2_AMOUNT, "allocation_A2");

        // Fund vester with total of both allocations (deal overwrites, so we need to add back)
        deal(address(l2wct), address(vester), ALLOCATION_A1_AMOUNT + ALLOCATION_A2_AMOUNT);

        // Fast forward past vesting start
        skip(90 days);

        postClaimHandler = IPostClaimHandler(address(lockedTokenStaker));

        vm.startPrank(users.admin);
        vester.addPostClaimHandlerToWhitelist(postClaimHandler);
        vm.stopPrank();
    }

    modifier givenUserHasMultipleAllocations() {
        _;
    }

    /* //////////////////////////////////////////////////////////////////////////
                          LOCK FROM A1 ONLY - CLAIM FROM A1
    //////////////////////////////////////////////////////////////////////////*/

    function test_GivenClaimWithinUnlockedAmount_WhenLocksFromA1Only_ThenClaimsFromA1()
        external
        givenUserHasMultipleAllocations
    {
        // Lock 30 ETH from A1 (100 ETH total)
        uint256 lockAmount = 30 ether;
        _createLockForUser(users.alice, lockAmount, block.timestamp + LOCK_DURATION, decodableArgsA1, proofA1);

        // Try to claim 50 ETH from A1 (within unlocked 70 ETH)
        uint256 claimAmount = 50 ether;
        bytes memory extraData = abi.encode(uint32(0), decodableArgsA1, proofA1);

        uint256 balanceBefore = l2wct.balanceOf(users.alice);

        vm.prank(users.alice);
        vester.withdraw(claimAmount, 0, decodableArgsA1, proofA1, postClaimHandler, extraData);

        uint256 balanceAfter = l2wct.balanceOf(users.alice);

        assertEq(balanceAfter - balanceBefore, claimAmount, "Should receive 50 ETH from A1");
    }

    function test_RevertGiven_ClaimExceedsUnlockedAmount_WhenLocksFromA1Only_ThenClaimsFromA1()
        external
        givenUserHasMultipleAllocations
    {
        // Lock 30 ETH from A1 (100 ETH total)
        uint256 lockAmount = 30 ether;
        _createLockForUser(users.alice, lockAmount, block.timestamp + LOCK_DURATION, decodableArgsA1, proofA1);

        // Claim 70 ETH first (entire unlocked amount)
        bytes memory extraData = abi.encode(uint32(0), decodableArgsA1, proofA1);
        vm.prank(users.alice);
        vester.withdraw(70 ether, 0, decodableArgsA1, proofA1, postClaimHandler, extraData);

        // Try to claim 1 more ETH from A1 (exceeds unlocked amount)
        // remainingAllocation = 100 - 70 = 30
        // allocationBackedLock = 30
        // 30 < 30 + 1 -> should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                LockedTokenStaker.CannotClaimLockedTokens.selector,
                30 ether, // remainingAllocation
                30 ether, // lockedAmount
                1 ether // claimAmount
            )
        );
        vm.prank(users.alice);
        vester.withdraw(1 ether, 0, decodableArgsA1, proofA1, postClaimHandler, extraData);
    }

    /* //////////////////////////////////////////////////////////////////////////
                          LOCK FROM A1 ONLY - CLAIM FROM A2
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @dev Documents cross-allocation limitation: Lock from A1 blocks claims from A2
     *      Current check: remainingAllocation(200) < lockedAmount(30) - transferredAmount(0) + claimAmount(200)?
     *      200 < 230? TRUE → REVERTS
     *      Mitigation: Operational constraint—one allocation per wallet prevents this scenario
     */
    function test_WhenLocksFromA1Only_ThenClaimsFromA2() external givenUserHasMultipleAllocations {
        // Lock 30 ETH from A1
        uint256 lockAmountA1 = 30 ether;
        _createLockForUser(users.alice, lockAmountA1, block.timestamp + LOCK_DURATION, decodableArgsA1, proofA1);

        // Try to claim full 200 ETH from A2 (A2 has no per-allocation lock)
        uint256 claimAmount = 200 ether;
        bytes memory extraData = abi.encode(uint32(1), decodableArgsA2, proofA2);

        // Reverts because aggregate lock from A1 reduces A2's claimable amount
        vm.expectRevert(
            abi.encodeWithSelector(
                LockedTokenStaker.CannotClaimLockedTokens.selector,
                ALLOCATION_A2_AMOUNT, // remainingAllocation (200 ETH)
                lockAmountA1, // lockedAmount (30 ETH from A1)
                claimAmount // 200 ETH
            )
        );
        vm.prank(users.alice);
        vester.withdraw(claimAmount, 1, decodableArgsA2, proofA2, postClaimHandler, extraData);

        // Operational mitigation: One allocation per wallet prevents this scenario
    }

    /* //////////////////////////////////////////////////////////////////////////
                      LOCK FROM BOTH ALLOCATIONS - CLAIM FROM A1
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @dev This test demonstrates the architectural limitation:
     *      You CANNOT create locks from multiple allocations because:
     *      1. StakeWeight only allows ONE lock per user
     *      2. createLockFor reverts if lock already exists
     *      3. increaseLockAmountFor validates against the SAME allocation
     *
     *      This test documents that the current system fundamentally doesn't support
     *      a multi-allocation scenario.
     */
    function test_RevertWhen_TryingToLockFromSecondAllocation() external givenUserHasMultipleAllocations {
        // Lock 50 ETH from A1
        uint256 lockAmountA1 = 50 ether;
        _createLockForUser(users.alice, lockAmountA1, block.timestamp + LOCK_DURATION, decodableArgsA1, proofA1);

        // Try to create another lock from A2 - should revert because lock already exists
        uint256 lockAmountA2 = 100 ether;

        vm.startPrank(users.alice);
        vm.expectRevert(); // Will revert with "Lock already exists" from StakeWeight
        lockedTokenStaker.createLockFor(lockAmountA2, block.timestamp + LOCK_DURATION, 1, decodableArgsA2, proofA2);
        vm.stopPrank();
    }

    /* //////////////////////////////////////////////////////////////////////////
                      MIXED WITH OWN TOKENS (transferredAmount)
    //////////////////////////////////////////////////////////////////////////*/

    function test_WhenUserAddsOwnTokens_ThenOwnTokensDoNotBlockAllocationClaims()
        external
        givenUserHasMultipleAllocations
    {
        // Lock 30 ETH from A1
        uint256 lockAmountA1 = 30 ether;
        _createLockForUser(users.alice, lockAmountA1, block.timestamp + LOCK_DURATION, decodableArgsA1, proofA1);

        // Alice adds 20 ETH of her own tokens via StakeWeight
        uint256 ownTokens = 20 ether;
        vm.startPrank(users.alice);
        deal(address(l2wct), users.alice, ownTokens);
        l2wct.approve(address(stakeWeight), ownTokens);
        stakeWeight.increaseLockAmount(ownTokens);
        vm.stopPrank();

        StakeWeight.LockedBalance memory lock = stakeWeight.locks(users.alice);
        assertEq(SafeCast.toUint256(lock.amount), 50 ether, "Total lock should be 50 ETH");
        assertEq(lock.transferredAmount, ownTokens, "Transferred amount should be 20 ETH");

        // Claim 65 ETH from A1
        // vestingBackedTotal = 50 - 20 = 30 ETH
        // allocationBackedLock = min(30, 30) = 30 ETH
        // remainingAllocation = 100
        // 100 < 30 + 65 = 95? FALSE -> should ALLOW
        uint256 claimAmount = 65 ether;
        bytes memory extraData = abi.encode(uint32(0), decodableArgsA1, proofA1);

        uint256 balanceBefore = l2wct.balanceOf(users.alice);

        vm.prank(users.alice);
        vester.withdraw(claimAmount, 0, decodableArgsA1, proofA1, postClaimHandler, extraData);

        uint256 balanceAfter = l2wct.balanceOf(users.alice);

        assertEq(balanceAfter - balanceBefore, claimAmount, "Should receive 65 ETH from A1");
    }

    /* //////////////////////////////////////////////////////////////////////////
                              LOCK EXPIRY SCENARIOS
    //////////////////////////////////////////////////////////////////////////*/

    function test_GivenLockExpiresDuringClaimSequence_ThenAllowsClaimingPreviouslyLockedAmount()
        external
        givenUserHasMultipleAllocations
    {
        // Lock 40 ETH from A1
        uint256 lockAmountA1 = 40 ether;
        _createLockForUser(users.alice, lockAmountA1, block.timestamp + LOCK_DURATION, decodableArgsA1, proofA1);

        // Claim 50 ETH from A1 (within unlocked 60 ETH)
        bytes memory extraData = abi.encode(uint32(0), decodableArgsA1, proofA1);
        vm.prank(users.alice);
        vester.withdraw(50 ether, 0, decodableArgsA1, proofA1, postClaimHandler, extraData);

        // Fast forward past lock expiry
        skip(LOCK_DURATION + 1);

        // Now should be able to claim the remaining 40 ETH (previously locked)
        uint256 balanceBefore = l2wct.balanceOf(users.alice);

        vm.prank(users.alice);
        vester.withdraw(40 ether, 0, decodableArgsA1, proofA1, postClaimHandler, extraData);

        uint256 balanceAfter = l2wct.balanceOf(users.alice);

        assertEq(balanceAfter - balanceBefore, 40 ether, "Should receive 40 ETH after lock expires");

        // Verify lock was withdrawn
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(users.alice);
        assertEq(SafeCast.toUint256(lock.amount), 0, "Lock should be withdrawn");
    }

    /* //////////////////////////////////////////////////////////////////////////
                              EDGE CASES
    //////////////////////////////////////////////////////////////////////////*/

    function test_GivenLockEqualsAllocation_WhenClaimsFromLockedAllocation_ThenCannotClaim()
        external
        givenUserHasMultipleAllocations
    {
        // Lock full 100 ETH from A1
        uint256 lockAmountA1 = ALLOCATION_A1_AMOUNT;
        _createLockForUser(users.alice, lockAmountA1, block.timestamp + LOCK_DURATION, decodableArgsA1, proofA1);

        // Try to claim any amount from A1 should fail
        bytes memory extraData = abi.encode(uint32(0), decodableArgsA1, proofA1);

        vm.expectRevert();
        vm.prank(users.alice);
        vester.withdraw(1 ether, 0, decodableArgsA1, proofA1, postClaimHandler, extraData);

        // But claiming from A2 should work
        uint256 balanceBefore = l2wct.balanceOf(users.alice);

        vm.prank(users.alice);
        bytes memory extraDataA2 = abi.encode(uint32(1), decodableArgsA2, proofA2);
        vester.withdraw(100 ether, 1, decodableArgsA2, proofA2, postClaimHandler, extraDataA2);

        uint256 balanceAfter = l2wct.balanceOf(users.alice);

        assertEq(balanceAfter - balanceBefore, 100 ether, "Should receive 100 ETH from A2");
    }

    function test_GivenZeroLock_WhenClaimsFromMultipleAllocations_ThenClaimsSucceed()
        external
        givenUserHasMultipleAllocations
    {
        // No lock created, should be able to claim from both allocations

        // Claim from A1
        bytes memory extraDataA1 = abi.encode(uint32(0), decodableArgsA1, proofA1);
        vm.prank(users.alice);
        vester.withdraw(100 ether, 0, decodableArgsA1, proofA1, postClaimHandler, extraDataA1);

        // Claim from A2
        bytes memory extraDataA2 = abi.encode(uint32(1), decodableArgsA2, proofA2);
        vm.prank(users.alice);
        vester.withdraw(200 ether, 1, decodableArgsA2, proofA2, postClaimHandler, extraDataA2);

        assertEq(l2wct.balanceOf(users.alice), 300 ether, "Should receive 300 ETH total");
    }
}
