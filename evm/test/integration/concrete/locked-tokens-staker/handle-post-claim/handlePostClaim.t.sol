// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { LockedTokenStaker_Integration_Shared_Test } from "test/integration/shared/LockedTokenStaker.t.sol";
import { LockedTokenStaker } from "src/LockedTokenStaker.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IPostClaimHandler, IERC20 } from "src/utils/magna/MerkleVester.sol";

contract HandlePostClaim_LockedTokenStaker_Integration_Concrete_Test is LockedTokenStaker_Integration_Shared_Test {
    uint256 constant LOCK_AMOUNT = 100 ether;
    uint256 constant LOCK_DURATION = 1 weeks;
    uint256 constant CLAIM_AMOUNT = 50 ether;
    bytes decodableArgs;
    bytes32[] proof;

    IPostClaimHandler postClaimHandler;

    function setUp() public override {
        super.setUp();
        (decodableArgs, proof) = _createAllocation(users.alice, LOCK_AMOUNT);

        skip(90 days);
        postClaimHandler = IPostClaimHandler(address(lockedTokenStaker));

        vm.startPrank(users.admin);
        vester.addPostClaimHandlerToWhitelist(postClaimHandler);
        vm.stopPrank();
    }

    function test_RevertGiven_ContractIsPaused() external {
        _pause();

        vm.expectRevert(LockedTokenStaker.Paused.selector);
        vm.prank(users.alice);
        vester.withdraw(CLAIM_AMOUNT, 0, decodableArgs, proof, postClaimHandler, "");
    }

    modifier whenContractIsNotPaused() {
        _;
    }

    function test_RevertGiven_CallerIsNotTheVesterContract() external whenContractIsNotPaused {
        vm.expectRevert(LockedTokenStaker.InvalidCaller.selector);
        vm.prank(users.attacker);
        lockedTokenStaker.handlePostClaim(
            IERC20(address(l2wct)), CLAIM_AMOUNT, users.alice, users.alice, "allocation1", ""
        );
    }

    modifier givenCallerIsTheVesterContract() {
        _;
    }

    modifier givenAllocationIsFullyVested() {
        // Fast forward to after the lock has vested
        _;
    }

    function test_GivenUserHasNoLock()
        external
        whenContractIsNotPaused
        givenCallerIsTheVesterContract
        givenAllocationIsFullyVested
    {
        uint256 initialBalance = l2wct.balanceOf(users.alice);

        vester.withdraw(
            CLAIM_AMOUNT, // withdrawalAmount
            0, // rootIndex (assuming 0 for this test case)
            decodableArgs, // decodableArgs
            proof, // proof
            postClaimHandler, // postClaimHandler
            "" // extraData (empty for this test case)
        );

        assertEq(
            l2wct.balanceOf(users.alice), initialBalance + CLAIM_AMOUNT, "Tokens should be transferred to the user"
        );
    }

    modifier givenUserHasLock() {
        _createLockForUser(users.alice, LOCK_AMOUNT, block.timestamp + LOCK_DURATION, decodableArgs, proof);
        _;
    }

    function test_GivenUserHasExpiredLock()
        external
        whenContractIsNotPaused
        givenCallerIsTheVesterContract
        givenAllocationIsFullyVested
        givenUserHasLock
    {
        // Fast forward to after lock expiration
        vm.warp(block.timestamp + LOCK_DURATION + 1);

        uint256 initialSupply = stakeWeight.supply();
        uint256 initialBalance = l2wct.balanceOf(users.alice);

        vm.expectEmit(true, true, true, true);
        emit Supply(initialSupply, initialSupply - LOCK_AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit Withdraw(users.alice, LOCK_AMOUNT, 0, block.timestamp);

        vester.withdraw(
            CLAIM_AMOUNT, // withdrawalAmount
            0, // rootIndex (assuming 0 for this test case)
            decodableArgs, // decodableArgs
            proof, // proof
            postClaimHandler, // postClaimHandler
            "" // extraData (empty for this test case)
        );

        StakeWeight.LockedBalance memory lock = stakeWeight.locks(users.alice);
        assertEq(SafeCast.toUint256(lock.amount), 0, "Lock amount should be zero");
        assertEq(lock.end, 0, "Lock end should be zero");
        assertEq(stakeWeight.supply(), initialSupply - LOCK_AMOUNT, "Total supply should be updated");
        assertEq(
            l2wct.balanceOf(users.alice), initialBalance + CLAIM_AMOUNT, "Tokens should be transferred to the user"
        );
    }

    function test_RevertGiven_ActiveLockAndInvalidAllocationId()
        external
        whenContractIsNotPaused
        givenCallerIsTheVesterContract
        givenAllocationIsFullyVested
        givenUserHasLock
    {
        bytes memory wrongDecodableArgs;
        bytes32[] memory wrongProof;
        (wrongDecodableArgs, wrongProof) = _createAllocationWithId(users.bob, LOCK_AMOUNT, "allocation2");

        bytes memory extraData = abi.encode(uint32(1), wrongDecodableArgs, wrongProof);

        vm.expectRevert(LockedTokenStaker.InvalidAllocation.selector);

        vm.prank(users.alice);
        vester.withdraw(
            CLAIM_AMOUNT, // withdrawalAmount
            0, // rootIndex (assuming 0 for this test case)
            decodableArgs, // decodableArgs
            proof, // proof
            postClaimHandler, // postClaimHandler
            extraData // extraData
        );
    }

    function test_RevertGiven_ActiveLockAndClaimExceedsRemaining()
        external
        whenContractIsNotPaused
        givenCallerIsTheVesterContract
        givenAllocationIsFullyVested
    {
        uint256 remainingAllocation = LOCK_AMOUNT;
        bytes memory extraData = abi.encode(uint32(0), decodableArgs, proof);

        uint256 lockAmount = LOCK_AMOUNT / 10;

        _createLockForUser(users.alice, lockAmount, block.timestamp + LOCK_DURATION, decodableArgs, proof);

        // Claim the remaining allocation excluding the lockAmount
        vm.startPrank(users.alice);
        vester.withdraw(
            remainingAllocation - lockAmount, // withdrawalAmount
            0, // rootIndex (assuming 0 for this test case)
            decodableArgs, // decodableArgs
            proof, // proof
            postClaimHandler, // postClaimHandler
            extraData // extraData
        );

        remainingAllocation = lockAmount;

        // Can't claim the lockAmount as it's locked
        vm.expectRevert(
            abi.encodeWithSelector(
                LockedTokenStaker.CannotClaimLockedTokens.selector, remainingAllocation, lockAmount, lockAmount
            )
        );
        vester.withdraw(
            lockAmount, // withdrawalAmount
            0, // rootIndex (assuming 0 for this test case)
            decodableArgs, // decodableArgs
            proof, // proof
            postClaimHandler, // postClaimHandler
            extraData // extraData
        );
    }

    function test_GivenActiveLockAndClaimWithinRemaining()
        external
        whenContractIsNotPaused
        givenCallerIsTheVesterContract
    {
        uint256 remainingAllocation = LOCK_AMOUNT;
        bytes memory extraData = abi.encode(uint32(0), decodableArgs, proof);

        uint256 lockAmount = LOCK_AMOUNT / 10;

        _createLockForUser(users.alice, lockAmount, block.timestamp + LOCK_DURATION, decodableArgs, proof);

        uint256 claimableAmount = remainingAllocation - lockAmount;
        uint256 firstClaimAmount = claimableAmount * 5 / 8;
        uint256 secondClaimAmount = claimableAmount * 3 / 8;

        uint256 initialBalance = l2wct.balanceOf(users.alice);

        // Claim the remaining allocation excluding the lockAmount
        vm.startPrank(users.alice);
        vester.withdraw(
            firstClaimAmount, // withdrawalAmount
            0, // rootIndex (assuming 0 for this test case)
            decodableArgs, // decodableArgs
            proof, // proof
            postClaimHandler, // postClaimHandler
            extraData // extraData
        );

        vester.withdraw(
            secondClaimAmount, // withdrawalAmount
            0, // rootIndex (assuming 0 for this test case)
            decodableArgs, // decodableArgs
            proof, // proof
            postClaimHandler, // postClaimHandler
            extraData // extraData
        );

        assertEq(
            l2wct.balanceOf(users.alice), initialBalance + claimableAmount, "Tokens should be transferred to the user"
        );

        remainingAllocation = lockAmount;

        // Even though fully vested, the user can't claim more than the remaining allocation
        vm.expectRevert(
            abi.encodeWithSelector(
                LockedTokenStaker.CannotClaimLockedTokens.selector, remainingAllocation, lockAmount, remainingAllocation
            )
        );
        vester.withdraw(
            remainingAllocation, // withdrawalAmount
            0, // rootIndex (assuming 0 for this test case)
            decodableArgs, // decodableArgs
            proof, // proof
            postClaimHandler, // postClaimHandler
            extraData // extraData
        );

        // Now the lock has expired, the user can withdraw the remaining allocation
        vm.warp(block.timestamp + LOCK_DURATION + 1);

        vm.startPrank(users.alice);
        vester.withdraw(
            remainingAllocation, // withdrawalAmount
            0, // rootIndex (assuming 0 for this test case)
            decodableArgs, // decodableArgs
            proof, // proof
            postClaimHandler, // postClaimHandler
            extraData // extraData
        );

        assertEq(l2wct.balanceOf(users.alice), initialBalance + LOCK_AMOUNT, "Tokens should be transferred to the user");
    }
}
