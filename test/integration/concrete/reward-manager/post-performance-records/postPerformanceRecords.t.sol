// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Staking_Integration_Shared_Test } from "test/integration/shared/Staking.t.sol";
import { RewardManager } from "src/RewardManager.sol";

contract PostPerformanceRecords_RewardManager_Integration_Concrete_Test is Staking_Integration_Shared_Test {
    uint256 internal defaultReportingEpoch;

    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
        defaultReportingEpoch = defaults.FIRST_EPOCH();
    }

    function test_RevertWhen_CallerNotOwner() external {
        // Make the attacker the caller
        vm.startPrank(users.attacker);

        // Run the test
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.attacker));
        rewardManager.postPerformanceRecords(
            RewardManager.PerformanceData({
                nodes: new address[](0),
                performance: new uint256[](0),
                reportingEpoch: defaultReportingEpoch
            })
        );
    }

    modifier whenCallerOwner() {
        vm.startPrank(users.admin);
        _;
    }

    modifier whenReportingEpochIsGTLastUpdatedEpoch() {
        _;
    }

    modifier whenInputArraysMatchInLength() {
        _;
    }

    function test_RevertWhen_ReportingEpochLTELastUpdatedEpoch() external whenCallerOwner {
        uint256 lastUpdatedEpoch = rewardManager.lastUpdatedEpoch();
        // Run the test
        vm.expectRevert(RewardManager.PerformanceDataAlreadyUpdated.selector);
        rewardManager.postPerformanceRecords(
            RewardManager.PerformanceData({
                nodes: new address[](0),
                performance: new uint256[](0),
                reportingEpoch: lastUpdatedEpoch
            })
        );
    }

    function test_RevertWhen_InputArraysDontMatchInLength()
        external
        whenCallerOwner
        whenReportingEpochIsGTLastUpdatedEpoch
    {
        // Run the test
        vm.expectRevert(RewardManager.MismatchedDataLengths.selector);
        rewardManager.postPerformanceRecords(
            RewardManager.PerformanceData({
                nodes: new address[](1),
                performance: new uint256[](0),
                reportingEpoch: defaultReportingEpoch
            })
        );
    }

    function test_RevertWhen_PerformanceSumIsZero()
        external
        whenCallerOwner
        whenReportingEpochIsGTLastUpdatedEpoch
        whenInputArraysMatchInLength
    {
        // Run the test
        vm.expectRevert(RewardManager.TotalPerformanceZero.selector);
        rewardManager.postPerformanceRecords(
            RewardManager.PerformanceData({
                nodes: new address[](1),
                performance: new uint256[](1),
                reportingEpoch: defaultReportingEpoch
            })
        );
    }

    function test_PostPerformanceRecords_givenOnlyOneNodeIsActive()
        external
        whenCallerOwner
        whenReportingEpochIsGTLastUpdatedEpoch
        whenInputArraysMatchInLength
    {
        // Variables
        uint256 nodesLength = 1;
        // Prepare the input arrays
        address[] memory nodes = new address[](nodesLength);
        uint256[] memory performance = new uint256[](nodesLength);
        nodes[0] = createUser("node");
        performance[0] = 100;
        // Prev state
        uint256 prevPendingRewards = staking.pendingRewards(nodes[0]);
        stakeFrom(nodes[0], defaults.MIN_STAKE());

        vm.expectEmit({ emitter: address(rewardManager) });
        emit PerformanceUpdated(defaultReportingEpoch, defaults.EPOCH_REWARD_EMISSION());

        // Run the test
        vm.startPrank(users.admin);
        rewardManager.postPerformanceRecords(
            RewardManager.PerformanceData({
                nodes: nodes,
                performance: performance,
                reportingEpoch: defaultReportingEpoch
            })
        );
        vm.stopPrank();
        // Assert
        assertEq(staking.pendingRewards(nodes[0]), prevPendingRewards + defaults.EPOCH_REWARD_EMISSION());
        assertEq(rewardManager.lastUpdatedEpoch(), defaultReportingEpoch);
    }

    function test_PostPerformanceRecords_givenMaxNodesAreActive()
        external
        whenCallerOwner
        whenReportingEpochIsGTLastUpdatedEpoch
        whenInputArraysMatchInLength
    {
        // Variables
        uint256 nodesLength = defaults.MAX_NODES();
        // Prepare the input arrays
        address[] memory nodes = new address[](nodesLength);
        uint256[] memory performance = new uint256[](nodesLength);
        for (uint256 i = 0; i < nodesLength; i++) {
            nodes[i] = createUser(string(abi.encodePacked("node", i)));
            performance[i] = 100;
            stakeFrom(nodes[i], defaults.MIN_STAKE());
        }
        vm.expectEmit({ emitter: address(rewardManager) });
        emit PerformanceUpdated(defaultReportingEpoch, defaults.EPOCH_REWARD_EMISSION());

        // Run the test
        vm.startPrank(users.admin);
        rewardManager.postPerformanceRecords(
            RewardManager.PerformanceData({
                nodes: nodes,
                performance: performance,
                reportingEpoch: defaultReportingEpoch
            })
        );
        vm.stopPrank();
        // Assert
        uint256 expectedReward = defaults.EPOCH_REWARD_EMISSION() / nodesLength;
        assertEq(staking.pendingRewards(nodes[0]), expectedReward);
        assertEq(rewardManager.lastUpdatedEpoch(), defaultReportingEpoch);
    }

    function testGasProfiling_PostPerformanceRecords()
        external
        whenCallerOwner
        whenReportingEpochIsGTLastUpdatedEpoch
        whenInputArraysMatchInLength
    {
        // Variables
        uint256 nodesLength = defaults.MAX_NODES();
        // Prepare the input arrays
        address[] memory nodes = new address[](nodesLength);
        uint256[] memory performance = new uint256[](nodesLength);
        for (uint256 i = 0; i < nodesLength; i++) {
            nodes[i] = createUser(string(abi.encodePacked("user", i)));
            performance[i] = i == 0 ? 0 : 100;
            stakeFrom(nodes[i], defaults.MIN_STAKE());
        }
        vm.expectEmit({ emitter: address(rewardManager) });
        emit PerformanceUpdated(defaultReportingEpoch, defaults.EPOCH_REWARD_EMISSION());

        vm.startPrank(users.admin);
        // Run the first time (storage slot are empty) -> 1276450 gas
        rewardManager.postPerformanceRecords(
            RewardManager.PerformanceData({
                nodes: nodes,
                performance: performance,
                reportingEpoch: defaultReportingEpoch
            })
        );
        // Run the second time (storage slots are updated) -> 421450 gas
        rewardManager.postPerformanceRecords(
            RewardManager.PerformanceData({
                nodes: nodes,
                performance: performance,
                reportingEpoch: defaultReportingEpoch + 1
            })
        );
    }
}
