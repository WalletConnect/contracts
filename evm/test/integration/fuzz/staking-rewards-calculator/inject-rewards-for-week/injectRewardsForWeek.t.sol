// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { StakingRewardsCalculator } from "src/StakingRewardsCalculator.sol";
import { StakingRewardsCalculator_Integration_Shared_Test } from
    "test/integration/shared/StakingRewardsCalculator.t.sol";
import { SimpleAccount } from "test/mocks/SimpleAccount.sol";

contract InjectRewardsForWeek_StakingRewardsCalculator_Integration_Fuzz_Test is
    StakingRewardsCalculator_Integration_Shared_Test
{
    uint256 constant MAX_SUPPLY = 1e9; // 1 billion tokens
    uint256 constant PRECISION = 1e18;

    function setUp() public override {
        super.setUp();
        // Give admin enough tokens for all tests
        deal(address(l2wct), users.admin, MAX_SUPPLY * PRECISION);
    }

    /// @dev Test injection with existing rewards and varying stake amounts
    function testFuzz_ExistingRewardsLessThanCalculated(
        uint256 stakeAmount,
        uint256 existingRewards,
        uint256 lockDuration
    )
        public
    {
        // Bound inputs to realistic values
        stakeAmount = bound(stakeAmount, 0, MAX_SUPPLY * PRECISION); // Max 1B tokens
        existingRewards = bound(existingRewards, 1 ether, MAX_SUPPLY * PRECISION); // Max 1B tokens
        lockDuration = bound(lockDuration, 1 weeks, stakeWeight.maxLock()); // 1-2 years lock

        // Setup initial state
        uint256 timestamp = _timestampToFloorWeek(block.timestamp);
        uint256 endTime = block.timestamp + lockDuration;

        // Create lock with bounded stake amount
        if (stakeAmount > 0) {
            _createLockForUser(users.alice, stakeAmount, endTime);
        }

        // Inject initial rewards
        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), existingRewards);
        stakingRewardDistributor.injectReward(timestamp, existingRewards);
        vm.stopPrank();

        // Preview expected rewards
        try calculator.previewRewards(address(walletConnectConfig), timestamp) returns (uint256 expectedRewards, int256)
        {
            // Skip if existing rewards would be >= expected rewards
            vm.assume(existingRewards < expectedRewards);

            // Inject additional rewards
            uint256 rewards = _calculateAndInjectRewards(address(walletConnectConfig), timestamp, false, bytes(""));

            // Verify rewards
            assertEq(
                rewards, expectedRewards - existingRewards, "Should inject difference between expected and existing"
            );
            assertEq(
                l2wct.balanceOf(address(stakingRewardDistributor)),
                rewards + existingRewards,
                "Distributor should have total rewards"
            );
            assertEq(
                stakingRewardDistributor.tokensPerWeek(timestamp),
                rewards + existingRewards,
                "Distributor should record total rewards"
            );
        } catch {
            // If preview reverts (e.g. NoStakeWeight), injection should also revert
            _calculateAndInjectRewards(address(walletConnectConfig), timestamp, true, bytes(""));
        }
    }

    /// @dev Test regular injection with varying stake amounts
    function testFuzz_RegularInjection(uint256 stakeAmount, uint256 lockDuration) public {
        // Bound inputs to realistic values
        stakeAmount = bound(stakeAmount, 0, MAX_SUPPLY * PRECISION); // Max 1B tokens
        lockDuration = bound(lockDuration, 1 weeks, stakeWeight.maxLock()); // 1-2 years lock

        // Setup initial state
        uint256 timestamp = _timestampToFloorWeek(block.timestamp);
        uint256 endTime = block.timestamp + lockDuration;

        bool shouldRevert = false;
        bytes memory revertData = bytes("");
        // Create lock with bounded stake weight
        if (stakeAmount > 0) {
            _createLockForUser(users.alice, stakeAmount, endTime);
        }

        stakingRewardDistributor.checkpointTotalSupply();

        uint256 supplyAt = stakingRewardDistributor.totalSupplyAt(timestamp);

        if (supplyAt == 0) {
            shouldRevert = true;
            revertData = abi.encodeWithSelector(StakingRewardsCalculator.NoStakeWeight.selector);
        }

        // Inject rewards
        uint256 rewards = _calculateAndInjectRewards(address(walletConnectConfig), timestamp, shouldRevert, bytes(""));

        assertEq(l2wct.balanceOf(address(stakingRewardDistributor)), rewards, "Distributor should have rewards");
        assertEq(stakingRewardDistributor.tokensPerWeek(timestamp), rewards, "Distributor should record rewards");
    }

    /// @dev Test injection with different config addresses
    function testFuzz_DifferentConfigs(address config, uint256 stakeAmount) public {
        // Bound stake amount to max supply
        stakeAmount = bound(stakeAmount, 0, MAX_SUPPLY * PRECISION);

        // Skip only the valid config address
        vm.assume(config != address(walletConnectConfig));

        // Setup initial state
        uint256 timestamp = _timestampToFloorWeek(block.timestamp);

        // Create lock with bounded stake amount
        if (stakeAmount > 0) {
            _createLockForUser(users.alice, stakeAmount, block.timestamp + 52 weeks);
        }

        // Should revert for any invalid config address
        _calculateAndInjectRewards(config, timestamp, true, bytes(""));
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
            if (revertData.length > 0) {
                vm.expectRevert(revertData);
            } else {
                vm.expectRevert();
            }
            admin.executeTx(target, functionCall, true);
            return 0;
        } else {
            bytes memory result = admin.executeTx(target, functionCall, true);
            return abi.decode(result, (uint256));
        }
    }
}
