// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { LockedTokenStaker_Integration_Shared_Test } from "test/integration/shared/LockedTokenStaker.t.sol";
import { LockedTokenStaker } from "src/LockedTokenStaker.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract IncreaseUnlockTimeFor_LockedTokenStaker_Integration_Concrete_Test is
    LockedTokenStaker_Integration_Shared_Test
{
    uint256 constant INITIAL_LOCK_AMOUNT = 100 ether;
    uint256 constant INITIAL_LOCK_DURATION = 4 weeks;
    uint256 constant NEW_LOCK_DURATION = 8 weeks;

    function setUp() public override {
        super.setUp();
        (bytes memory decodableArgs, bytes32[] memory proof) = _createAllocation(users.alice, INITIAL_LOCK_AMOUNT);
        _createLockForUser(
            users.alice, INITIAL_LOCK_AMOUNT, block.timestamp + INITIAL_LOCK_DURATION, decodableArgs, proof
        );
    }

    function test_RevertGiven_ContractIsPaused() external {
        _pause();

        vm.expectRevert(LockedTokenStaker.Paused.selector);
        vm.prank(users.alice);
        lockedTokenStaker.increaseUnlockTimeFor(users.alice, block.timestamp + NEW_LOCK_DURATION);
    }

    modifier whenContractIsNotPaused() {
        _;
    }

    function test_RevertGiven_CallerIsNotTheOriginalBeneficiary() external whenContractIsNotPaused {
        vm.expectRevert(LockedTokenStaker.InvalidCaller.selector);
        vm.prank(users.bob);
        lockedTokenStaker.increaseUnlockTimeFor(users.alice, block.timestamp + NEW_LOCK_DURATION);
    }

    modifier givenCallerIsTheOriginalBeneficiary() {
        _;
    }

    function test_RevertGiven_UserHasNoExistingLock()
        external
        whenContractIsNotPaused
        givenCallerIsTheOriginalBeneficiary
    {
        vm.expectRevert(StakeWeight.NonExistentLock.selector);
        vm.prank(users.bob);
        lockedTokenStaker.increaseUnlockTimeFor(users.bob, block.timestamp + NEW_LOCK_DURATION);
    }

    modifier givenUserHasExistingLock() {
        _;
    }

    function test_RevertGiven_LockHasExpired()
        external
        whenContractIsNotPaused
        givenCallerIsTheOriginalBeneficiary
        givenUserHasExistingLock
    {
        vm.warp(block.timestamp + INITIAL_LOCK_DURATION + 1);
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(users.alice);

        vm.expectRevert(abi.encodeWithSelector(StakeWeight.ExpiredLock.selector, block.timestamp, lock.end));
        vm.prank(users.alice);
        lockedTokenStaker.increaseUnlockTimeFor(users.alice, block.timestamp + NEW_LOCK_DURATION);
    }

    function test_RevertWhen_NewUnlockTimeLessThanOrEqualToCurrentLockEnd()
        external
        whenContractIsNotPaused
        givenCallerIsTheOriginalBeneficiary
        givenUserHasExistingLock
    {
        uint256 currentLockEnd = _timestampToFloorWeek(block.timestamp + INITIAL_LOCK_DURATION);
        vm.expectRevert(
            abi.encodeWithSelector(StakeWeight.LockTimeNotIncreased.selector, currentLockEnd, currentLockEnd)
        );
        vm.prank(users.alice);
        lockedTokenStaker.increaseUnlockTimeFor(users.alice, block.timestamp + INITIAL_LOCK_DURATION);
    }

    function test_RevertWhen_NewUnlockTimeExceedsMaxLock()
        external
        whenContractIsNotPaused
        givenCallerIsTheOriginalBeneficiary
        givenUserHasExistingLock
    {
        uint256 maxLock = stakeWeight.maxLock();
        vm.expectRevert(
            abi.encodeWithSelector(
                StakeWeight.LockMaxDurationExceeded.selector,
                _timestampToFloorWeek(block.timestamp + maxLock + 1 weeks),
                _timestampToFloorWeek(block.timestamp + maxLock)
            )
        );
        vm.prank(users.alice);
        lockedTokenStaker.increaseUnlockTimeFor(users.alice, block.timestamp + maxLock + 1 weeks);
    }

    function test_WhenNewUnlockTimeIsValid()
        external
        whenContractIsNotPaused
        givenCallerIsTheOriginalBeneficiary
        givenUserHasExistingLock
    {
        uint256 newUnlockTime = block.timestamp + NEW_LOCK_DURATION;
        uint256 newUnlockTimeFloored = _timestampToFloorWeek(newUnlockTime);
        uint256 initialSupply = stakeWeight.supply();
        uint256 initialTotalSupply = stakeWeight.totalSupply();
        uint256 initialStakeWeight = stakeWeight.balanceOf(users.alice);

        vm.expectEmit(true, true, true, true);
        emit Deposit(
            users.alice, 0, newUnlockTimeFloored, stakeWeight.ACTION_INCREASE_UNLOCK_TIME(), 0, block.timestamp
        );

        vm.expectEmit(true, true, true, true);
        emit Supply(initialSupply, stakeWeight.supply());

        vm.prank(users.alice);
        lockedTokenStaker.increaseUnlockTimeFor(users.alice, newUnlockTime);

        StakeWeight.LockedBalance memory lock = stakeWeight.locks(users.alice);
        assertEq(lock.end, newUnlockTimeFloored, "Lock end time should be updated");
        assertEq(stakeWeight.supply(), initialSupply, "Supply should remain the same");
        assertGt(stakeWeight.balanceOf(users.alice), initialStakeWeight, "Stake weight should increase");
        assertGt(stakeWeight.totalSupply(), initialTotalSupply, "Total supply should increase");
    }
}
