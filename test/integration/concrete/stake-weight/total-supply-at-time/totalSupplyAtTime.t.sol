// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakeWeight } from "src/StakeWeight.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { StakeWeight_Integration_Shared_Test } from "test/integration/shared/StakeWeight.t.sol";

contract TotalSupplyAtTime_StakeWeight_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    function test_WhenQueryingSupplyAtTimeBeforeAnyLocks() external {
        assertEq(stakeWeight.totalSupplyAtTime(block.timestamp), 0, "Total supply should be zero before any locks");
        // Underflow
        vm.expectRevert();
        stakeWeight.totalSupplyAtTime(block.timestamp - 1);
    }

    function test_WhenQueryingSupplyAtCurrentTime() external {
        uint256 amount = 100e18;
        uint256 lockDuration = 1 weeks;
        _createLockForUser(users.alice, amount, block.timestamp + lockDuration);

        assertEq(
            stakeWeight.totalSupplyAtTime(block.timestamp),
            stakeWeight.totalSupply(),
            "Total supply at current time should match regular totalSupply"
        );
    }

    function test_WhenQueryingSupplyAtTimeWithActiveLocks() external {
        uint256 aliceAmount = 100e18;
        uint256 bobAmount = 200e18;
        uint256 lockDuration1 = 1 weeks;
        uint256 lockDuration2 = 2 weeks;

        _createLockForUser(users.alice, aliceAmount, block.timestamp + lockDuration1);
        _createLockForUser(users.bob, bobAmount, block.timestamp + lockDuration2);

        uint256 queryTime = block.timestamp + 3 days;
        uint256 supplyAtTime = stakeWeight.totalSupplyAtTime(queryTime);

        assertGt(supplyAtTime, 0, "Supply at time should be greater than zero");
        assertLe(
            supplyAtTime,
            stakeWeight.totalSupply(),
            "Supply at time should be less than or equal to current totalSupply"
        );
    }

    function test_WhenQueryingSupplyAtTimeAfterSomeLocksHaveExpired() external {
        uint256 aliceAmount = 100e18;
        uint256 bobAmount = 200e18;
        uint256 lockDuration1 = 1 weeks;
        uint256 lockDuration2 = 2 weeks;

        _createLockForUser(users.alice, aliceAmount, block.timestamp + lockDuration1);
        _createLockForUser(users.bob, bobAmount, block.timestamp + lockDuration2);

        uint256 initialSupply = stakeWeight.totalSupply();
        uint256 queryTime = block.timestamp + lockDuration1 + 1 days;

        uint256 supplyAtTime = stakeWeight.totalSupplyAtTime(queryTime);

        assertLt(supplyAtTime, initialSupply, "Supply at time should be less than the original totalSupply");
    }

    function test_WhenQueryingSupplyAtTimeAfterAllLocksHaveExpired() external {
        uint256 amount1 = 100e18;
        uint256 amount2 = 200e18;
        uint256 lockDuration = 1 weeks;

        _createLockForUser(users.alice, amount1, block.timestamp + lockDuration);
        _createLockForUser(users.bob, amount2, block.timestamp + lockDuration);

        uint256 queryTime = block.timestamp + lockDuration + 1 days;

        assertEq(
            stakeWeight.totalSupplyAtTime(queryTime), 0, "Total supply should be zero after all locks have expired"
        );
    }

    function test_WhenLocksHaveDifferentDurations() external {
        uint256 aliceAmount = 100e18;
        uint256 bobAmount = 200e18;
        uint256 lockDuration1 = 1 weeks;
        uint256 lockDuration2 = 4 weeks;

        _createLockForUser(users.alice, aliceAmount, block.timestamp + lockDuration1);
        _createLockForUser(users.bob, bobAmount, block.timestamp + lockDuration2);

        uint256 queryTime = block.timestamp + 2 weeks;
        uint256 supplyAtTime = stakeWeight.totalSupplyAtTime(queryTime);

        assertGt(supplyAtTime, 0, "Supply at time should be greater than zero");
        assertLt(supplyAtTime, stakeWeight.totalSupply(), "Supply at time should be less than current totalSupply");
    }

    function test_WhenQueryingSupplyIntoFuture() external {
        // Create various locks at different times
        uint256 initialTime = block.timestamp;
        _createLockForUser(users.alice, 100e18, initialTime + 1 weeks);
        _createLockForUser(users.bob, 200e18, initialTime + 2 weeks);
        _createLockForUser(users.carol, 300e18, initialTime + 3 weeks);

        uint256 lastSupply = stakeWeight.totalSupply();
        for (uint256 i = 1; i <= 4; i++) {
            uint256 queryTime = initialTime + i * 1 weeks;
            uint256 supplyAtTime = stakeWeight.totalSupplyAtTime(queryTime);
            assertLe(supplyAtTime, lastSupply, "Supply at time should be less than or equal to initial supply");
            lastSupply = supplyAtTime;
        }

        assertGt(
            stakeWeight.totalSupplyAtTime(initialTime + 2 weeks + 5 days), 0, "Supply before 3 weeks should be > 0"
        );
        assertEq(stakeWeight.totalSupplyAtTime(initialTime + 3 weeks), 0, "Supply at 3 weeks should be 0");
    }

    function test_WhenQueryingSupplyBackwardsAfterWarping() external {
        // Set initial time and create locks
        uint256 initialTime = block.timestamp;

        _createLockForUser(users.alice, 100e18, initialTime + 1 weeks);
        _createLockForUser(users.bob, 200e18, initialTime + 2 weeks);
        _createLockForUser(users.carol, 300e18, initialTime + 3 weeks);

        uint256 initialSupply = stakeWeight.totalSupply();

        // Warp 3 weeks into the future
        vm.warp(initialTime + 3 weeks);

        uint256 lastSupply;
        for (uint256 i = 0; i < 4; i++) {
            uint256 queryTime = initialTime + (3 - i) * 1 weeks;
            uint256 supplyAtTime = stakeWeight.totalSupplyAtTime(queryTime);

            if (i > 0) {
                assertGt(supplyAtTime, lastSupply, "Supply at time should increase as we query backwards");
            } else {
                assertEq(supplyAtTime, lastSupply, "Supply at time should be equal to last supply");
            }

            lastSupply = supplyAtTime;
        }

        assertEq(
            stakeWeight.totalSupplyAtTime(initialTime),
            initialSupply,
            "Supply at initial time should be the same we got at that time"
        );
        assertEq(stakeWeight.totalSupplyAtTime(block.timestamp + 1), 0, "Supply at 1 second after expiries should be 0");
    }
}
