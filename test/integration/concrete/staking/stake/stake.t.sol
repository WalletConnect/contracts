// SPDX-License-Identifier: UNLICENSED

import { Staking_Integration_Shared_Test } from "test/integration/shared/Staking.t.sol";

import { Staking } from "src/Staking.sol";
import { IERC20Errors } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

pragma solidity >=0.8.25 <0.9.0;

contract Stake_Staking_Integration_Concrete_Test is Staking_Integration_Shared_Test {
    function test_RevertGiven_StakingIsPaused() external {
        vm.startPrank(users.admin);
        pauser.setIsStakingPaused(true);

        vm.expectRevert(Staking.Paused.selector);
        staking.stake(0);
    }

    modifier givenStakingIsUnpaused() {
        _;
    }

    modifier givenStakingAllowlistIsOn() {
        _;
    }

    function test_RevertWhen_CallerIsNotAPermissionedNode() external givenStakingIsUnpaused givenStakingAllowlistIsOn {
        vm.startPrank(users.attacker);
        vm.expectRevert(Staking.NotWhitelisted.selector);
        staking.stake(0);
    }

    modifier whenCallerIsAPermissionedNode() {
        vm.prank(users.admin);
        permissionedNodeRegistry.whitelistNode(users.permissionedNode);
        _;
    }

    function test_RevertWhen_AmountToStakeLTMinStake()
        external
        givenStakingIsUnpaused
        givenStakingAllowlistIsOn
        whenCallerIsAPermissionedNode
    {
        vm.startPrank(users.permissionedNode);
        uint256 amount = defaults.MIN_STAKE() - 1;
        vm.expectRevert(abi.encodeWithSelector(Staking.StakingBelowMinimum.selector, defaults.MIN_STAKE(), amount));
        staking.stake(amount);
    }

    modifier whenAmountToStakeGTEMinStake() {
        _;
    }

    function test_RevertGiven_CallerHasNotApprovedStakingAmount()
        external
        givenStakingIsUnpaused
        givenStakingAllowlistIsOn
        whenCallerIsAPermissionedNode
        whenAmountToStakeGTEMinStake
    {
        vm.startPrank(users.permissionedNode);
        uint256 amount = defaults.MIN_STAKE();
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector,
                address(staking),
                brr.allowance(address(staking), users.permissionedNode),
                amount
            )
        );
        staking.stake(amount);
    }

    modifier whenCallerHasApprovedStakingAmount(address caller) {
        vm.startPrank(caller);
        brr.approve(address(staking), defaults.MIN_STAKE());
        vm.stopPrank();
        _;
    }

    function test_RevertGiven_CallerHasNotEnoughBalance()
        external
        givenStakingIsUnpaused
        givenStakingAllowlistIsOn
        whenCallerIsAPermissionedNode
        whenAmountToStakeGTEMinStake
        whenCallerHasApprovedStakingAmount(users.permissionedNode)
    {
        uint256 amount = defaults.MIN_STAKE();
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                users.permissionedNode,
                brr.balanceOf(users.permissionedNode),
                amount
            )
        );
        vm.prank(users.permissionedNode);
        staking.stake(amount);
    }

    function test_GivenCallerHasEnoughBalance()
        external
        givenStakingIsUnpaused
        givenStakingAllowlistIsOn
        whenCallerIsAPermissionedNode
        whenAmountToStakeGTEMinStake
        whenCallerHasApprovedStakingAmount(users.permissionedNode)
    {
        vm.startPrank({ msgSender: users.admin });
        brr.mint(users.permissionedNode, defaults.MIN_STAKE());
        vm.stopPrank();
        uint256 initialStake = staking.stakes(users.permissionedNode);
        uint256 initialStakingBalance = brr.balanceOf(address(staking));
        uint256 initialNodeBalance = brr.balanceOf(users.permissionedNode);
        vm.startPrank({ msgSender: users.permissionedNode });
        vm.expectEmit({ emitter: address(staking) });
        emit Staked(users.permissionedNode, defaults.MIN_STAKE());
        staking.stake(defaults.MIN_STAKE());
        // it should increase the {stakes} for the caller
        vm.assertEq(staking.stakes(users.permissionedNode), initialStake + defaults.MIN_STAKE());
        // it should increase the balance of the staking contract by the amount of tokens staked
        vm.assertEq(brr.balanceOf(address(staking)), initialStakingBalance + defaults.MIN_STAKE());
        // it should decrease the balance of the caller by the amount of tokens staked
        vm.assertEq(brr.balanceOf(users.permissionedNode), initialNodeBalance - defaults.MIN_STAKE());
    }

    modifier whenCallerIsNotAPermissionedNode() {
        _;
    }

    function test_GivenCallerHasEnoughBalanceAndAllowlistIsOff()
        external
        givenStakingIsUnpaused
        whenAmountToStakeGTEMinStake
        whenCallerHasApprovedStakingAmount(users.nonPermissionedNode)
        whenCallerIsNotAPermissionedNode
    {
        vm.startPrank({ msgSender: users.admin });
        // set allowlist to false
        staking.setStakingAllowlist(false);
        brr.mint(users.nonPermissionedNode, defaults.MIN_STAKE());
        vm.stopPrank();
        uint256 initialStake = staking.stakes(users.nonPermissionedNode);
        uint256 initialStakingBalance = brr.balanceOf(address(staking));
        uint256 initialNodeBalance = brr.balanceOf(users.nonPermissionedNode);
        vm.startPrank({ msgSender: users.nonPermissionedNode });
        vm.expectEmit({ emitter: address(staking) });
        emit Staked(users.nonPermissionedNode, defaults.MIN_STAKE());
        staking.stake(defaults.MIN_STAKE());
        // it should increase the {stakes} for the caller
        vm.assertEq(staking.stakes(users.nonPermissionedNode), initialStake + defaults.MIN_STAKE());
        // it should increase the balance of the staking contract by the amount of tokens staked
        vm.assertEq(brr.balanceOf(address(staking)), initialStakingBalance + defaults.MIN_STAKE());
        // it should decrease the balance of the caller by the amount of tokens staked
        vm.assertEq(brr.balanceOf(users.nonPermissionedNode), initialNodeBalance - defaults.MIN_STAKE());
    }
}
