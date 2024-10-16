// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakeWeight } from "src/StakeWeight.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { StakeWeight_Integration_Shared_Test } from "test/integration/shared/StakeWeight.t.sol";
import { console2 } from "forge-std/console2.sol";

contract TotalSupplyAt_StakeWeight_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    function test_WhenQueryingSupplyAtBlockBeforeAnyLocks() external view {
        assertEq(stakeWeight.totalSupplyAt(block.number), 0, "Total supply should be zero before any locks");
    }

    function test_WhenQueryingSupplyAtCurrentBlock() external {
        uint256 amount = 100e18;
        uint256 lockDuration = 1 weeks;
        _createLockForUser(users.alice, amount, block.timestamp + lockDuration);

        assertEq(
            stakeWeight.totalSupplyAt(block.number),
            stakeWeight.totalSupply(),
            "Total supply at current block should match regular totalSupply"
        );
    }

    function test_WhenQueryingSupplyAtBlockWithActiveLocks() external {
        uint256 aliceAmount = 100e18;
        uint256 bobAmount = 200e18;
        uint256 lockDuration1 = 1 weeks;
        uint256 lockDuration2 = 2 weeks;

        _createLockForUser(users.alice, aliceAmount, block.timestamp + lockDuration1);
        _createLockForUser(users.bob, bobAmount, block.timestamp + lockDuration2);

        _mineBlocks(100);
        uint256 supplyAtBlock = stakeWeight.totalSupplyAt(block.number);

        assertGt(supplyAtBlock, 0, "Supply at block should be greater than zero");
        assertLe(
            supplyAtBlock,
            stakeWeight.totalSupply(),
            "Supply at block should be less than or equal to current totalSupply"
        );
    }

    function test_WhenQueryingSupplyAtBlockAfterSomeLocksHaveExpired() external {
        uint256 aliceAmount = 100e18;
        uint256 bobAmount = 200e18;
        uint256 lockDuration1 = 1 weeks;
        uint256 lockDuration2 = 2 weeks;

        _createLockForUser(users.alice, aliceAmount, block.timestamp + lockDuration1);
        _createLockForUser(users.bob, bobAmount, block.timestamp + lockDuration2);

        uint256 initialSupply = stakeWeight.totalSupply();
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS() + 1);

        uint256 supplyAtBlock = stakeWeight.totalSupplyAt(block.number);

        assertLt(supplyAtBlock, initialSupply, "Supply at block should be less than the original totalSupply");
        assertEq(supplyAtBlock, stakeWeight.totalSupply(), "Supply at block should be equal to current totalSupply");
        assertEq(
            supplyAtBlock,
            stakeWeight.balanceOf(users.bob),
            "Supply at block should be equal to bob's balance, as alice's expired"
        );
    }

    function test_WhenQueryingSupplyAtBlockAfterAllLocksHaveExpired() external {
        uint256 amount1 = 100e18;
        uint256 amount2 = 200e18;
        uint256 lockDuration = 1 weeks;

        _createLockForUser(users.alice, amount1, block.timestamp + lockDuration);
        _createLockForUser(users.bob, amount2, block.timestamp + lockDuration);

        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        assertEq(stakeWeight.totalSupplyAt(block.number), 0, "Total supply should be zero after all locks have expired");
    }

    function test_WhenLocksHaveDifferentDurations() external {
        uint256 aliceAmount = 100e18;
        uint256 bobAmount = 200e18;
        uint256 lockDuration1 = 1 weeks;
        uint256 lockDuration2 = 4 weeks;

        _createLockForUser(users.alice, aliceAmount, block.timestamp + lockDuration1);
        _createLockForUser(users.bob, bobAmount, block.timestamp + lockDuration2);

        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS() * 2);

        uint256 supplyAtBlock = stakeWeight.totalSupplyAt(block.number);

        _mineBlocks(1);

        assertGt(supplyAtBlock, 0, "Supply at block should be greater than zero");
        assertEq(
            stakeWeight.totalSupplyAt(block.number),
            stakeWeight.totalSupply(),
            "Supply at block should be equal to current totalSupply"
        );
        assertEq(
            stakeWeight.totalSupplyAtTime(block.timestamp),
            stakeWeight.totalSupplyAt(block.number),
            "Supply at time should be equal to supply at block"
        );
    }

    function test_WhenQueryingSupplyBackwardsAfterCreatingLocks() external {
        uint256 initialBlock = block.number;
        uint256 initialTime = block.timestamp;

        _createLockForUser(users.alice, 100e18, initialTime + 1 weeks);
        _createLockForUser(users.bob, 200e18, initialTime + 2 weeks);
        _createLockForUser(users.carol, 300e18, initialTime + 3 weeks);

        uint256 initialSupply = stakeWeight.totalSupply();

        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS() * 3);

        uint256 blockIntervals = (block.number - initialBlock) / 4;

        uint256 lastSupply = stakeWeight.totalSupplyAt(block.number);
        for (uint256 i = 1; i <= 4; i++) {
            uint256 queryBlock = block.number - (i * blockIntervals);
            uint256 supplyAtBlock = stakeWeight.totalSupplyAt(queryBlock);
            assertGt(supplyAtBlock, lastSupply, "Supply should increase as we query backwards");
            lastSupply = supplyAtBlock;
        }

        assertEq(
            stakeWeight.totalSupplyAt(initialBlock),
            initialSupply,
            "Supply at initial block should match the initial supply"
        );
    }

    function test_WhenQueryingAcrossEpochBoundaries() external {
        uint256 initialBlock = block.number;
        uint256 initialTime = block.timestamp;

        _createLockForUser(users.alice, 100e18, initialTime + 1 weeks);
        _createLockForUser(users.bob, 200e18, initialTime + 2 weeks);

        uint256 midBlock = initialBlock + defaults.ONE_WEEK_IN_BLOCKS() * 3 / 2;
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS() * 3 / 2);

        _createLockForUser(users.carol, 300e18, block.timestamp + 2 weeks);

        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS() * 2);

        uint256 supplyAtMidBlock = stakeWeight.totalSupplyAt(midBlock);
        uint256 supplyBeforeMidBlock = stakeWeight.totalSupplyAt(midBlock - 1);
        uint256 supplyAfterMidBlock = stakeWeight.totalSupplyAt(midBlock + 1);

        assertGt(supplyAtMidBlock, 0, "Supply at mid block should be greater than zero");
        assertLe(supplyBeforeMidBlock, supplyAtMidBlock, "Supply should not decrease when a lock is created");
        assertGe(supplyAtMidBlock, supplyAfterMidBlock, "Supply should decrease as we query forward");
    }

    function test_WhenQueryingFutureBlock() external {
        vm.expectRevert(abi.encodeWithSelector(StakeWeight.BadBlockNumber.selector, block.number + 1));
        stakeWeight.totalSupplyAt(block.number + 1);
    }
}
