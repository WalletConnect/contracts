// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakeWeight_Integration_Shared_Test } from "test/integration/shared/StakeWeight.t.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Checkpoint_StakeWeight_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    uint256 checkpointCallCount;

    function setUp() public override {
        super.setUp();

        checkpointCallCount = 0;
    }

    function test_checkpoint_noExistingLocks() public {
        uint256 initialEpoch = stakeWeight.epoch();
        uint256 initialSupply = stakeWeight.totalSupply();

        _checkpointAndCount();

        (int128 bias, int128 slope, uint256 timestamp,) = stakeWeight.pointHistory(stakeWeight.epoch());

        assertEq(stakeWeight.epoch(), initialEpoch + checkpointCallCount, "Epoch should be incremented");
        assertEq(timestamp, block.timestamp, "Point timestamp should be current block timestamp");
        assertEq(bias, 0, "Point bias should be zero");
        assertEq(slope, 0, "Point slope should be zero");
        assertEq(stakeWeight.totalSupply(), initialSupply, "Total supply should not change");
    }

    function test_checkpoint_existingLocks_noTimePassed() public {
        _createLockForUser(users.alice, 100e18, block.timestamp + 4 weeks);
        _createLockForUser(users.bob, 200e18, block.timestamp + 8 weeks);

        uint256 initialEpoch = stakeWeight.epoch();
        uint256 initialSupply = stakeWeight.totalSupply();

        _checkpointAndCount();

        assertEq(stakeWeight.epoch(), initialEpoch + checkpointCallCount, "Epoch should be incremented");
        assertEq(stakeWeight.totalSupply(), initialSupply, "Total supply should not change");

        (,, uint256 latestTimestamp,) = stakeWeight.pointHistory(stakeWeight.epoch());
        assertEq(latestTimestamp, block.timestamp, "Latest point timestamp should be current block timestamp");
    }

    function test_checkpoint_existingLocks_lessThanWeekPassed() public {
        _createLockForUser(users.alice, 100e18, block.timestamp + 4 weeks);
        _createLockForUser(users.bob, 200e18, block.timestamp + 8 weeks);

        uint256 initialEpoch = stakeWeight.epoch();
        uint256 initialSupply = stakeWeight.totalSupply();

        vm.warp(block.timestamp + 6 days);

        _checkpointAndCount();

        (int128 bias, int128 slope, uint256 timestamp,) = stakeWeight.pointHistory(stakeWeight.epoch());

        assertEq(stakeWeight.epoch(), initialEpoch + checkpointCallCount, "Epoch should be incremented");
        assertEq(timestamp, block.timestamp, "Point timestamp should be current block timestamp");
        assertTrue(bias > 0, "Point bias should be positive");
        assertTrue(slope > 0, "Point slope should be positive");
        assertTrue(stakeWeight.totalSupply() < initialSupply, "Total supply should decrease");
    }

    function test_checkpoint_existingLocks_multipleWeeksPassed() public {
        _createLockForUser(users.alice, 100e18, block.timestamp + 4 weeks);
        _createLockForUser(users.bob, 200e18, block.timestamp + 8 weeks);

        uint256 initialEpoch = stakeWeight.epoch();
        uint256 initialSupply = stakeWeight.totalSupply();

        uint256 initialTimestamp = block.timestamp;

        (,, uint256 latestTimestamp,) = stakeWeight.pointHistory(stakeWeight.epoch());
        assertEq(latestTimestamp, initialTimestamp, "Latest point timestamp should be initial timestamp");

        uint256 weeksPassed = 3;
        vm.warp(initialTimestamp + weeksPassed * 1 weeks);

        _checkpointAndCount();

        uint256 expectedEpochIncrease = weeksPassed + checkpointCallCount;

        assertEq(
            stakeWeight.epoch(),
            initialEpoch + expectedEpochIncrease,
            "Epoch should be incremented by weeks passed + checkpoint calls"
        );

        initialTimestamp = _timestampToFloorWeek(initialTimestamp);

        for (uint256 i = 1; i <= expectedEpochIncrease; i++) {
            (int128 bias, int128 slope, uint256 timestamp,) = stakeWeight.pointHistory(initialEpoch + i);
            assertTrue(bias > 0, "Point bias should be positive for each week");
            assertTrue(slope > 0, "Point slope should be positive for each week");

            uint256 expectedTimestamp;
            if (i < expectedEpochIncrease) {
                expectedTimestamp = initialTimestamp + i * 1 weeks;
            } else {
                expectedTimestamp = block.timestamp;
            }

            assertEq(timestamp, expectedTimestamp, "Timestamp should be correct for each week");
        }

        assertLt(stakeWeight.totalSupply(), initialSupply, "Total supply should decrease because of the decay");
    }

    function test_checkpoint_existingLocks_someExpiry() public {
        // Create some locks
        _createLockForUser(users.alice, 100e18, block.timestamp + 2 weeks);
        _createLockForUser(users.bob, 200e18, block.timestamp + 8 weeks);

        uint256 initialEpoch = stakeWeight.epoch();

        // Move time forward to expire the first lock
        uint256 numWeeksPassed = 3;
        vm.warp(block.timestamp + numWeeksPassed * 1 weeks);

        _checkpointAndCount();

        (int128 bias, int128 slope, uint256 timestamp,) = stakeWeight.pointHistory(stakeWeight.epoch());

        uint256 finalBobBalance = stakeWeight.balanceOf(users.bob);

        assertEq(
            stakeWeight.epoch(),
            initialEpoch + numWeeksPassed + checkpointCallCount,
            "Epoch should be incremented by weeks passed"
        );
        assertEq(timestamp, block.timestamp, "Point timestamp should be current block timestamp");
        assertTrue(bias > 0, "Point bias should be positive");
        assertTrue(slope > 0, "Point slope should be positive");
        assertEq(
            stakeWeight.totalSupply(),
            finalBobBalance,
            "Total supply should only be Bob's current balance, as Alice's lock has expired"
        );
    }

    function test_checkpoint_existingLocks_allExpiry() public {
        // Create some locks
        _createLockForUser(users.alice, 100e18, block.timestamp + 2 weeks);
        _createLockForUser(users.bob, 200e18, block.timestamp + 4 weeks);

        uint256 initialEpoch = stakeWeight.epoch();

        // Move time forward to expire all locks
        uint256 numWeeksPassed = 5;
        vm.warp(block.timestamp + numWeeksPassed * 1 weeks);

        _checkpointAndCount();
        (int128 bias, int128 slope, uint256 timestamp,) = stakeWeight.pointHistory(stakeWeight.epoch());

        assertEq(
            stakeWeight.epoch(),
            initialEpoch + numWeeksPassed + checkpointCallCount,
            "Epoch should be incremented by weeks passed"
        );
        assertEq(timestamp, block.timestamp, "Point timestamp should be current block timestamp");
        assertEq(bias, 0, "Point bias should be zero");
        assertEq(slope, 0, "Point slope should be zero");
        assertEq(stakeWeight.totalSupply(), 0, "Total supply should be zero");
    }

    function test_checkpoint_multipleCallsSameBlock() public {
        uint256 initialEpoch = stakeWeight.epoch();

        stakeWeight.checkpoint();
        uint256 firstCallEpoch = stakeWeight.epoch();
        (,, uint256 firstTimestamp,) = stakeWeight.pointHistory(firstCallEpoch);

        stakeWeight.checkpoint();
        uint256 secondCallEpoch = stakeWeight.epoch();
        (,, uint256 secondTimestamp,) = stakeWeight.pointHistory(secondCallEpoch);

        assertEq(firstCallEpoch, initialEpoch + 1, "First call should increment epoch");
        assertEq(secondCallEpoch, firstCallEpoch + 1, "Second call should also increment epoch");
        assertEq(firstTimestamp, secondTimestamp, "Both calls should use same timestamp");
    }

    function _checkpointAndCount() internal {
        stakeWeight.checkpoint();
        checkpointCallCount++;
    }
}
