// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { IERC20, IERC20Errors } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { StakeWeight_Integration_Shared_Test } from "../../../shared/StakeWeight.t.sol";
import { console2 } from "forge-std/console2.sol";

contract Feed_StakingRewardDistributor_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    uint256 constant FEED_AMOUNT = 1000 ether;

    function setUp() public override {
        super.setUp();

        vm.startPrank(users.alice);
        l2wct.approve(address(stakingRewardDistributor), FEED_AMOUNT);
        vm.stopPrank();
    }

    function test_RevertWhen_ContractIsNotLive() external {
        vm.prank(users.admin);
        stakingRewardDistributor.kill();

        vm.prank(users.alice);
        vm.expectRevert(StakingRewardDistributor.ContractKilled.selector);
        stakingRewardDistributor.feed(FEED_AMOUNT);
    }

    modifier whenContractIsLive() {
        _;
    }

    function test_RevertWhen_CallerHasInsufficientBalance() external whenContractIsLive {
        vm.startPrank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, users.alice, l2wct.balanceOf(users.alice), FEED_AMOUNT
            )
        );
        stakingRewardDistributor.feed(FEED_AMOUNT);
        vm.stopPrank();
    }

    modifier whenCallerHasSufficientBalance() {
        deal(address(l2wct), users.alice, FEED_AMOUNT);
        _;
    }

    function test_RevertWhen_AmountIsZero() external whenContractIsLive whenCallerHasSufficientBalance {
        _mineBlocks(10);
        uint256 initialBalance = l2wct.balanceOf(address(stakingRewardDistributor));
        uint256 initialLastTokenBalance = stakingRewardDistributor.lastTokenBalance();

        vm.prank(users.alice);
        vm.expectEmit(true, true, true, true);
        emit Feed(0);
        bool result = stakingRewardDistributor.feed(0);

        assertEq(
            l2wct.balanceOf(address(stakingRewardDistributor)),
            initialBalance,
            "Should not tokens from caller to contract"
        );
        assertEq(stakingRewardDistributor.lastTokenBalance(), initialLastTokenBalance, "Should keep lastTokenBalance");
        assertTrue(result, "Should return true");

        // Check if _checkpointToken was called
        assertEq(stakingRewardDistributor.lastTokenTimestamp(), block.timestamp, "Should update lastTokenTimestamp");
    }

    function test_WhenAmountIsGreaterThanZero() external whenContractIsLive whenCallerHasSufficientBalance {
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());
        uint256 initialBalance = l2wct.balanceOf(address(stakingRewardDistributor));
        uint256 initialLastTokenBalance = stakingRewardDistributor.lastTokenBalance();

        // Distribute rewards between lastTokenTimestamp's week and block.timestamp weeks
        uint256 lastTokenWeek = _timestampToFloorWeek(stakingRewardDistributor.lastTokenTimestamp());
        uint256 currentWeek = _timestampToFloorWeek(block.timestamp);

        vm.prank(users.alice);
        vm.expectEmit(true, true, true, true);
        emit Feed(FEED_AMOUNT);
        bool result = stakingRewardDistributor.feed(FEED_AMOUNT);

        assertEq(
            l2wct.balanceOf(address(stakingRewardDistributor)),
            initialBalance + FEED_AMOUNT,
            "Should transfer tokens from caller to contract"
        );
        assertEq(
            stakingRewardDistributor.lastTokenBalance(),
            initialLastTokenBalance + FEED_AMOUNT,
            "Should increase lastTokenBalance"
        );
        assertTrue(result, "Should return true");

        // Check if _checkpointToken was called, by checking if the weeks got the FEED_AMOUNT

        if (lastTokenWeek == currentWeek) {
            uint256 actualReward = stakingRewardDistributor.tokensPerWeek(lastTokenWeek);
            assertApproxEqAbs(actualReward, FEED_AMOUNT, 1, "Reward distribution mismatch for single week");
        } else {
            // Check rewards for lastTokenWeek and the following week

            uint256 actualRewardWeek1 = stakingRewardDistributor.tokensPerWeek(lastTokenWeek);
            assertGt(actualRewardWeek1, 0, "Reward distribution mismatch for week 1");
            uint256 actualRewardWeek2 = stakingRewardDistributor.tokensPerWeek(lastTokenWeek + 1 weeks);
            assertGt(actualRewardWeek2, 0, "Reward distribution mismatch for week 2");

            assertApproxEqAbs(actualRewardWeek1 + actualRewardWeek2, FEED_AMOUNT, 1, "Reward distribution mismatch");
        }

        // Check if _checkpointToken was called
        assertEq(stakingRewardDistributor.lastTokenTimestamp(), block.timestamp, "Should update lastTokenTimestamp");
    }
}
