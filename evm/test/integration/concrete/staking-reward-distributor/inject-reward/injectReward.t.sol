// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { IERC20Errors } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { StakeWeight_Integration_Shared_Test } from "../../../shared/StakeWeight.t.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

contract InjectReward_StakingRewardDistributor_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    uint256 constant INJECTION_AMOUNT = 1000 ether;

    function setUp() public override {
        super.setUp();
        vm.warp(_timestampToFloorWeek(block.timestamp + 1 weeks));

        vm.prank(users.admin);
        l2wct.disableTransferRestrictions();

        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), INJECTION_AMOUNT);
        vm.stopPrank();
    }

    function test_RevertWhen_ContractKilled() external {
        deal(address(l2wct), users.admin, INJECTION_AMOUNT);
        vm.prank(users.admin);
        stakingRewardDistributor.kill();

        vm.expectRevert(StakingRewardDistributor.ContractKilled.selector);
        vm.prank(users.admin);
        stakingRewardDistributor.injectReward(block.timestamp, INJECTION_AMOUNT);
    }

    function test_RevertWhen_ContractPaused() external {
        deal(address(l2wct), users.admin, INJECTION_AMOUNT);
        vm.prank(users.pauser);
        pauser.setIsStakingRewardDistributorPaused(true);

        vm.expectRevert(StakingRewardDistributor.Paused.selector);
        vm.prank(users.admin);
        stakingRewardDistributor.injectReward(block.timestamp, INJECTION_AMOUNT);
    }

    function test_RevertWhen_CallerIsNotOwner() external {
        bytes32 REWARD_MANAGER_ROLE = keccak256("REWARD_MANAGER_ROLE");
        vm.prank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.alice, REWARD_MANAGER_ROLE
            )
        );
        stakingRewardDistributor.injectReward(block.timestamp, INJECTION_AMOUNT);
    }

    modifier whenCallerHasRewardManagerRole() {
        // Admin gets REWARD_MANAGER_ROLE by default in initialize
        vm.startPrank(users.admin);
        _;
        vm.stopPrank();
    }

    function test_RevertWhen_CallerDoesntHaveEnoughTokens() external whenCallerHasRewardManagerRole {
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                users.admin,
                l2wct.balanceOf(users.admin),
                INJECTION_AMOUNT
            )
        );
        stakingRewardDistributor.injectReward(block.timestamp, INJECTION_AMOUNT);
    }

    modifier whenAmountIsGreaterThanZero() {
        deal(address(l2wct), users.admin, INJECTION_AMOUNT);
        _;
    }

    function test_RevertWhen_TimestampIsBeforeStartWeekCursor()
        external
        whenCallerHasRewardManagerRole
        whenAmountIsGreaterThanZero
    {
        uint256 pastTimestamp = stakingRewardDistributor.startWeekCursor() - 1 weeks;
        vm.expectRevert(StakingRewardDistributor.InvalidTimestamp.selector);
        stakingRewardDistributor.injectReward(pastTimestamp, INJECTION_AMOUNT);
    }

    function test_InjectRewardInThePast() external whenCallerHasRewardManagerRole whenAmountIsGreaterThanZero {
        uint256 pastTimestamp = block.timestamp - 1 weeks;
        uint256 initialBalance = l2wct.balanceOf(address(stakingRewardDistributor));
        uint256 initialLastTokenBalance = stakingRewardDistributor.lastTokenBalance();
        uint256 initialTotalDistributed = stakingRewardDistributor.totalDistributed();

        stakingRewardDistributor.injectReward(pastTimestamp, INJECTION_AMOUNT);

        assertEq(
            l2wct.balanceOf(address(stakingRewardDistributor)),
            initialBalance + INJECTION_AMOUNT,
            "Should transfer tokens from caller to contract"
        );
        assertEq(
            stakingRewardDistributor.lastTokenBalance(),
            initialLastTokenBalance + INJECTION_AMOUNT,
            "Should increase lastTokenBalance"
        );
        assertEq(
            stakingRewardDistributor.totalDistributed(),
            initialTotalDistributed + INJECTION_AMOUNT,
            "Should increase totalDistributed"
        );
        assertEq(
            stakingRewardDistributor.tokensPerWeek(_timestampToFloorWeek(pastTimestamp)),
            INJECTION_AMOUNT,
            "Should increase tokensPerWeek for the corresponding week"
        );
    }

    function test_InjectRewardInTheFuture() external whenCallerHasRewardManagerRole whenAmountIsGreaterThanZero {
        uint256 futureTimestamp = block.timestamp + 1 weeks;
        uint256 initialBalance = l2wct.balanceOf(address(stakingRewardDistributor));
        uint256 initialLastTokenBalance = stakingRewardDistributor.lastTokenBalance();
        uint256 initialTotalDistributed = stakingRewardDistributor.totalDistributed();

        stakingRewardDistributor.injectReward(futureTimestamp, INJECTION_AMOUNT);

        assertEq(
            l2wct.balanceOf(address(stakingRewardDistributor)),
            initialBalance + INJECTION_AMOUNT,
            "Should transfer tokens from caller to contract"
        );
        assertEq(
            stakingRewardDistributor.lastTokenBalance(),
            initialLastTokenBalance + INJECTION_AMOUNT,
            "Should increase lastTokenBalance"
        );
        assertEq(
            stakingRewardDistributor.totalDistributed(),
            initialTotalDistributed + INJECTION_AMOUNT,
            "Should increase totalDistributed"
        );
        assertEq(
            stakingRewardDistributor.tokensPerWeek(_timestampToFloorWeek(futureTimestamp)),
            INJECTION_AMOUNT,
            "Should increase tokensPerWeek for the corresponding week"
        );
    }

    function test_InjectRewardForCurrentWeek() external whenCallerHasRewardManagerRole whenAmountIsGreaterThanZero {
        uint256 initialBalance = l2wct.balanceOf(address(stakingRewardDistributor));
        uint256 initialLastTokenBalance = stakingRewardDistributor.lastTokenBalance();
        uint256 initialTotalDistributed = stakingRewardDistributor.totalDistributed();

        stakingRewardDistributor.injectReward(block.timestamp, INJECTION_AMOUNT);

        assertEq(
            l2wct.balanceOf(address(stakingRewardDistributor)),
            initialBalance + INJECTION_AMOUNT,
            "Should transfer tokens from caller to contract"
        );
        assertEq(
            stakingRewardDistributor.lastTokenBalance(),
            initialLastTokenBalance + INJECTION_AMOUNT,
            "Should increase lastTokenBalance"
        );
        assertEq(
            stakingRewardDistributor.totalDistributed(),
            initialTotalDistributed + INJECTION_AMOUNT,
            "Should increase totalDistributed"
        );
        assertEq(
            stakingRewardDistributor.tokensPerWeek(_timestampToFloorWeek(block.timestamp)),
            INJECTION_AMOUNT,
            "Should increase tokensPerWeek for the current week"
        );
    }
}
