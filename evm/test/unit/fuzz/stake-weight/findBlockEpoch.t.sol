// SPDX-License-Identifier: MIT

pragma solidity >=0.8.25 <0.9.0;

import { StakeWeight } from "src/StakeWeight.sol";
import { StakeWeight_Concrete_Test } from "test/unit/concrete/stake-weight/StakeWeight.t.sol";

contract FindBlockEpoch_StakeWeight_Unit_Fuzz_Test is StakeWeight_Concrete_Test {
    uint256 constant MAX_EPOCHS = 100;

    function setUp() public override {
        super.setUp();
    }

    function testFuzz_FindBlockEpoch(uint256 blockNumber, uint256 maxEpoch) public {
        maxEpoch = bound(maxEpoch, 1, MAX_EPOCHS);

        uint256 lastBlockNumber = _generatePointHistory(maxEpoch);

        blockNumber = bound(blockNumber, 0, lastBlockNumber + 1000);

        uint256 result = stakeWeightHarness.findBlockEpoch(blockNumber, maxEpoch);

        // Verify the result
        assertTrue(result <= maxEpoch, "Result should not exceed maxEpoch");

        StakeWeight.Point memory resultPoint = stakeWeightHarness.pointHistory(result);

        if (blockNumber < 1) {
            // For block numbers less than the first point, it should return the first epoch (0)
            assertEq(result, 0, "Should return first epoch for block numbers less than the first point");
        } else {
            assertTrue(
                resultPoint.blockNumber <= blockNumber, "Result epoch's block number should be <= input block number"
            );

            if (result < maxEpoch) {
                StakeWeight.Point memory nextPoint = stakeWeightHarness.pointHistory(result + 1);
                assertTrue(
                    nextPoint.blockNumber > blockNumber, "Next epoch's block number should be > input block number"
                );
            }
        }
    }

    function testFuzz_FindBlockEpoch_LastBlockNumber(uint256 maxEpoch) public {
        maxEpoch = bound(maxEpoch, 1, MAX_EPOCHS);

        uint256 lastBlockNumber = _generatePointHistory(maxEpoch);

        uint256 result = stakeWeightHarness.findBlockEpoch(lastBlockNumber, maxEpoch);

        assertEq(
            result, maxEpoch, "Should return the last epoch when block number equals the last point's block number"
        );
    }

    function testFuzz_FindBlockEpoch_MaxEpochZero(uint256 blockNumber) public {
        // Create a single point history
        stakeWeightHarness.createPointHistory(100, 1000);

        uint256 result = stakeWeightHarness.findBlockEpoch(blockNumber, 0);

        assertEq(result, 0, "Should always return 0 when maxEpoch is 0");
    }

    function testFuzz_FindBlockEpoch_BlockNumberBeyondLastPoint(uint256 blockNumber, uint256 maxEpoch) public {
        maxEpoch = bound(maxEpoch, 1, MAX_EPOCHS);

        uint256 lastBlockNumber = _generatePointHistory(maxEpoch);

        blockNumber = bound(blockNumber, lastBlockNumber + 1, type(uint256).max);

        uint256 result = stakeWeightHarness.findBlockEpoch(blockNumber, maxEpoch);

        assertEq(result, maxEpoch, "Should return the last epoch when block number is beyond the last point");
    }

    function _generatePointHistory(uint256 maxEpoch) internal returns (uint256 lastBlockNumber) {
        lastBlockNumber = 0;
        for (uint256 i = 0; i <= maxEpoch; i++) {
            lastBlockNumber = lastBlockNumber + (i * 100) + 1;
            stakeWeightHarness.createPointHistory(lastBlockNumber, i * 1000);
        }
    }
}
