// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { LockedTokenStaker_Integration_Shared_Test } from "test/integration/shared/LockedTokenStaker.t.sol";
import { LockedTokenStaker } from "src/LockedTokenStaker.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract WithdrawAllFor_LockedTokenStaker_Integration_Concrete_Test is LockedTokenStaker_Integration_Shared_Test {
    uint256 constant LOCK_AMOUNT = 100 ether;
    uint256 constant LOCK_DURATION = 1 weeks;

    function setUp() public override {
        super.setUp();
        (bytes memory decodableArgs, bytes32[] memory proof) = _createAllocation(users.alice, LOCK_AMOUNT);
        _createLockForUser(users.alice, LOCK_AMOUNT, block.timestamp + LOCK_DURATION, decodableArgs, proof);
    }

    function test_RevertGiven_ContractIsPaused() external {
        _pause();

        vm.expectRevert(LockedTokenStaker.Paused.selector);
        vm.prank(users.alice);
        lockedTokenStaker.withdrawAllFor(users.alice);
    }

    modifier whenContractIsNotPaused() {
        _;
    }

    function test_RevertGiven_CallerIsNotTheOriginalBeneficiary() external whenContractIsNotPaused {
        vm.expectRevert(LockedTokenStaker.InvalidCaller.selector);
        vm.prank(users.bob);
        lockedTokenStaker.withdrawAllFor(users.alice);
    }

    modifier givenCallerIsTheOriginalBeneficiary() {
        _;
    }

    function test_RevertGiven_UserHasNoLock() external whenContractIsNotPaused givenCallerIsTheOriginalBeneficiary {
        vm.expectRevert(StakeWeight.NonExistentLock.selector);
        vm.prank(users.bob);
        lockedTokenStaker.withdrawAllFor(users.bob);
    }

    function test_RevertGiven_LockHasNotExpired()
        external
        whenContractIsNotPaused
        givenCallerIsTheOriginalBeneficiary
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                StakeWeight.LockStillActive.selector, _timestampToFloorWeek(block.timestamp + LOCK_DURATION)
            )
        );
        vm.prank(users.alice);
        lockedTokenStaker.withdrawAllFor(users.alice);
    }

    function test_WithdrawAllFor() external whenContractIsNotPaused givenCallerIsTheOriginalBeneficiary {
        // Fast forward to after lock expiration
        vm.warp(block.timestamp + LOCK_DURATION + 1);

        uint256 initialSupply = stakeWeight.supply();
        uint256 initialBalance = l2wct.balanceOf(users.alice);
        uint256 initialStakingContractBalance = l2wct.balanceOf(address(stakeWeight));

        vm.expectEmit(true, true, true, true);
        emit Supply(initialSupply, initialSupply - LOCK_AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit Withdraw(users.alice, LOCK_AMOUNT, 0, block.timestamp);

        vm.prank(users.alice);
        lockedTokenStaker.withdrawAllFor(users.alice);

        StakeWeight.LockedBalance memory lock = stakeWeight.locks(users.alice);
        assertEq(SafeCast.toUint256(lock.amount), 0, "Lock amount should be zero");
        assertEq(lock.end, 0, "Lock end should be zero");
        assertEq(stakeWeight.supply(), initialSupply - LOCK_AMOUNT, "Total supply should be updated");
        assertEq(l2wct.balanceOf(users.alice), initialBalance, "Tokens should not be transferred to the user");
        assertEq(
            l2wct.balanceOf(address(stakeWeight)),
            initialStakingContractBalance,
            "Staking contract balance should not change"
        );
    }
}
