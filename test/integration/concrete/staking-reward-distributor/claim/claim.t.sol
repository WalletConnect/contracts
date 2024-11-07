// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { newStakingRewardDistributor } from "script/helpers/Proxy.sol";
import { StakeWeight_Integration_Shared_Test } from "../../../shared/StakeWeight.t.sol";

contract Claim_StakingRewardDistributor_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    uint256 constant WEEKS_IN_YEAR = 52;
    uint256 weeklyAmount;

    function setUp() public override {
        super.setUp();
        weeklyAmount = defaults.STAKING_REWARD_BUDGET() / WEEKS_IN_YEAR;
        // Every test should start with the weekCursor set to the current week
        vm.warp(_timestampToFloorWeek(block.timestamp + 1 weeks));
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

        uint256 contractBalance = l2wct.balanceOf(address(stakingRewardDistributor));
        assertGt(contractBalance, 0, "No rewards in the contract");
    }

    function test_RevertWhen_ContractKilled() external {
        // Kill the contract
        vm.prank(users.admin);
        stakingRewardDistributor.kill();

        vm.expectRevert(StakingRewardDistributor.ContractKilled.selector);
        stakingRewardDistributor.claim(users.alice);
    }

    modifier whenContractLive() {
        _;
    }

    function test_RevertWhen_BlockTimestampIsLessThanStartWeekCursor() external whenContractLive {
        stakingRewardDistributor = newStakingRewardDistributor({
            initialOwner: users.admin,
            init: StakingRewardDistributor.Init({
                admin: users.admin,
                startTime: block.timestamp + 1 weeks,
                emergencyReturn: users.emergencyHolder,
                config: address(walletConnectConfig)
            })
        });

        // Underflow
        vm.expectRevert();
        stakingRewardDistributor.claim(users.alice);
    }

    modifier whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor() {
        _;
    }

    function test_CheckpointTotalSupply()
        external
        whenContractLive
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        _createLockForUser(users.alice, 1000 ether, block.timestamp + 4 weeks);
        uint256 firstWeekCursor = stakingRewardDistributor.weekCursor();
        uint256 initialTotalSupply = stakingRewardDistributor.totalSupplyAt(firstWeekCursor);
        assertEq(initialTotalSupply, 0, "Total supply should be zero");

        // Set block.timestamp to be greater than weekCursor
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        // This should checkpoint the total supply
        stakingRewardDistributor.claim(users.alice);

        uint256 updatedWeekCursor = stakingRewardDistributor.weekCursor();
        // Checkpointed total supply happens at the end of the week, so we need to check the previous week
        uint256 updatedTotalSupply = stakingRewardDistributor.totalSupplyAt(updatedWeekCursor - 1 weeks);

        assertGt(updatedTotalSupply, 0, "Total supply should be greater than zero");
        assertNotEq(initialTotalSupply, updatedTotalSupply, "Total supply should be checkpointed");

        assertGt(updatedWeekCursor, firstWeekCursor, "Week cursor should be updated");
    }

    function test_UpdateLastTokenTimestamp()
        external
        whenContractLive
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        uint256 initialLastTokenTimestamp = stakingRewardDistributor.lastTokenTimestamp();
        stakingRewardDistributor.claim(users.alice);
        uint256 updatedLastTokenTimestamp = stakingRewardDistributor.lastTokenTimestamp();

        assertGt(updatedLastTokenTimestamp, initialLastTokenTimestamp, "Last token timestamp should be updated");
    }

    function test_UseUserAddressAsRecipient()
        external
        view
        whenContractLive
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        // Assume no custom recipient is set
        address recipient = stakingRewardDistributor.getRecipient(users.alice);
        assertEq(recipient, users.alice, "User's address should be used as recipient");
    }

    function test_UseCustomRecipientAddress()
        external
        whenContractLive
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        // Set a custom recipient
        vm.prank(users.alice);
        stakingRewardDistributor.setRecipient(users.bob);

        address recipient = stakingRewardDistributor.getRecipient(users.alice);
        assertEq(recipient, users.bob, "Custom recipient address should be used");
    }

    function test_NoRewardsWhenNoStakeHistory()
        external
        whenContractLive
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        uint256 claimedAmount = stakingRewardDistributor.claim(users.carol);
        assertEq(claimedAmount, 0, "Should return 0 when user has no stake history");
    }

    function test_CalculateRewardsFromFirstStake()
        external
        whenContractLive
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        // Setup: Stake for users.alice after distribution start
        uint256 amount = 1000 ether;
        uint256 lockTime = block.timestamp + 5 weeks;
        _createLockForUser(users.alice, amount, lockTime);

        // Move time forward to ensure distribution has started (1 week)
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        uint256 claimedAmount = stakingRewardDistributor.claim(users.alice);
        assertGt(claimedAmount, 0, "Should calculate rewards from user's first stake");

        uint256 totalSupply = stakingRewardDistributor.totalSupplyAt(_timestampToFloorWeek(block.timestamp));
        assertGt(totalSupply, 0, "Total supply not updated");

        uint256 userStake = stakingRewardDistributor.balanceOfAt(users.alice, block.timestamp);
        uint256 expectedStake = stakeWeight.balanceOfAt(users.alice, block.timestamp);
        assertEq(userStake, expectedStake, "User's stake not recorded correctly");

        uint256 distributedAmount = stakingRewardDistributor.tokensPerWeek(_timestampToFloorWeek(block.timestamp));
        assertGt(distributedAmount, 0, "No rewards distributed for the current week");
    }

    function test_IncludeInjectedRewards()
        external
        whenContractLive
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        // Setup: Stake for users.alice, inject rewards, wait some time
        uint256 initialAmount = 1000 ether;
        uint256 initialLockTime = block.timestamp + 4 weeks;
        _createLockForUser(users.alice, initialAmount, initialLockTime);

        // Inject additional rewards
        uint256 injectedAmount = 500 ether;
        deal(address(l2wct), address(users.admin), injectedAmount);
        vm.startPrank(address(users.admin));
        l2wct.approve(address(stakingRewardDistributor), injectedAmount);
        stakingRewardDistributor.injectRewardForCurrentWeek(injectedAmount);
        vm.stopPrank();

        // Move time forward by another week
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        uint256 claimedAmount = stakingRewardDistributor.claim(users.alice);
        // Weekly amount + injected amount
        uint256 expectedAmount = weeklyAmount + injectedAmount;
        assertEq(claimedAmount, expectedAmount, "Should include injected rewards in calculation");
    }

    function test_CalculateRewardsAcrossMultipleEpochs()
        external
        whenContractLive
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        // Setup: Stake for users.alice across multiple epochs
        uint256 initialAmount = 1000 ether;
        uint256 initialLockTime = block.timestamp + 4 weeks;
        _createLockForUser(users.alice, initialAmount, initialLockTime);

        // Move time forward by 2 week
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS() * 2);

        uint256 claimedAmount = stakingRewardDistributor.claim(users.alice);
        // Two weeks of rewards
        uint256 expectedRewards = weeklyAmount * 2;
        assertEq(claimedAmount, expectedRewards, "Claimed amount should be equal to expected rewards");

        // Verify that user's balance has increased by the claimed amount
        uint256 userBalance = l2wct.balanceOf(users.alice);
        assertEq(userBalance, claimedAmount, "User balance should reflect claimed rewards");
    }

    function test_AccountForIncreasedStake()
        external
        whenContractLive
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        // Setup: Initial stake for users.alice / users.bob, then increase stake for users.alice
        uint256 initialAmount = 1000 ether;
        uint256 initialLockTime = block.timestamp + 4 weeks;
        _createLockForUser(users.alice, initialAmount, initialLockTime);
        _createLockForUser(users.bob, initialAmount, initialLockTime);

        // Move time forward by 1 week
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        assertEq(
            stakingRewardDistributor.claim(users.alice),
            stakingRewardDistributor.claim(users.bob),
            "Same amount should be claimed for both users"
        );

        // Increase stake for users.alice
        uint256 increasedAmount = 2000 ether;
        _increaseLockAmountForUser(users.alice, increasedAmount);

        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        assertGt(
            stakingRewardDistributor.claim(users.alice),
            stakingRewardDistributor.claim(users.bob),
            "Alice should have more rewards after increasing stake"
        );
    }

    function test_ClaimRewards() external whenContractLive whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor {
        // Setup: Ensure users.alice has rewards to claim
        uint256 initialAmount = 1000 ether;
        uint256 initialLockTime = block.timestamp + 4 weeks;
        _createLockForUser(users.alice, initialAmount, initialLockTime);

        // Move time forward to accumulate rewards
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        uint256 initialBalance = l2wct.balanceOf(users.alice);
        uint256 claimedAmount = stakingRewardDistributor.claim(users.alice);

        assertEq(claimedAmount, weeklyAmount, "Should claim one weeks of rewards");
        assertEq(
            l2wct.balanceOf(users.alice), initialBalance + claimedAmount, "Should transfer correct amount of tokens"
        );
    }

    function test_EmitClaimedEvent()
        external
        whenContractLive
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        // Setup: Ensure users.alice has rewards to claim
        uint256 initialAmount = 1000 ether;
        uint256 initialLockTime = block.timestamp + 4 weeks;
        _createLockForUser(users.alice, initialAmount, initialLockTime);

        // Move time forward to accumulate rewards
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        // Calculate expected claim amount
        uint256 expectedClaimAmount = weeklyAmount;

        // Get the current user epoch and max epoch
        uint256 maxEpoch = stakeWeight.userPointEpoch(users.alice);

        vm.expectEmit(true, true, true, true);
        // First claim is always epoch 1
        emit RewardsClaimed(users.alice, users.alice, expectedClaimAmount, 1, maxEpoch);
        stakingRewardDistributor.claim(users.alice);
    }

    function test_UpdateUserClaimCursor()
        external
        whenContractLive
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        // Setup: Ensure users.alice has rewards to claim
        uint256 initialAmount = 1000 ether;
        uint256 initialLockTime = block.timestamp + 4 weeks;
        _createLockForUser(users.alice, initialAmount, initialLockTime);

        // Move time forward to accumulate rewards
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        uint256 initialCursor = stakingRewardDistributor.weekCursorOf(users.alice);
        stakingRewardDistributor.claim(users.alice);
        uint256 updatedCursor = stakingRewardDistributor.weekCursorOf(users.alice);

        assertGt(updatedCursor, initialCursor, "Should update user's claim cursor");
    }

    function test_ReturnTotalClaimedAmount()
        external
        whenContractLive
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        // Setup: Ensure users.alice has rewards to claim
        uint256 initialAmount = 1000 ether;
        uint256 initialLockTime = block.timestamp + 4 weeks;
        _createLockForUser(users.alice, initialAmount, initialLockTime);

        // Move time forward to accumulate rewards
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        uint256 claimedAmount = stakingRewardDistributor.claim(users.alice);
        assertGt(claimedAmount, 0, "Should return the total claimed amount");
        assertEq(claimedAmount, weeklyAmount, "Should claim one week of rewards");
    }
}
