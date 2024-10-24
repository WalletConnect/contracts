// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { LockedTokenStaker_Integration_Shared_Test } from "test/integration/shared/LockedTokenStaker.t.sol";
import { LockedTokenStaker } from "src/LockedTokenStaker.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IPostClaimHandler } from "src/interfaces/MerkleVester.sol";

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

        // Fast forward to after the lock has vested
        skip(90 days);

        postClaimHandler = IPostClaimHandler(address(lockedTokenStaker));

        vm.startPrank(users.admin);
        vester.addPostClaimHandlerToWhitelist(postClaimHandler);
        vm.stopPrank();
    }

    function test_RevertGiven_ContractIsPaused() external {
        _pause();

        vm.expectRevert(LockedTokenStaker.Paused.selector);
        vm.prank(address(vester));
        lockedTokenStaker.handlePostClaim(IERC20(address(l2wct)), CLAIM_AMOUNT, users.alice, users.alice, "");
    }

    modifier whenContractIsNotPaused() {
        _;
    }

    function test_RevertGiven_CallerIsNotTheVesterContract() external whenContractIsNotPaused {
        vm.expectRevert(LockedTokenStaker.InvalidCaller.selector);
        vm.prank(users.bob);
        lockedTokenStaker.handlePostClaim(IERC20(address(l2wct)), CLAIM_AMOUNT, users.alice, users.alice, "");
    }

    modifier givenCallerIsTheVesterContract() {
        _;
    }

    function test_GivenUserHasNoLock() external whenContractIsNotPaused givenCallerIsTheVesterContract {
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

    function test_RevertGiven_UserHasActiveLock()
        external
        whenContractIsNotPaused
        givenCallerIsTheVesterContract
        givenUserHasLock
    {
        vm.expectRevert(LockedTokenStaker.CannotClaimWithActiveLock.selector);
        vester.withdraw(
            0, // withdrawalAmount (0 to withdraw all vested funds)
            0, // rootIndex (assuming 0 for this test case)
            decodableArgs, // decodableArgs
            proof, // proof
            postClaimHandler, // postClaimHandler
            "" // extraData (empty for this test case)
        );
    }

    function test_GivenUserHasExpiredLock()
        external
        whenContractIsNotPaused
        givenCallerIsTheVesterContract
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
}
