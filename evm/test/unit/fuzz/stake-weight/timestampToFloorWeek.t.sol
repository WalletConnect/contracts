// SPDX-License-Identifier: MIT

pragma solidity >=0.8.25 <0.9.0;

import { StakeWeight_Concrete_Test } from "test/unit/concrete/stake-weight/StakeWeight.t.sol";

contract TimestampToFloorWeek_StakeWeight_Unit_Fuzz_Test is StakeWeight_Concrete_Test {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_TimestampToFloorWeek(uint256 timestamp) public view {
        uint256 result = stakeWeightHarness.timestampToFloorWeek(timestamp);

        // Verify the result
        assertTrue(result <= timestamp, "Result should not exceed input timestamp");
        assertEq(result % 1 weeks, 0, "Result should be a multiple of 1 week");
        assertTrue(timestamp - result < 1 weeks, "Difference between input and result should be less than 1 week");
    }

    function testFuzz_TimestampToFloorWeek_ExactWeek(uint256 numberOfWeeks) public view {
        numberOfWeeks = bound(numberOfWeeks, 1, 1000); // Limit to reasonable number of weeks
        uint256 timestamp = numberOfWeeks * 1 weeks;
        uint256 result = stakeWeightHarness.timestampToFloorWeek(timestamp);
        assertEq(result, timestamp, "Should return the same value for exact week multiples");
    }

    function testFuzz_TimestampToFloorWeek_MidWeek(uint256 numberOfWeeks, uint256 offset) public view {
        numberOfWeeks = bound(numberOfWeeks, 1, 1000); // Limit to reasonable number of weeks
        offset = bound(offset, 1, 1 weeks - 1); // Offset within a week, but not exactly a week
        uint256 timestamp = numberOfWeeks * 1 weeks + offset;
        uint256 result = stakeWeightHarness.timestampToFloorWeek(timestamp);
        assertEq(result, numberOfWeeks * 1 weeks, "Should return the start of the week for mid-week timestamps");
    }

    function testFuzz_TimestampToFloorWeek_ConsecutiveDays(uint256 startTimestamp) public view {
        startTimestamp = bound(startTimestamp, 0, type(uint248).max - 7 days);

        // Floor the start timestamp to the beginning of its week
        uint256 weekStart = stakeWeightHarness.timestampToFloorWeek(startTimestamp);

        // Test for 8 days to ensure we cover the transition to the next week
        for (uint256 i = 0; i < 8; i++) {
            uint256 currentTimestamp = weekStart + i * 1 days;
            uint256 currentResult = stakeWeightHarness.timestampToFloorWeek(currentTimestamp);

            if (i < 7) {
                assertEq(currentResult, weekStart, "Should return the same week start for all days within the week");
            } else {
                assertEq(currentResult, weekStart + 1 weeks, "Should return the next week start for the 8th day");
            }
        }
    }

    function testFuzz_TimestampToFloorWeek_EdgeCases(uint256 timestamp) public view {
        timestamp = bound(timestamp, 0, type(uint256).max);
        uint256 result = stakeWeightHarness.timestampToFloorWeek(timestamp);

        assertTrue(result <= timestamp, "Result should not exceed input timestamp");
        assertEq(result % 1 weeks, 0, "Result should be a multiple of 1 week");
        assertTrue(timestamp - result < 1 weeks, "Difference between input and result should be less than 1 week");
    }
}
