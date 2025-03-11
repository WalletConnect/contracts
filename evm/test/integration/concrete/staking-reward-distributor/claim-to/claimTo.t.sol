// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { StakeWeight_Integration_Shared_Test } from "../../../shared/StakeWeight.t.sol";

contract ClaimTo_StakingRewardDistributor_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    uint256 constant WEEKS_IN_YEAR = 52;
    uint256 weeklyAmount;

    function setUp() public override {
        super.setUp();
        weeklyAmount = defaults.STAKING_REWARD_BUDGET() / WEEKS_IN_YEAR;
        vm.warp(_timestampToFloorWeek(block.timestamp + 1 weeks));

        // Allowlist
        vm.startPrank(users.manager);
        l2wct.setAllowedFrom(address(stakeWeight), true);
        l2wct.setAllowedTo(address(stakeWeight), true);
        l2wct.setAllowedTo(address(stakingRewardDistributor), true);
        l2wct.setAllowedFrom(address(stakingRewardDistributor), true);

        _distributeAnnualBudget();
    }

    function _distributeAnnualBudget() internal {
        uint256 currentWeek = _timestampToFloorWeek(block.timestamp);

        deal(address(l2wct), users.admin, defaults.STAKING_REWARD_BUDGET());

        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), defaults.STAKING_REWARD_BUDGET());

        for (uint256 i = 0; i < WEEKS_IN_YEAR; i++) {
            uint256 weekTimestamp = currentWeek + (i * 1 weeks);
            stakingRewardDistributor.injectReward({ timestamp: weekTimestamp, amount: weeklyAmount });
        }

        vm.stopPrank();
    }

    function test_RevertWhen_TransferRestrictionsEnabled() external {
        // Setup: Ensure users.alice has rewards to claim
        uint256 initialAmount = 1000 ether;
        uint256 initialLockTime = block.timestamp + 4 weeks;
        _createLockForUser(users.alice, initialAmount, initialLockTime);

        // Move time forward to accumulate rewards
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        vm.prank(users.alice);
        vm.expectRevert(StakingRewardDistributor.TransferRestrictionsEnabled.selector);
        stakingRewardDistributor.claimTo(users.bob);
    }

    modifier whenTransferRestrictionsDisabled() {
        vm.prank(users.admin);
        l2wct.disableTransferRestrictions();
        _;
    }

    function test_RevertWhen_ContractKilled() external whenTransferRestrictionsDisabled {
        vm.prank(users.admin);
        stakingRewardDistributor.kill();

        vm.startPrank(users.alice);
        vm.expectRevert(StakingRewardDistributor.ContractKilled.selector);
        stakingRewardDistributor.claimTo(users.bob);
    }

    modifier whenContractNotKilled() {
        _;
    }

    function test_ClaimToZeroAddress() external whenTransferRestrictionsDisabled whenContractNotKilled {
        // Setup: Ensure users.alice has rewards to claim
        uint256 initialAmount = 1000 ether;
        uint256 initialLockTime = block.timestamp + 4 weeks;
        uint256 initialLastTokenBalance = stakingRewardDistributor.lastTokenBalance();
        _createLockForUser(users.alice, initialAmount, initialLockTime);

        // Move time forward to accumulate rewards
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        vm.startPrank(users.alice);
        uint256 claimedAmount = stakingRewardDistributor.claimTo(address(0));
        assertGt(claimedAmount, 0, "Should have claimable balance");
        assertEq(l2wct.balanceOf(address(0)), 0, "Zero address should have no balance");
        assertLt(
            stakingRewardDistributor.lastTokenBalance(),
            initialLastTokenBalance,
            "Last token balance should have decreased"
        );
        assertGt(l2wct.balanceOf(users.alice), 0, "Alice should have balance");
        assertEq(
            stakingRewardDistributor.lastTokenTimestamp(),
            block.timestamp,
            "Last token timestamp should be current timestamp"
        );
        assertEq(stakingRewardDistributor.claim(users.alice), 0, "Should have no claimable balance");
    }

    modifier whenToAddressIsNotZero() {
        _;
    }

    function test_ClaimToCustomRecipient()
        external
        whenTransferRestrictionsDisabled
        whenContractNotKilled
        whenToAddressIsNotZero
    {
        // Setup: Ensure users.alice has rewards to claim
        uint256 initialAmount = 1000 ether;
        uint256 initialLockTime = block.timestamp + 4 weeks;
        _createLockForUser(users.alice, initialAmount, initialLockTime);

        // Move time forward to accumulate rewards
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        // Claim to a custom recipient
        vm.prank(users.alice);
        uint256 claimedAmount = stakingRewardDistributor.claimTo(users.bob);

        assertEq(claimedAmount, weeklyAmount, "Should claim one week of rewards");
        assertEq(l2wct.balanceOf(users.bob), claimedAmount, "Should transfer to custom recipient");
    }

    function test_EmitClaimedEventWithCustomRecipient()
        external
        whenTransferRestrictionsDisabled
        whenContractNotKilled
        whenToAddressIsNotZero
    {
        // Setup: Ensure users.alice has rewards to claim
        uint256 initialAmount = 1000 ether;
        uint256 initialLockTime = block.timestamp + 4 weeks;
        _createLockForUser(users.alice, initialAmount, initialLockTime);

        // Move time forward to accumulate rewards
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        // Get the current user epoch and max epoch
        uint256 maxEpoch = stakeWeight.userPointEpoch(users.alice);

        vm.expectEmit(true, true, true, true);
        emit RewardsClaimed(users.alice, users.bob, weeklyAmount, 1, maxEpoch);

        vm.prank(users.alice);
        stakingRewardDistributor.claimTo(users.bob);
    }
}
