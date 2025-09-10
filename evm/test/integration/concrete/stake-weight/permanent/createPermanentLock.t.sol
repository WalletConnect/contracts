// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakeWeight_Integration_Shared_Test } from "test/integration/shared/StakeWeight.t.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CreatePerpetualLock_StakeWeight_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    uint256 constant VALID_DURATION = 52 weeks; // Use one valid duration for path testing
    uint256 constant INVALID_DURATION = 5 weeks; // Not in the valid set

    function setUp() public override {
        super.setUp();
        vm.prank(users.admin);
        l2wct.disableTransferRestrictions();
    }

    function test_RevertWhen_ContractIsPaused() external {
        _pause();

        vm.expectRevert(StakeWeight.Paused.selector);
        stakeWeight.createPermanentLock(100 ether, VALID_DURATION);
    }

    modifier whenContractIsNotPaused() {
        _;
    }

    function test_RevertWhen_UserAlreadyHasLock() external whenContractIsNotPaused {
        uint256 amount = 100 ether;
        
        // Deal tokens to Alice and start pranking as Alice
        deal(address(l2wct), users.alice, amount * 2);
        vm.startPrank(users.alice);
        
        // Approve tokens for locking
        IERC20(address(l2wct)).approve(address(stakeWeight), amount * 2);
        
        // Create initial permanent lock
        stakeWeight.createPermanentLock(amount, VALID_DURATION);
        
        // Attempt to create another lock
        vm.expectRevert(StakeWeight.AlreadyCreatedLock.selector);
        stakeWeight.createPermanentLock(amount, VALID_DURATION);
        
        vm.stopPrank();
    }

    modifier givenUserDoesNotHaveALock() {
        // Ensure the user doesn't have an existing lock
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(users.alice);
        require(lock.amount == 0, "User already has a lock");
        _;
    }

    function test_RevertWhen_AmountIsZero() external whenContractIsNotPaused givenUserDoesNotHaveALock {
        vm.expectRevert(abi.encodeWithSelector(StakeWeight.InvalidAmount.selector, 0));
        stakeWeight.createPermanentLock(0, VALID_DURATION);
    }

    function test_RevertWhen_DurationNotInValidSet() external whenContractIsNotPaused givenUserDoesNotHaveALock {
        vm.expectRevert(abi.encodeWithSelector(StakeWeight.InvalidDuration.selector, INVALID_DURATION));
        stakeWeight.createPermanentLock(100 ether, INVALID_DURATION);
    }

    function test_WhenParametersAreValid() external whenContractIsNotPaused givenUserDoesNotHaveALock {
        uint256 amount = 100 ether;
        
        // Deal tokens to Alice and start pranking as Alice
        deal(address(l2wct), users.alice, amount);
        vm.startPrank(users.alice);
        
        // Approve tokens for locking
        IERC20(address(l2wct)).approve(address(stakeWeight), amount);
        
        uint256 supplyBefore = stakeWeight.supply();
        
        // Expect the Deposit event
        vm.expectEmit(true, true, true, true);
        emit Deposit(
            users.alice, 
            amount, 
            0, // end is 0 for permanent
            stakeWeight.ACTION_CREATE_LOCK(), 
            amount, 
            block.timestamp
        );
        
        // Create permanent lock
        stakeWeight.createPermanentLock(amount, VALID_DURATION);
        
        // Verify lock was created with correct parameters
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(users.alice);
        assertEq(uint256(int256(lock.amount)), amount, "Locked amount should match");
        assertEq(lock.end, 0, "End should be 0 for permanent lock");
        assertEq(stakeWeight.permanentBaseWeeks(users.alice) * 1 weeks, VALID_DURATION, "Duration should be stored");
        
        // Verify balance is weighted and non-zero
        uint256 currentBalance = stakeWeight.balanceOf(users.alice);
        assertGt(currentBalance, 0, "Balance should be greater than 0");
        
        // Verify balance remains constant over time (permanent characteristic)
        uint256 initialBalance = currentBalance;
        _mineBlocks(10 weeks / defaults.SECONDS_PER_BLOCK());
        uint256 futureBalance = stakeWeight.balanceOf(users.alice);
        assertEq(futureBalance, initialBalance, "Balance should remain constant for permanent");
        
        // Verify total supply was updated
        assertEq(
            stakeWeight.supply(),
            supplyBefore + amount,
            "Total supply should increase by locked amount"
        );
        
        // Verify the lock behaves as permanent (constant weight over time)
        // We don't check internal Point structures, only external behavior
        
        vm.stopPrank();
    }
}