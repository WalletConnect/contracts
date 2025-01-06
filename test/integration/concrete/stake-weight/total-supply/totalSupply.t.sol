// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakeWeight } from "src/StakeWeight.sol";
import { StakeWeight_Integration_Shared_Test } from "test/integration/shared/StakeWeight.t.sol";

contract TotalSupply_StakeWeight_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    function setUp() public override {
        super.setUp();
        vm.prank(users.admin);
        l2wct.disableTransferRestrictions();
    }

    function test_GivenNoLocksExist() external view {
        assertEq(stakeWeight.totalSupply(), 0, "Total supply should be zero when no locks exist");
    }

    function test_GivenLocksExist() external {
        uint256 amount = 100e18;
        uint256 lockDuration = 1 weeks;
        _createLockForUser(users.alice, amount, block.timestamp + lockDuration);

        uint256 bias = _calculateBias(amount, block.timestamp + lockDuration, block.timestamp);

        assertEq(stakeWeight.totalSupply(), bias, "Total supply should equal the locked amount");
        assertGt(stakeWeight.totalSupply(), 0, "Total supply should be greater than zero");
        assertLe(stakeWeight.totalSupply(), bias, "Total supply should not exceed the total locked amount");
    }

    function test_GivenMultipleUsersHaveLocks() external {
        uint256 aliceAmount = 100e18;
        uint256 bobAmount = 200e18;
        uint256 lockDuration1 = 1 weeks;
        uint256 lockDuration2 = 2 weeks;

        _createLockForUser(users.alice, aliceAmount, block.timestamp + lockDuration1);
        _createLockForUser(users.bob, bobAmount, block.timestamp + lockDuration2);

        uint256 aliceBias = _calculateBias(aliceAmount, block.timestamp + lockDuration1, block.timestamp);
        uint256 bobBias = _calculateBias(bobAmount, block.timestamp + lockDuration2, block.timestamp);

        assertEq(stakeWeight.totalSupply(), aliceBias + bobBias, "Total supply should correctly sum all active locks");
    }

    function test_AfterLockExpires() external {
        uint256 aliceAmount = 100e18;
        uint256 bobAmount = 200e18;
        uint256 lockDuration1 = 1 weeks;
        uint256 lockDuration2 = 2 weeks;

        _createLockForUser(users.alice, aliceAmount, block.timestamp + lockDuration1);
        _createLockForUser(users.bob, bobAmount, block.timestamp + lockDuration2);

        uint256 initialBalanceSum = stakeWeight.balanceOf(users.alice) + stakeWeight.balanceOf(users.bob);

        uint256 initialSupply = stakeWeight.totalSupply();
        assertEq(initialSupply, initialBalanceSum, "Initial supply should equal the sum of initial balances");

        // Warp time to after the first lock expires
        vm.warp(block.timestamp + lockDuration1 + 1);

        uint256 bobBalance = stakeWeight.balanceOf(users.bob);

        assertEq(
            stakeWeight.totalSupply(),
            bobBalance,
            "Total supply should just be bob's balance (as alice's lock has expired)"
        );
        assertLt(stakeWeight.totalSupply(), initialSupply, "Total supply should decrease after a lock expires");
    }

    function test_GivenAllLocksExpire() external {
        uint256 amount1 = 100e18;
        uint256 amount2 = 200e18;
        uint256 lockDuration = 1 weeks;

        _createLockForUser(users.alice, amount1, block.timestamp + lockDuration);
        _createLockForUser(users.bob, amount2, block.timestamp + lockDuration);

        // Warp time to after all locks expire
        vm.warp(block.timestamp + lockDuration + 1);

        assertEq(stakeWeight.totalSupply(), 0, "Total supply should return to zero when all locks expire");
    }
}
