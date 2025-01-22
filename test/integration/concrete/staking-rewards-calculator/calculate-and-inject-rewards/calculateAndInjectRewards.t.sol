// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakingRewardsCalculator_Integration_Shared_Test } from "../../../shared/StakingRewardsCalculator.t.sol";
import { SimpleAccount } from "test/mocks/SimpleAccount.sol";
import { StakingRewardsCalculator } from "src/StakingRewardsCalculator.sol";

contract CalculateAndInjectRewards_StakingRewardsCalculator_Integration_Test is
    StakingRewardsCalculator_Integration_Shared_Test
{
    uint256 constant STAKE_AMOUNT = 5_000_000 ether;
    uint256 constant REWARDS_AMOUNT = 10_000 ether;
    uint256 constant EXPECTED_WEEKLY_REWARD = 2816.059 ether;

    uint256 defaultTimestamp;

    function setUp() public override {
        super.setUp();
        defaultTimestamp = _timestampToFloorWeek(block.timestamp);
        deal(address(l2wct), users.admin, REWARDS_AMOUNT);
    }

    function test_RevertWhen_ConfigIsZeroAddress() external {
        vm.expectRevert();
        _calculateAndInjectRewards(address(0), defaultTimestamp, true, bytes(""));
    }

    modifier whenConfigIsNotZeroAddress() {
        _;
    }

    function test_RevertWhen_TimestampNotThursday() external whenConfigIsNotZeroAddress {
        uint256 nonThursdayTimestamp = defaultTimestamp + 1 days;
        _calculateAndInjectRewards(
            address(walletConnectConfig),
            nonThursdayTimestamp,
            true,
            abi.encodePacked(StakingRewardsCalculator.NotThursday.selector)
        );
    }

    function test_RevertWhen_TimestampIsInFuture() external whenConfigIsNotZeroAddress {
        uint256 futureTimestamp = defaultTimestamp + 1 weeks;
        _calculateAndInjectRewards(
            address(walletConnectConfig),
            futureTimestamp,
            true,
            abi.encodeWithSelector(StakingRewardsCalculator.FutureWeek.selector, futureTimestamp, block.timestamp)
        );
    }

    modifier whenTimestampIsPresentOrBefore() {
        _;
    }

    function test_RevertWhen_NoStakeWeight() external whenConfigIsNotZeroAddress whenTimestampIsPresentOrBefore {
        _calculateAndInjectRewards(
            address(walletConnectConfig),
            defaultTimestamp,
            true,
            abi.encodeWithSelector(StakingRewardsCalculator.NoStakeWeight.selector)
        );
    }

    modifier whenTotalSupplyOfStakeWeightIsNotZero() {
        _createLockForUser(users.alice, STAKE_AMOUNT, block.timestamp + 52 weeks);
        _;
    }

    function test_RevertWhen_TokenApprovalFails()
        external
        whenConfigIsNotZeroAddress
        whenTimestampIsPresentOrBefore
        whenTotalSupplyOfStakeWeightIsNotZero
    {
        MockFailingToken mockToken = new MockFailingToken();
        vm.etch(address(l2wct), address(mockToken).code);
        _calculateAndInjectRewards(
            address(walletConnectConfig),
            defaultTimestamp,
            true,
            abi.encodeWithSelector(StakingRewardsCalculator.ApprovalFailed.selector)
        );
    }

    modifier whenTokenApprovalSucceedsOrNotRequired() {
        _;
    }

    function test_RevertWhen_RewardsAlreadyInjected()
        external
        whenConfigIsNotZeroAddress
        whenTimestampIsPresentOrBefore
        whenTotalSupplyOfStakeWeightIsNotZero
        whenTokenApprovalSucceedsOrNotRequired
    {
        uint256 timestamp = defaultTimestamp;
        (uint256 previewRewards,) = calculator.previewRewards(address(walletConnectConfig), timestamp);
        _calculateAndInjectRewards(address(walletConnectConfig), timestamp, false, bytes(""));

        _calculateAndInjectRewards(
            address(walletConnectConfig),
            timestamp,
            true,
            abi.encodeWithSelector(StakingRewardsCalculator.RewardsAlreadyInjected.selector, timestamp, previewRewards)
        );
    }

    modifier whenExistingRewardsAreLessThanCalculatedRewards() {
        vm.prank(users.admin);
        stakingRewardDistributor.injectReward(defaultTimestamp, 1 ether);
        _;
    }

    modifier whenRewardsDontExistForWeek() {
        _;
    }

    function test_CalculateAndInjectRewards_SingleStaker()
        external
        whenConfigIsNotZeroAddress
        whenTimestampIsPresentOrBefore
        whenTotalSupplyOfStakeWeightIsNotZero
        whenTokenApprovalSucceedsOrNotRequired
        whenRewardsDontExistForWeek
    {
        // Given: Alice stakes 500_000 tokens for 1 year (52/208 weight ratio)
        skip(1 weeks);
        uint256 rewards = _calculateAndInjectRewards(
            address(walletConnectConfig), _timestampToFloorWeek(block.timestamp), false, bytes("")
        );

        // Then: Rewards should be 2816 tokens (1000 * 12% / 52)
        assertApproxEqAbs(rewards, EXPECTED_WEEKLY_REWARD, 1e16, "Rewards should match known calculation");
    }

    function test_CalculateAndInjectRewards_TwoStakers()
        external
        whenConfigIsNotZeroAddress
        whenTimestampIsPresentOrBefore
        whenTotalSupplyOfStakeWeightIsNotZero
        whenTokenApprovalSucceedsOrNotRequired
        whenRewardsDontExistForWeek
    {
        // Given: Alice and Bob each stake 500_000 tokens for 1 year
        // Alice -> Already done in whenTotalSupplyOfStakeWeightIsNotZero modifier
        _createLockForUser(users.bob, STAKE_AMOUNT, block.timestamp + 52 weeks);

        // When: We calculate rewards
        skip(1 weeks);
        uint256 rewards = _calculateAndInjectRewards(address(walletConnectConfig), defaultTimestamp, false, bytes(""));

        // Then: Rewards should be around double (more flexibility for the test)
        assertApproxEqAbs(rewards, EXPECTED_WEEKLY_REWARD * 2, 1e20, "Rewards should be double for two equal stakers");
    }

    function _calculateAndInjectRewards(
        address config,
        uint256 timestamp,
        bool shouldRevert,
        bytes memory revertData
    )
        internal
        returns (uint256)
    {
        SimpleAccount admin = SimpleAccount(users.admin);
        bytes memory functionCall = abi.encodeCall(calculator.injectRewardsForWeek, (config, timestamp));
        address target = address(calculator);
        if (shouldRevert) {
            vm.expectRevert(revertData, users.admin);
            admin.executeTx(target, functionCall, true);
            return 0;
        } else {
            bytes memory result = admin.executeTx(target, functionCall, true);
            return abi.decode(result, (uint256));
        }
    }
}

contract MockFailingToken {
    function approve(address, uint256) external pure returns (bool) {
        return false;
    }

    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }
}
