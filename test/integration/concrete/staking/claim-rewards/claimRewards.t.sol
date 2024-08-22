// SPDX-License-Identifier: MIT

import { Staking_Integration_Shared_Test } from "test/integration/shared/Staking.t.sol";
import { Staking } from "src/Staking.sol";
import { IERC20Errors } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

pragma solidity >=0.8.25 <0.9.0;

contract ClaimRewards_Staking_Integration_Concrete_Test is Staking_Integration_Shared_Test {
    function test_RevertGivenCallerHasNoPendingRewards() external {
        uint256 pendingRewards = staking.pendingRewards(users.permissionedNode);
        assertEq(pendingRewards, 0);
        vm.startPrank(users.permissionedNode);
        vm.expectRevert(abi.encodeWithSelector(Staking.NoRewards.selector, users.permissionedNode));
        staking.claimRewards();
    }

    modifier givenCallerHasPendingRewards(address caller) {
        stakeFromAndReward(caller, defaults.MIN_STAKE());
        _;
    }

    function test_RevertGiven_stakingHasNoAllowanceFromRewardsVault()
        external
        givenCallerHasPendingRewards(users.permissionedNode)
    {
        vm.startPrank(users.permissionedNode);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector,
                address(staking),
                cnkt.allowance(address(staking), users.treasury),
                defaults.EPOCH_REWARD_EMISSION()
            )
        );
        staking.claimRewards();
    }

    modifier givenStakingHasAllowanceFromRewardsVault() {
        vm.startPrank(users.treasury);
        cnkt.approve(address(staking), defaults.EPOCH_REWARD_EMISSION());
        vm.stopPrank();
        _;
    }

    function test_RevertGiven_RewardsVaultDoesntHaveEnoughBalance()
        external
        givenCallerHasPendingRewards(users.permissionedNode)
        givenStakingHasAllowanceFromRewardsVault
    {
        vm.startPrank(users.permissionedNode);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                address(users.treasury),
                cnkt.balanceOf(address(users.treasury)),
                defaults.EPOCH_REWARD_EMISSION()
            )
        );
        staking.claimRewards();
    }

    function test_GivenRewardsVaultHasEnoughBalance()
        external
        givenCallerHasPendingRewards(users.permissionedNode)
        givenStakingHasAllowanceFromRewardsVault
    {
        vm.startPrank(users.admin);
        cnkt.mint(address(users.treasury), defaults.EPOCH_REWARD_EMISSION());
        vm.stopPrank();
        uint256 initialPendingRewards = staking.pendingRewards(users.permissionedNode);
        uint256 initialTreasuryBalance = cnkt.balanceOf(address(users.treasury));
        vm.expectEmit({ emitter: address(staking) });
        emit RewardsClaimed(users.permissionedNode, initialPendingRewards);
        vm.prank(users.permissionedNode);
        staking.claimRewards();
        uint256 finalPendingRewards = staking.pendingRewards(users.permissionedNode);
        uint256 finalTreasuryBalance = cnkt.balanceOf(address(users.treasury));
        assertEq(finalPendingRewards, 0);
        assertEq(finalTreasuryBalance, initialTreasuryBalance - initialPendingRewards);
    }
}
