// SPDX-License-Identifier: MIT

pragma solidity >=0.8.25 <0.9.0;

import { Base_Test } from "test/Base.t.sol";
import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract StakingRewardDistributorHarness is StakingRewardDistributor {
    function timestampToFloorWeek(uint256 _timestamp) external pure returns (uint256) {
        return _timestampToFloorWeek(_timestamp);
    }
}

// Clone of test/unit/concrete/stake-weight/timestamp-to-floor-week/timestampToFloorWeek.t.sol
contract TimestampToFloorWeek_StakingRewardDistributor_Unit_Concrete_Test is Base_Test {
    StakingRewardDistributorHarness stakingRewardDistributorHarness;

    function setUp() public override {
        super.setUp();
        deployCoreConditionally();

        stakingRewardDistributorHarness = StakingRewardDistributorHarness(
            address(
                new ERC1967Proxy(
                    address(new StakingRewardDistributorHarness()),
                    abi.encodeWithSelector(
                        StakingRewardDistributor.initialize.selector,
                        StakingRewardDistributor.Init({
                            admin: address(users.admin),
                            startTime: block.timestamp,
                            emergencyReturn: address(users.emergencyHolder),
                            config: address(walletConnectConfig)
                        })
                    )
                )
            )
        );
    }

    function test_WhenTimestampExactlyOnWeekBoundary() external view {
        uint256 timestamp = 1 weeks;
        assertEq(
            stakingRewardDistributorHarness.timestampToFloorWeek(timestamp),
            timestamp,
            "Should return the same timestamp"
        );
    }

    function test_WhenTimestampInMiddleOfWeek() external view {
        uint256 timestamp = 1 weeks + 3 days;
        assertEq(
            stakingRewardDistributorHarness.timestampToFloorWeek(timestamp),
            1 weeks,
            "Should return the timestamp of the start of that week"
        );
    }

    function test_WhenTimestampIsZero() external view {
        assertEq(stakingRewardDistributorHarness.timestampToFloorWeek(0), 0, "Should return zero");
    }

    function test_WhenTimestampIsVeryLarge() external view {
        uint256 largeTimestamp = 52 weeks + 3 days;
        assertEq(
            stakingRewardDistributorHarness.timestampToFloorWeek(largeTimestamp),
            52 weeks,
            "Should correctly round down to the nearest week"
        );
    }
}
