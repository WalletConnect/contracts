// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakeWeight } from "src/StakeWeight.sol";
import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";
import { StakeWeight_Integration_Shared_Test } from "../../../shared/StakeWeight.t.sol";

contract CheckpointTotalSupply_StakingRewardDistributor_Integration_Concrete_Test is
    StakeWeight_Integration_Shared_Test
{
    function setUp() public override {
        super.setUp();

        vm.prank(users.admin);
        l2wct.disableTransferRestrictions();
    }

    function test_CallCheckpointOnStakeWeight() external {
        vm.expectCall(address(stakeWeight), abi.encodeWithSelector(stakeWeight.checkpoint.selector));
        stakingRewardDistributor.checkpointTotalSupply();
    }

    function test_IterateThroughWeeks() external {
        uint256 initialWeekCursor = stakingRewardDistributor.weekCursor();
        uint256 initialTimestamp = block.timestamp;

        // Mine blocks for 52 weeks
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS() * 52);

        stakingRewardDistributor.checkpointTotalSupply();

        uint256 newWeekCursor = stakingRewardDistributor.weekCursor();
        uint256 expectedWeeks = (block.timestamp - initialTimestamp) / 1 weeks;
        uint256 weeksIterated = (newWeekCursor - initialWeekCursor) / 1 weeks;

        assertGt(newWeekCursor, initialWeekCursor, "Week cursor should be incremented");
        assertEq(weeksIterated, expectedWeeks, "Week cursor should be incremented by the expected number of weeks");
        assertLe(weeksIterated, 52, "Should not iterate more than 52 times");
    }

    function test_CalculateBiasAndSetTotalSupply() external {
        _createLockForUser(users.alice, 1000 ether, block.timestamp + 52 weeks);

        uint256 epoch = stakeWeight.userPointEpoch(users.alice);
        StakeWeight.Point memory point = stakeWeight.userPointHistory(users.alice, epoch);

        // Force a checkpoint to ensure the point is recorded
        stakeWeight.checkpoint();

        // Move time forward two weeks to test bias calculation
        vm.warp(block.timestamp + 2 weeks);

        // Checkpoint total supply
        stakingRewardDistributor.checkpointTotalSupply();

        // Check the total supply for the current week
        uint256 currentWeek = _timestampToFloorWeek(block.timestamp);
        uint256 totalSupply = stakingRewardDistributor.totalSupplyAt(currentWeek);

        // The bias should have decreased slightly due to the slope
        assertLt(totalSupply, SafeCast.toUint256(point.bias), "Total supply should be less than initial bias");
        assertGt(totalSupply, 0, "Total supply should be greater than 0");
    }

    function test_SetTotalSupplyToZeroWhenBiasNegative() external {
        _createLockForUser(users.alice, 1000 ether, block.timestamp + 52 weeks);

        // Force a checkpoint to ensure the point is recorded
        stakeWeight.checkpoint();

        // Move time forward to ensure bias becomes negative
        vm.warp(block.timestamp + 100 weeks);

        // Checkpoint total supply
        stakingRewardDistributor.checkpointTotalSupply();

        // Check the total supply for the current week
        uint256 currentWeek = _timestampToFloorWeek(block.timestamp);
        uint256 totalSupply = stakingRewardDistributor.totalSupplyAt(currentWeek);

        assertEq(totalSupply, 0, "Total supply should be 0 when bias is negative");
    }

    function test_UpdateWeekCursor() external {
        uint256 numberOfWeeks = 3;
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS() * numberOfWeeks);
        uint256 initialWeekCursor = stakingRewardDistributor.weekCursor();

        // Checkpoint total supply
        stakingRewardDistributor.checkpointTotalSupply();

        uint256 newWeekCursor = stakingRewardDistributor.weekCursor();

        // The week cursor should be updated to include the current week plus one additional week,
        // which is 4 weeks ahead of the initial cursor
        uint256 expectedWeekCursor = initialWeekCursor + (numberOfWeeks + 1) * 1 weeks;

        assertEq(newWeekCursor, expectedWeekCursor, "Week cursor should be exactly 4 weeks ahead");

        // The new week cursor should be one week ahead of the current week
        assertEq(
            newWeekCursor,
            _timestampToFloorWeek(block.timestamp) + 1 weeks,
            "New week cursor should be one week ahead of current week"
        );
    }

    function test_RevertWhenStakeWeightNotSet() external {
        // Get the storage slot for the STAKE_WEIGHT
        bytes32 slot = keccak256(abi.encode(walletConnectConfig.STAKE_WEIGHT(), uint256(0)));

        // Load the current stake weight address from storage
        address firstStakeWeight = address(uint160(uint256(vm.load(address(walletConnectConfig), slot))));

        // Assert that the loaded address matches the one returned by getStakeWeight()
        assertEq(firstStakeWeight, walletConnectConfig.getStakeWeight(), "Stake weight should be set");

        // Set the stake weight address to zero in storage
        vm.store(address(walletConnectConfig), slot, bytes32(0));

        // Get the current stake weight address after setting it to zero
        address currentStakeWeight = walletConnectConfig.getStakeWeight();

        // Assert that the stake weight address is now zero
        assertEq(currentStakeWeight, address(0), "Stake weight should be 0 now");

        // Call checkpointTotalSupply
        vm.expectRevert();
        stakingRewardDistributor.checkpointTotalSupply();
    }
}
