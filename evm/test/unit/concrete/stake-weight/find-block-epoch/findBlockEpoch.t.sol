// SPDX-License-Identifier: MIT

pragma solidity >=0.8.25 <0.9.0;

import { Base_Test } from "test/Base.t.sol";
import { StakeWeight_Concrete_Test } from "../StakeWeight.t.sol";

contract FindBlockEpoch_StakeWeight_Unit_Concrete_Test is StakeWeight_Concrete_Test {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenBlockNumberLessThanFirstPoint() external {
        // Setup: Create a point history with at least one point
        // Assume the first point is at block 100
        stakeWeightHarness.createPointHistory(100, 1000);

        uint256 result = stakeWeightHarness.findBlockEpoch(50, 1);
        assertEq(result, 0, "Should return 0 when block number is less than the first point's block number");
    }

    function test_WhenBlockNumberEqualToPointBlockNumber() external {
        // Setup: Create a point history with multiple points
        stakeWeightHarness.createPointHistory(100, 1000);
        stakeWeightHarness.createPointHistory(200, 2000);

        uint256 result = stakeWeightHarness.findBlockEpoch(200, 2);
        assertEq(result, 2, "Should return the epoch of the point when block number matches");
    }

    function test_WhenBlockNumberBetweenTwoPoints() external {
        // Setup: Create a point history with multiple points
        stakeWeightHarness.createPointHistory(100, 1000);
        stakeWeightHarness.createPointHistory(200, 2000);
        stakeWeightHarness.createPointHistory(300, 3000);

        uint256 result = stakeWeightHarness.findBlockEpoch(250, 3);
        assertEq(result, 2, "Should return the epoch of the earlier point when block number is between two points");
    }

    function test_WhenBlockNumberGreaterThanLastPoint() external {
        // Setup: Create a point history with multiple points
        stakeWeightHarness.createPointHistory(100, 1000);
        stakeWeightHarness.createPointHistory(200, 2000);
        stakeWeightHarness.createPointHistory(300, 3000);

        uint256 result = stakeWeightHarness.findBlockEpoch(400, 3);
        assertEq(
            result, 3, "Should return the last epoch when block number is greater than the last point's block number"
        );
    }
}
