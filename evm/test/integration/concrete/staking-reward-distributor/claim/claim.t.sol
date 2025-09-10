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
        disableTransferRestrictions();
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

        vm.startPrank(users.alice);
        vm.expectRevert(StakingRewardDistributor.ContractKilled.selector);
        stakingRewardDistributor.claim(users.alice);
    }

    modifier whenContractLive() {
        _;
    }

    function test_RevertWhen_UnauthorizedClaimer()
        external
        whenContractLive
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        // Try to claim as an unauthorized address
        vm.prank(users.attacker);
        vm.expectRevert(StakingRewardDistributor.UnauthorizedClaimer.selector);
        stakingRewardDistributor.claim(users.alice);
    }

    modifier whenAuthorizedClaimer() {
        _;
    }

    function test_RevertWhen_BlockTimestampIsLessThanStartWeekCursor()
        external
        whenContractLive
        whenAuthorizedClaimer
    {
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
        vm.startPrank(users.alice);
        vm.expectRevert();
        stakingRewardDistributor.claim(users.alice);
    }

    modifier whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor() {
        _;
    }

    function test_ClaimWithPermanentLock()
        external
        whenContractLive
        whenAuthorizedClaimer
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        // Setup: Create permanent lock for alice
        uint256 amount = 1000 ether;
        uint256 duration = 52 weeks; // 52 weeks permanent lock
        
        deal(address(l2wct), users.alice, amount);
        vm.startPrank(users.alice);
        l2wct.approve(address(stakeWeight), amount);
        stakeWeight.createPermanentLock(amount, duration);
        vm.stopPrank();
        
        // Move time forward by 2 weeks
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS() * 2);
        
        // Claim rewards
        vm.prank(users.alice);
        uint256 claimedAmount = stakingRewardDistributor.claim(users.alice);
        
        // Should receive 2 weeks of rewards
        uint256 expectedRewards = weeklyAmount * 2;
        assertEq(claimedAmount, expectedRewards, "Permanent lock should receive full rewards");
    }
    
    function test_ConvertDecayingToPermanentAndClaim()
        external
        whenContractLive
        whenAuthorizedClaimer
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        // Setup: Create decaying lock for alice
        uint256 amount = 1000 ether;
        uint256 lockTime = block.timestamp + 52 weeks;
        _createLockForUser(users.alice, amount, lockTime);
        
        // Move time forward by 1 week and claim
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());
        vm.prank(users.alice);
        uint256 firstClaim = stakingRewardDistributor.claim(users.alice);
        assertGt(firstClaim, 0, "Should receive rewards for decaying period");
        
        // Convert to permanent (52 weeks)
        vm.prank(users.alice);
        stakeWeight.convertToPermanent(52 weeks);
        
        // Move time forward by 2 more weeks
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS() * 2);
        
        // Claim rewards again
        vm.prank(users.alice);
        uint256 secondClaim = stakingRewardDistributor.claim(users.alice);
        
        // Should receive 2 weeks of rewards at permanent weight
        assertEq(secondClaim, weeklyAmount * 2, "Should receive rewards for permanent period");
    }
    
    function test_ConvertPermanentToDecayingAndClaim()
        external
        whenContractLive
        whenAuthorizedClaimer
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        // Setup: Create permanent lock for alice
        uint256 amount = 1000 ether;
        uint256 duration = 52 weeks;
        
        deal(address(l2wct), users.alice, amount);
        vm.startPrank(users.alice);
        l2wct.approve(address(stakeWeight), amount);
        stakeWeight.createPermanentLock(amount, duration);
        vm.stopPrank();
        
        // Move time forward by 1 week and claim
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());
        vm.prank(users.alice);
        uint256 firstClaim = stakingRewardDistributor.claim(users.alice);
        assertEq(firstClaim, weeklyAmount, "Should receive rewards for permanent period");
        
        // Trigger unlock to convert back to decaying
        vm.prank(users.alice);
        stakeWeight.triggerUnlock();
        
        // Move time forward by 2 more weeks
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS() * 2);
        
        // Claim rewards again
        vm.prank(users.alice);
        uint256 secondClaim = stakingRewardDistributor.claim(users.alice);
        
        // Should receive 2 weeks of rewards at decaying rate
        assertEq(secondClaim, weeklyAmount * 2, "Should receive rewards for new decaying period");
    }
    
    function test_CheckpointTotalSupply()
        external
        whenContractLive
        whenAuthorizedClaimer
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        _createLockForUser(users.alice, 1000 ether, block.timestamp + 4 weeks);
        uint256 firstWeekCursor = stakingRewardDistributor.weekCursor();
        uint256 initialTotalSupply = stakingRewardDistributor.totalSupplyAt(firstWeekCursor);
        assertEq(initialTotalSupply, 0, "Total supply should be zero");

        // Set block.timestamp to be greater than weekCursor
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        // This should checkpoint the total supply
        vm.prank(users.alice);
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
        whenAuthorizedClaimer
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        uint256 initialLastTokenTimestamp = stakingRewardDistributor.lastTokenTimestamp();
        vm.prank(users.alice);
        stakingRewardDistributor.claim(users.alice);
        uint256 updatedLastTokenTimestamp = stakingRewardDistributor.lastTokenTimestamp();

        assertGt(updatedLastTokenTimestamp, initialLastTokenTimestamp, "Last token timestamp should be updated");
    }

    function test_UseUserAddressAsRecipient()
        external
        view
        whenContractLive
        whenAuthorizedClaimer
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        // Assume no custom recipient is set
        address recipient = stakingRewardDistributor.getRecipient(users.alice);
        assertEq(recipient, users.alice, "User's address should be used as recipient");
    }

    function test_UseCustomRecipientAddress()
        external
        whenContractLive
        whenAuthorizedClaimer
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
        whenAuthorizedClaimer
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        vm.prank(users.carol);
        uint256 claimedAmount = stakingRewardDistributor.claim(users.carol);
        assertEq(claimedAmount, 0, "Should return 0 when user has no stake history");
    }

    function test_CalculateRewardsFromFirstStake()
        external
        whenContractLive
        whenAuthorizedClaimer
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        // Setup: Stake for users.alice after distribution start
        uint256 amount = 1000 ether;
        uint256 lockTime = block.timestamp + 5 weeks;
        _createLockForUser(users.alice, amount, lockTime);

        // Move time forward to ensure distribution has started (1 week)
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        vm.prank(users.alice);
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
        whenAuthorizedClaimer
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

        vm.prank(users.alice);
        uint256 claimedAmount = stakingRewardDistributor.claim(users.alice);
        // Weekly amount + injected amount
        uint256 expectedAmount = weeklyAmount + injectedAmount;
        assertEq(claimedAmount, expectedAmount, "Should include injected rewards in calculation");
    }

    function test_CalculateRewardsAcrossMultipleEpochs()
        external
        whenContractLive
        whenAuthorizedClaimer
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        // Setup: Stake for users.alice across multiple epochs
        uint256 initialAmount = 1000 ether;
        uint256 initialLockTime = block.timestamp + 4 weeks;
        _createLockForUser(users.alice, initialAmount, initialLockTime);

        // Move time forward by 2 week
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS() * 2);

        vm.prank(users.alice);
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
        whenAuthorizedClaimer
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        // Setup: Initial stake for users.alice / users.bob, then increase stake for users.alice
        uint256 initialAmount = 1000 ether;
        uint256 initialLockTime = block.timestamp + 4 weeks;
        _createLockForUser(users.alice, initialAmount, initialLockTime);
        _createLockForUser(users.bob, initialAmount, initialLockTime);

        // Move time forward by 1 week
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        vm.prank(users.alice);
        uint256 aliceClaimedAmount = stakingRewardDistributor.claim(users.alice);
        vm.prank(users.bob);
        uint256 bobClaimedAmount = stakingRewardDistributor.claim(users.bob);

        assertEq(aliceClaimedAmount, bobClaimedAmount, "Same amount should be claimed for both users");

        // Increase stake for users.alice
        uint256 increasedAmount = 2000 ether;
        _increaseLockAmountForUser(users.alice, increasedAmount);

        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        vm.prank(users.alice);
        uint256 aliceNewClaimedAmount = stakingRewardDistributor.claim(users.alice);
        vm.prank(users.bob);
        uint256 bobNewClaimedAmount = stakingRewardDistributor.claim(users.bob);

        assertGt(aliceNewClaimedAmount, bobNewClaimedAmount, "Alice should have more rewards after increasing stake");
    }

    function test_ClaimRewards()
        external
        whenContractLive
        whenAuthorizedClaimer
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        // Setup: Ensure users.alice has rewards to claim
        uint256 initialAmount = 1000 ether;
        uint256 initialLockTime = block.timestamp + 4 weeks;
        _createLockForUser(users.alice, initialAmount, initialLockTime);

        // Move time forward to accumulate rewards
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        uint256 initialBalance = l2wct.balanceOf(users.alice);
        vm.prank(users.alice);
        uint256 claimedAmount = stakingRewardDistributor.claim(users.alice);

        assertEq(claimedAmount, weeklyAmount, "Should claim one weeks of rewards");
        assertEq(
            l2wct.balanceOf(users.alice), initialBalance + claimedAmount, "Should transfer correct amount of tokens"
        );
    }

    function test_EmitClaimedEvent()
        external
        whenContractLive
        whenAuthorizedClaimer
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
        vm.prank(users.alice);
        stakingRewardDistributor.claim(users.alice);
    }

    function test_UpdateUserClaimCursor()
        external
        whenContractLive
        whenAuthorizedClaimer
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        // Setup: Ensure users.alice has rewards to claim
        uint256 initialAmount = 1000 ether;
        uint256 initialLockTime = block.timestamp + 4 weeks;
        _createLockForUser(users.alice, initialAmount, initialLockTime);

        // Move time forward to accumulate rewards
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        uint256 initialCursor = stakingRewardDistributor.weekCursorOf(users.alice);
        vm.prank(users.alice);
        stakingRewardDistributor.claim(users.alice);
        uint256 updatedCursor = stakingRewardDistributor.weekCursorOf(users.alice);

        assertGt(updatedCursor, initialCursor, "Should update user's claim cursor");
    }

    function test_ReturnTotalClaimedAmount()
        external
        whenContractLive
        whenAuthorizedClaimer
        whenBlockTimestampIsGreaterThanOrEqualToStartWeekCursor
    {
        // Setup: Ensure users.alice has rewards to claim
        uint256 initialAmount = 1000 ether;
        uint256 initialLockTime = block.timestamp + 4 weeks;
        _createLockForUser(users.alice, initialAmount, initialLockTime);

        // Move time forward to accumulate rewards
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        // Claim as user
        vm.prank(users.alice);
        uint256 claimedAmount = stakingRewardDistributor.claim(users.alice);
        assertGt(claimedAmount, 0, "Should return the total claimed amount");
        assertEq(claimedAmount, weeklyAmount, "Should claim one week of rewards");
    }

    function test_ClaimAsRecipient() external {
        // Setup: Ensure users.alice has rewards to claim
        uint256 initialAmount = 1000 ether;
        uint256 initialLockTime = block.timestamp + 4 weeks;
        _createLockForUser(users.alice, initialAmount, initialLockTime);

        // Set a custom recipient
        vm.prank(users.alice);
        stakingRewardDistributor.setRecipient(users.bob);

        // Mine a week
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        // Claim as recipient
        vm.prank(users.bob);
        uint256 claimedAmount = stakingRewardDistributor.claim(users.alice);
        assertEq(claimedAmount, weeklyAmount, "Should claim one week of rewards");
        assertEq(l2wct.balanceOf(users.bob), claimedAmount, "Should transfer correct amount of tokens");
    }

    function test_ClaimAsUser() external {
        // Setup: Ensure users.alice has rewards to claim
        uint256 initialAmount = 1000 ether;
        uint256 initialLockTime = block.timestamp + 4 weeks;
        _createLockForUser(users.alice, initialAmount, initialLockTime);

        // Mine a week
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        // Claim as user
        vm.prank(users.alice);
        uint256 claimedAmount = stakingRewardDistributor.claim(users.alice);
        assertEq(claimedAmount, weeklyAmount, "Should claim one week of rewards");
    }
}
