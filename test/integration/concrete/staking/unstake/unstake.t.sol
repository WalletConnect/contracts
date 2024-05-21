// SPDX-License-Identifier: UNLICENSED

import { Staking_Integration_Shared_Test } from "test/integration/shared/Staking.t.sol";

import { Staking } from "src/Staking.sol";
import { IERC20Errors } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

pragma solidity >=0.8.25 <0.9.0;

contract Unstake_Staking_Integration_Concrete_Test is Staking_Integration_Shared_Test {
    function test_RevertGiven_StakingIsPaused() external {
        vm.startPrank(users.admin);
        pauser.setIsStakingPaused(true);

        vm.expectRevert(Staking.Paused.selector);
        staking.unstake(0);
    }

    modifier givenStakingIsUnpaused() {
        assertFalse(pauser.isStakingPaused());
        _;
    }

    function test_RevertWhen_UnstakeAmountIsZero() external givenStakingIsUnpaused {
        vm.startPrank(users.permissionedNode);
        vm.expectRevert(Staking.InvalidInput.selector);
        staking.unstake(0);
    }

    function test_RevertWhen_UnstakeAmountIsGTCallerStake() external givenStakingIsUnpaused {
        stakeFrom(users.permissionedNode, defaults.MIN_STAKE());
        uint256 callerStake = staking.stakes(users.permissionedNode);
        assertEq(callerStake, defaults.MIN_STAKE());

        vm.startPrank(users.permissionedNode);
        vm.expectRevert(
            abi.encodeWithSelector(
                Staking.InsufficientStake.selector, users.permissionedNode, callerStake, callerStake + 1
            )
        );
        staking.unstake(callerStake + 1);
    }

    modifier whenCallerUnstakeAmountIsLTCallerStake() {
        _;
    }

    function test_RevertWhen_UnstakeAmountWillPutCallerStakeBelowMinimum()
        external
        givenStakingIsUnpaused
        whenCallerUnstakeAmountIsLTCallerStake
    {
        stakeFrom(users.permissionedNode, defaults.MIN_STAKE());
        uint256 callerStake = staking.stakes(users.permissionedNode);
        assertEq(callerStake, defaults.MIN_STAKE());

        vm.startPrank(users.permissionedNode);
        uint256 unstakeAmount = defaults.MIN_STAKE() - 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Staking.UnstakingBelowMinimum.selector, defaults.MIN_STAKE(), callerStake, unstakeAmount
            )
        );
        staking.unstake(unstakeAmount);
    }

    function test_WhenUnstakeAmountWillNotPutCallerStakeBelowMinimum()
        external
        givenStakingIsUnpaused
        whenCallerUnstakeAmountIsLTCallerStake
    {
        uint256 initialStake = defaults.MIN_STAKE() * 2;
        stakeFrom(users.permissionedNode, initialStake);
        assertEq(initialStake, staking.stakes(users.permissionedNode));

        uint256 unstakeAmount = defaults.MIN_STAKE();
        uint256 stakingPoolBalance = cnct.balanceOf(address(staking));
        uint256 callerBalance = cnct.balanceOf(users.permissionedNode);
        vm.expectEmit({ emitter: address(staking) });
        emit Unstaked({ node: users.permissionedNode, amount: unstakeAmount });
        vm.prank(users.permissionedNode);
        staking.unstake(unstakeAmount);
        assertEq(staking.stakes(users.permissionedNode), initialStake - unstakeAmount);
        assertEq(cnct.balanceOf(address(staking)), stakingPoolBalance - unstakeAmount);
        assertEq(cnct.balanceOf(users.permissionedNode), callerBalance + unstakeAmount);
    }

    function test_WhenUnstakeAmountEqCallerStakes() external givenStakingIsUnpaused {
        stakeFrom(users.permissionedNode, defaults.MIN_STAKE());
        uint256 callerStake = staking.stakes(users.permissionedNode);
        assertEq(callerStake, defaults.MIN_STAKE());

        uint256 stakingPoolBalance = cnct.balanceOf(address(staking));
        uint256 callerBalance = cnct.balanceOf(users.permissionedNode);
        vm.expectEmit({ emitter: address(staking) });
        emit Unstaked({ node: users.permissionedNode, amount: callerStake });
        vm.prank(users.permissionedNode);
        staking.unstake(callerStake);
        assertEq(staking.stakes(users.permissionedNode), 0);
        assertEq(cnct.balanceOf(address(staking)), stakingPoolBalance - callerStake);
        assertEq(cnct.balanceOf(users.permissionedNode), callerBalance + callerStake);
    }
}
