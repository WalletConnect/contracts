// SPDX-License-Identifier: MIT

pragma solidity >=0.8.25 <0.9.0;

import { Base_Test } from "test/Base.t.sol";
import { StakeWeight_Concrete_Test } from "../StakeWeight.t.sol";

contract TimestampToFloorWeek_StakeWeight_Unit_Concrete_Test is StakeWeight_Concrete_Test {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenTimestampExactlyOnWeekBoundary() external view {
        uint256 timestamp = 1 weeks;
        assertEq(stakeWeightHarness.timestampToFloorWeek(timestamp), timestamp, "Should return the same timestamp");
    }

    function test_WhenTimestampInMiddleOfWeek() external view {
        uint256 timestamp = 1 weeks + 3 days;
        assertEq(
            stakeWeightHarness.timestampToFloorWeek(timestamp),
            1 weeks,
            "Should return the timestamp of the start of that week"
        );
    }

    function test_WhenTimestampIsZero() external view {
        assertEq(stakeWeightHarness.timestampToFloorWeek(0), 0, "Should return zero");
    }

    function test_WhenTimestampIsVeryLarge() external view {
        uint256 largeTimestamp = 52 weeks + 3 days;
        assertEq(
            stakeWeightHarness.timestampToFloorWeek(largeTimestamp),
            52 weeks,
            "Should correctly round down to the nearest week"
        );
    }
}
