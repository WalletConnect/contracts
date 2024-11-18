// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Base_Test } from "test/Base.t.sol";
import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { newStakingRewardDistributor, newStakeWeight } from "script/helpers/Proxy.sol";
import { console2 } from "forge-std/console2.sol";

contract StakingRewardDistributor_Test is Base_Test {
    uint256 public constant YEAR = 365 days;

    function setUp() public override {
        super.setUp();

        deployCoreConditionally();
        disableTransferRestrictions();
        // Mint l2wct tokens to users
        deal(address(l2wct), users.alice, 1000e18);
        deal(address(l2wct), users.bob, 1000e18);

        // Approve StakeWeight to spend l2wct
        vm.prank(users.alice);
        l2wct.approve(address(stakeWeight), type(uint256).max);
        vm.prank(users.bob);
        l2wct.approve(address(stakeWeight), type(uint256).max);
    }

    function testInitialized() public view {
        uint256 latestTimestamp = block.timestamp;
        uint256 startWeekCursor = (latestTimestamp / 1 weeks) * 1 weeks;

        assertEq(stakingRewardDistributor.startWeekCursor(), startWeekCursor);
        assertEq(stakingRewardDistributor.lastTokenTimestamp(), startWeekCursor);
        assertEq(stakingRewardDistributor.weekCursor(), startWeekCursor);
        assertEq(stakingRewardDistributor.emergencyReturn(), users.emergencyHolder);
    }

    function testCheckpointToken() public {
        // Setup users and locks
        address[] memory testUsers = new address[](5);
        testUsers[0] = users.alice;
        testUsers[1] = users.bob;
        testUsers[2] = users.carol;

        uint256[] memory unlockTimes = new uint256[](5);
        unlockTimes[0] = block.timestamp + 30 days;
        unlockTimes[1] = block.timestamp + 30 days;
        unlockTimes[2] = block.timestamp + 30 days;

        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 80_000e18;
        amounts[1] = 90_000e18;
        amounts[2] = 100_000e18;

        _setupUsersAndLocks(testUsers, unlockTimes, amounts);

        // Test checkpointToken
        uint256 latestTimestamp = block.timestamp;

        uint256 rewardAmount = 888e18;

        deal(address(l2wct), address(stakingRewardDistributor), rewardAmount);

        vm.warp(block.timestamp + 1);

        uint256 preCheckpointBalance = l2wct.balanceOf(address(stakingRewardDistributor));
        stakingRewardDistributor.checkpointToken();

        stakingRewardDistributor.checkpointToken();

        assertEq(
            stakingRewardDistributor.lastTokenBalance(),
            rewardAmount,
            "Last token balance should match transferred amount"
        );

        uint256 lastTokenTimestamp = stakingRewardDistributor.lastTokenTimestamp();
        assertGt(
            lastTokenTimestamp, latestTimestamp, "Last token timestamp should be greater than the latest timestamp"
        );

        uint256 weekTimestamp = (latestTimestamp / 1 weeks) * 1 weeks;
        uint256 tokensPerWeek = stakingRewardDistributor.tokensPerWeek(weekTimestamp);
        assertEq(tokensPerWeek, rewardAmount, "Tokens per week should match the transferred amount");
        assertEq(
            stakingRewardDistributor.lastTokenBalance(),
            preCheckpointBalance,
            "Last token balance should match pre-checkpoint balance"
        );
    }

    function testOneUserBalanceEqualsSupply() public {
        // Setup one user with a lock
        address[] memory testUsers = new address[](1);
        testUsers[0] = users.alice;

        uint256[] memory unlockTimes = new uint256[](1);
        unlockTimes[0] = block.timestamp + 30 days;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 80_000e18;

        _setupUsersAndLocks(testUsers, unlockTimes, amounts);

        // Get the current timestamp and calculate week cursors
        uint256 latestTimestamp = block.timestamp;
        uint256 weekCursor = _timestampToFloorWeek(latestTimestamp);
        uint256 nextWeekCursor = weekCursor + 1 weeks;

        // Check balances and supply at current week cursor
        uint256 totalSupplyAt = stakingRewardDistributor.totalSupplyAt(weekCursor);
        uint256 userBalanceOfAt = stakingRewardDistributor.balanceOfAt(users.alice, weekCursor);

        assertEq(userBalanceOfAt, 0, "User balance should be zero at current week cursor");
        assertEq(totalSupplyAt, 0, "Total supply should be zero at current week cursor");

        // Check balances and supply at next week cursor
        totalSupplyAt = stakingRewardDistributor.totalSupplyAt(nextWeekCursor);
        userBalanceOfAt = stakingRewardDistributor.balanceOfAt(users.alice, nextWeekCursor);

        assertGt(userBalanceOfAt, 0, "User balance should be greater than zero at next week cursor");
        assertEq(totalSupplyAt, 0, "Total supply should still be zero at next week cursor before checkpoint");

        // Checkpoint total supply
        stakingRewardDistributor.checkpointTotalSupply();

        // Warp to next week
        vm.warp(nextWeekCursor);

        // Checkpoint total supply again after warping
        stakingRewardDistributor.checkpointTotalSupply();

        // Check balances and supply after warping and checkpointing
        totalSupplyAt = stakingRewardDistributor.totalSupplyAt(nextWeekCursor);
        userBalanceOfAt = stakingRewardDistributor.balanceOfAt(users.alice, nextWeekCursor);

        assertGt(userBalanceOfAt, 0, "User balance should be greater than zero");
        assertEq(userBalanceOfAt, totalSupplyAt, "User balance should equal total supply");

        // Check if total supply matches the stake weight
        uint256 totalSupplyInStakeWeight = stakeWeight.totalSupplyAtTime(nextWeekCursor);
        assertEq(totalSupplyAt, totalSupplyInStakeWeight, "Total supply should match stake weight total supply");
    }

    function testTotalBalanceOfAtEqualsToTotalSupplyAt() public {
        // Setup test users
        address[] memory testUsers = new address[](3);
        testUsers[0] = users.alice;
        testUsers[1] = users.bob;
        testUsers[2] = users.carol;

        // Setup unlock times (30 days from now)
        uint256[] memory unlockTimes = new uint256[](3);
        unlockTimes[0] = block.timestamp + 30 days;
        unlockTimes[1] = block.timestamp + 30 days;
        unlockTimes[2] = block.timestamp + 30 days;

        // Setup amounts
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 80_000e18;
        amounts[1] = 90_000e18;
        amounts[2] = 100_000e18;

        // Setup users and locks
        _setupUsersAndLocks(testUsers, unlockTimes, amounts);

        // Get the current timestamp and calculate week cursor
        uint256 latestTimestamp = block.timestamp;
        uint256 weekCursor = _timestampToFloorWeek(latestTimestamp);
        uint256 nextWeekCursor = weekCursor + 1 weeks;

        // Warp to next week
        vm.warp(nextWeekCursor + 1);

        // Inject reward
        uint256 injectAmount = 88_888e18;
        deal(address(l2wct), users.admin, injectAmount);
        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), injectAmount);
        stakingRewardDistributor.injectRewardForCurrentWeek(injectAmount);

        // Checkpoint token and total supply
        stakingRewardDistributor.checkpointToken();
        stakingRewardDistributor.checkpointTotalSupply();
        vm.stopPrank();

        // Get total supply at the week cursor
        uint256 totalSupplyAt = stakingRewardDistributor.totalSupplyAt(nextWeekCursor);

        // Get balance of each user at the week cursor
        uint256 user1BalanceOfAt = stakingRewardDistributor.balanceOfAt(testUsers[0], nextWeekCursor);
        uint256 user2BalanceOfAt = stakingRewardDistributor.balanceOfAt(testUsers[1], nextWeekCursor);
        uint256 user3BalanceOfAt = stakingRewardDistributor.balanceOfAt(testUsers[2], nextWeekCursor);

        // Calculate total balance of all users
        uint256 userTotalBalanceOfAt = user1BalanceOfAt + user2BalanceOfAt + user3BalanceOfAt;

        // Assert that total balance of all users equals total supply
        assertEq(userTotalBalanceOfAt, totalSupplyAt, "Total balance of all users should equal total supply");
    }

    function testClaimWithNoLock() public {
        // Get the current timestamp and calculate week cursor
        uint256 latestTimestamp = block.timestamp;
        uint256 weekCursor = _timestampToFloorWeek(latestTimestamp);
        uint256 nextWeekCursor = weekCursor + 1 weeks;

        // Warp to next week
        vm.warp(nextWeekCursor + 1);

        // Inject reward
        uint256 injectAmount = 88_888e18;
        deal(address(l2wct), users.admin, injectAmount);
        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), injectAmount);
        stakingRewardDistributor.injectRewardForCurrentWeek(injectAmount);

        // Checkpoint token
        stakingRewardDistributor.checkpointToken();
        vm.stopPrank();

        // Warp another week
        vm.warp(nextWeekCursor + 1 weeks + 1);

        // Check last token balance
        uint256 lastTokenBalance = stakingRewardDistributor.lastTokenBalance();
        assertEq(lastTokenBalance, injectAmount, "Last token balance should equal injected amount");

        // Setup a user with no lock
        address payable userWithNoLock = payable(address(0x9999));

        // Check balance before claim
        uint256 balanceBefore = l2wct.balanceOf(userWithNoLock);

        // Attempt to claim
        vm.prank(userWithNoLock);
        stakingRewardDistributor.claim(userWithNoLock);

        // Check balance after claim
        uint256 balanceAfter = l2wct.balanceOf(userWithNoLock);

        // Assert that balance didn't change
        assertEq(balanceBefore, balanceAfter, "Balance should not change for user with no lock");
    }

    function testAllUsersClaimRewardEqualInjectAmount() public {
        // Setup users with locks
        address[] memory testUsers = new address[](3);
        testUsers[0] = users.alice;
        testUsers[1] = users.bob;
        testUsers[2] = users.carol;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 80_000e18;
        amounts[1] = 90_000e18;
        amounts[2] = 100_000e18;

        _setupUsersAndLocksWithSetUnlockTimes(block.timestamp + 30 days, testUsers, amounts);

        // Warp to next week and inject reward
        uint256 targetTime = block.timestamp + 1 weeks;
        vm.warp(targetTime);

        uint256 injectAmount = 88_888e18;
        deal(address(l2wct), address(users.admin), injectAmount);
        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), injectAmount);
        stakingRewardDistributor.injectReward(targetTime, injectAmount);
        vm.stopPrank();

        // Warp another week and checkpoint
        vm.warp(targetTime + 1 weeks);
        vm.startPrank(users.admin);
        stakingRewardDistributor.checkpointToken();
        stakingRewardDistributor.checkpointTotalSupply();
        vm.stopPrank();

        uint256 weekCursor = _timestampToFloorWeek(stakingRewardDistributor.lastTokenTimestamp());
        uint256 totalSupplyAt = stakingRewardDistributor.totalSupplyAt(weekCursor);
        uint256 totalRewardBalance = l2wct.balanceOf(address(stakingRewardDistributor));

        uint256 totalBalance;
        for (uint256 i = 0; i < testUsers.length; i++) {
            uint256 userBalance = stakingRewardDistributor.balanceOfAt(testUsers[i], weekCursor);
            uint256 expectedClaim = (userBalance * totalRewardBalance) / totalSupplyAt;

            vm.prank(testUsers[i]);
            stakingRewardDistributor.claim(testUsers[i]);

            uint256 actualClaim = l2wct.balanceOf(testUsers[i]);
            totalBalance += actualClaim;

            assertEq(expectedClaim, actualClaim, "Claim amount should match balance increase");
        }

        // Check if total claimed amount is close to injected amount (allowing for small rounding errors)
        assertTrue(
            (totalBalance * 10_000) / injectAmount > 9990,
            "Total claimed amount should be very close to injected amount"
        );
    }

    function testUserClaimZeroWhenLockAfterCheckpointToken() public {
        // Setup initial state
        uint256 latestTimestamp = block.timestamp;
        uint256 targetTime = latestTimestamp + 1 weeks;
        vm.warp(targetTime);

        // Inject reward
        uint256 injectAmount = 88_888e18;
        deal(address(l2wct), address(users.admin), injectAmount);
        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), injectAmount);
        stakingRewardDistributor.injectReward(targetTime, injectAmount);
        vm.stopPrank();

        // Warp to next week and checkpoint
        vm.warp(targetTime + 1 weeks);
        vm.startPrank(users.admin);
        stakingRewardDistributor.checkpointToken();
        vm.stopPrank();

        // Warp to just before the next week
        uint256 nextWeekTimestamp = ((block.timestamp / 1 weeks) + 1) * 1 weeks;
        vm.warp(nextWeekTimestamp - 1);

        // Setup user lock after checkpoint
        address user = address(0x1234);
        uint256 lockAmount = 80_000e18;
        uint256 lockDuration = 30 days;
        _setupUserLock(user, block.timestamp + lockDuration, lockAmount);

        // User claims
        vm.prank(user);
        stakingRewardDistributor.claim(user);

        // Check user balance
        uint256 userBalance = l2wct.balanceOf(user);
        assertEq(userBalance, 0, "User should have zero balance after claim");
    }

    function testUserClaimZeroWhenLockInSameWeek() public {
        // Setup initial state
        uint256 latestTimestamp = block.timestamp;
        uint256 targetTime = ((latestTimestamp / 1 weeks) + 1) * 1 weeks + 1;
        vm.warp(targetTime);

        // Calculate next week's timestamp
        uint256 nextWeekTimestamp = ((block.timestamp / 1 weeks) + 1) * 1 weeks;

        // Warp to 1 day before next week
        vm.warp(nextWeekTimestamp - 1 days);

        // Setup user lock
        address user = address(0x1234);
        uint256 lockAmount = 80_000e18;
        uint256 lockDuration = 30 days;
        _setupUserLock(user, block.timestamp + lockDuration, lockAmount);

        // Inject reward
        uint256 injectAmount = 88_888e18;
        deal(address(l2wct), address(users.admin), injectAmount);
        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), injectAmount);
        stakingRewardDistributor.injectReward(block.timestamp, injectAmount);
        stakingRewardDistributor.checkpointToken();
        vm.stopPrank();

        // User claims
        vm.prank(user);
        stakingRewardDistributor.claim(user);

        // Check user balance
        uint256 userBalance = l2wct.balanceOf(user);
        assertEq(userBalance, 0, "User should have zero balance after claim");
    }

    function testUserCanClaimRewardAfterNextWeekWhenLockAtThisWeek() public {
        // Setup initial state
        uint256 latestTimestamp = block.timestamp;
        uint256 targetTime = ((latestTimestamp / 1 weeks) + 1) * 1 weeks + 1;
        vm.warp(targetTime);

        // Calculate next week's timestamp
        uint256 nextWeekTimestamp = ((block.timestamp / 1 weeks) + 1) * 1 weeks;

        // Warp to 1 day before next week
        vm.warp(nextWeekTimestamp - 1 days);

        // Setup user lock
        address user = address(0x1234);
        uint256 lockAmount = 80_000e18;
        uint256 lockDuration = 30 days;
        _setupUserLock(user, block.timestamp + lockDuration, lockAmount);

        // Inject reward
        uint256 injectAmount = 88_888e18;
        deal(address(l2wct), address(users.admin), injectAmount);
        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), injectAmount);
        stakingRewardDistributor.injectReward(block.timestamp, injectAmount);
        stakingRewardDistributor.checkpointToken();
        vm.stopPrank();

        // User claims
        vm.prank(user);
        stakingRewardDistributor.claim(user);

        // Check user balance
        uint256 userBalance = l2wct.balanceOf(user);
        assertEq(userBalance, 0, "User should have zero balance after first claim");

        // Warp to next week + 1 hour
        vm.warp(nextWeekTimestamp + 1 hours);

        // Inject more rewards
        deal(address(l2wct), address(users.admin), injectAmount);
        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), injectAmount);
        stakingRewardDistributor.injectReward(block.timestamp, injectAmount);
        stakingRewardDistributor.checkpointToken();
        vm.stopPrank();

        // Warp to next week + 1 week + 1 hour
        vm.warp(nextWeekTimestamp + 1 weeks + 1 hours);

        // Inject more rewards
        deal(address(l2wct), address(users.admin), injectAmount);
        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), injectAmount);
        stakingRewardDistributor.injectReward(block.timestamp, injectAmount);
        stakingRewardDistributor.checkpointToken();
        vm.stopPrank();

        // User claims again
        vm.prank(user);
        stakingRewardDistributor.claim(user);

        // Check user balance
        userBalance = l2wct.balanceOf(user);
        assertTrue(userBalance > 0, "User should have non-zero balance after second claim");
    }

    function testUserCannotClaimRewardAgainAfterClaiming() public {
        address user = users.alice;
        uint256 lockAmount = 80_000e18;
        uint256 lockDuration = 30 days;
        uint256 injectAmount = 88_888e18;

        // Setup initial lock for user
        uint256 latestTimestamp = block.timestamp;
        uint256 nextWeekTimestamp = (latestTimestamp / 1 weeks + 1) * 1 weeks;
        vm.warp(nextWeekTimestamp - 1 days);

        _setupUserLock(user, block.timestamp + lockDuration, lockAmount);

        // Inject reward
        deal(address(l2wct), address(users.admin), injectAmount);
        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), injectAmount);
        stakingRewardDistributor.injectReward(block.timestamp, injectAmount);
        stakingRewardDistributor.checkpointToken();
        vm.stopPrank();

        // User claims
        vm.prank(user);
        stakingRewardDistributor.claim(user);

        // Check user balance
        uint256 userBalance = l2wct.balanceOf(user);
        assertEq(userBalance, 0, "User should have zero balance after first claim");

        // Warp to next week + 1 hour
        vm.warp(nextWeekTimestamp + 1 hours);

        // Inject more rewards
        deal(address(l2wct), address(users.admin), injectAmount);
        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), injectAmount);
        stakingRewardDistributor.injectReward(block.timestamp, injectAmount);
        stakingRewardDistributor.checkpointToken();
        vm.stopPrank();

        // Warp to next week + 1 week + 1 hour
        vm.warp(nextWeekTimestamp + 1 weeks + 1 hours);

        // Inject more rewards
        deal(address(l2wct), address(users.admin), injectAmount);
        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), injectAmount);
        stakingRewardDistributor.injectReward(block.timestamp, injectAmount);
        stakingRewardDistributor.checkpointToken();
        vm.stopPrank();

        // User claims again
        vm.prank(user);
        stakingRewardDistributor.claim(user);

        // Check user balance
        userBalance = l2wct.balanceOf(user);
        assertTrue(userBalance > 0, "User should have non-zero balance after second claim");

        // User attempts to claim again
        vm.prank(user);
        stakingRewardDistributor.claim(user);

        // Check user balance hasn't changed
        uint256 userBalanceAfterSecondClaim = l2wct.balanceOf(user);
        assertEq(userBalanceAfterSecondClaim, userBalance, "User balance should not change after claiming again");
    }

    function testUserCannotClaimRewardAgainAfterClaimTo() public {
        address user = address(0x1234);
        uint256 lockAmount = 80_000 ether;
        uint256 injectAmount = 88_888 ether;

        // Setup initial lock for the user
        uint256 latestTimestamp = block.timestamp;
        uint256 nextWeekTimestamp = (latestTimestamp / 1 weeks + 1) * 1 weeks;
        uint256 lockDuration = 30 days;
        _setupUserLock(user, nextWeekTimestamp + lockDuration, lockAmount);

        // Warp to just before next week
        vm.warp(nextWeekTimestamp - 1 days);

        // Inject initial reward
        deal(address(l2wct), address(users.admin), injectAmount);
        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), injectAmount);
        stakingRewardDistributor.injectReward(block.timestamp, injectAmount);
        stakingRewardDistributor.checkpointToken();
        vm.stopPrank();

        // User claims
        vm.prank(user);
        stakingRewardDistributor.claimTo(user);

        // Check user balance
        uint256 userBalance = l2wct.balanceOf(user);
        assertEq(userBalance, 0, "User should have zero balance after first claim");

        // Warp to next week + 1 hour
        vm.warp(nextWeekTimestamp + 1 hours);

        // Inject more rewards
        deal(address(l2wct), address(users.admin), injectAmount);
        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), injectAmount);
        stakingRewardDistributor.injectReward(block.timestamp, injectAmount);
        stakingRewardDistributor.checkpointToken();
        vm.stopPrank();

        // Warp to next week + 1 week + 1 hour
        vm.warp(nextWeekTimestamp + 1 weeks + 1 hours);

        // Inject more rewards
        deal(address(l2wct), address(users.admin), injectAmount);
        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), injectAmount);
        stakingRewardDistributor.injectReward(block.timestamp, injectAmount);
        stakingRewardDistributor.checkpointToken();
        vm.stopPrank();

        // User claims again using claimTo
        vm.prank(user);
        stakingRewardDistributor.claimTo(user);

        // Check user balance
        userBalance = l2wct.balanceOf(user);
        assertTrue(userBalance > 0, "User should have non-zero balance after second claim");

        // User attempts to claim again using claimTo
        vm.prank(user);
        stakingRewardDistributor.claimTo(user);

        // Check user balance hasn't changed
        uint256 userBalanceAfterSecondClaim = l2wct.balanceOf(user);
        assertEq(userBalanceAfterSecondClaim, userBalance, "User balance should not change after claiming again");
    }

    function testFeedWeeksAfterWeekCursor() public {
        vm.warp(stakingRewardDistributor.startWeekCursor() + 4 weeks);
        uint256 injectAmount = 88_888e18;
        deal(address(l2wct), address(users.admin), injectAmount);
        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), injectAmount);
        stakingRewardDistributor.feed(injectAmount);
        vm.stopPrank();
        // Check that the contract balance has increased by the injected amount
        assertEq(
            l2wct.balanceOf(address(stakingRewardDistributor)),
            injectAmount,
            "Contract balance should increase by injected amount"
        );
        // Check that the tokensPerWeek array has distributed the amount over the weeks
        uint256 totalTokensPerWeek = 0;
        for (uint256 i = 0; i < 4; i++) {
            totalTokensPerWeek +=
                stakingRewardDistributor.tokensPerWeek(stakingRewardDistributor.startWeekCursor() + 1 weeks * i);
        }
        assertApproxEqAbs(
            totalTokensPerWeek, injectAmount, 1e6, "Total tokens per week should be equal to injected amount"
        );
    }

    function testFeedWeeksAndTimeAfterWeekCursor() public {
        vm.warp(stakingRewardDistributor.startWeekCursor() + 4 weeks + 1 days + 18 hours); // 1/4 of the week in
        uint256 injectAmount = 88_888e18;
        deal(address(l2wct), address(users.admin), injectAmount);
        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), injectAmount);
        stakingRewardDistributor.feed(injectAmount);
        vm.stopPrank();
        // Check that the contract balance has increased by the injected amount
        assertEq(
            l2wct.balanceOf(address(stakingRewardDistributor)),
            injectAmount,
            "Contract balance should increase by injected amount"
        );
        // Check that the tokensPerWeek array has distributed the amount over the weeks
        uint256 totalTokensPerWeek = 0;
        for (uint256 i = 0; i < 5; i++) {
            totalTokensPerWeek +=
                stakingRewardDistributor.tokensPerWeek(stakingRewardDistributor.startWeekCursor() + 1 weeks * i);
        }
        assertApproxEqAbs(
            totalTokensPerWeek, injectAmount, 1e6, "Total tokens per week should be equal to injected amount"
        );
    }

    function testClaimAssumptions() public {
        // We deploy stakeWeight and stakingRewardDistributor at the same time (tuesday),
        // with the startWeekCursor of SRD being 1 week after the deploy time

        // Warp to tuesday (timestamp 0 is a thursday, so 5 days later is tuesday)
        vm.warp(5 days);

        // Deploy stakeWeight
        stakeWeight =
            newStakeWeight(users.admin, StakeWeight.Init({ admin: users.admin, config: address(walletConnectConfig) }));

        // Deploy stakingRewardDistributor
        stakingRewardDistributor = newStakingRewardDistributor({
            initialOwner: users.admin,
            init: StakingRewardDistributor.Init({
                admin: users.admin,
                startTime: block.timestamp + 1 weeks,
                emergencyReturn: users.emergencyHolder,
                config: address(walletConnectConfig)
            })
        });

        // inject reward for week 1
        uint256 injectAmount = 1000 ether;
        deal(address(l2wct), address(users.admin), injectAmount);
        vm.startPrank(users.admin);
        walletConnectConfig.updateStakeWeight(address(stakeWeight));
        l2wct.approve(address(stakingRewardDistributor), injectAmount);
        stakingRewardDistributor.injectReward(block.timestamp + 1 weeks, injectAmount);
        vm.stopPrank();

        // For a user who stakes on tuesday for 2 weeks, they should be able to claim on thursday of the next week
        _setupUserLock(users.alice, block.timestamp + 2 weeks, 100 ether);
        uint256 claimAmount;

        // Skip to wednesday of the next week, still not eligible to claim
        skip(8 days);
        vm.prank(users.alice);
        try stakingRewardDistributor.claim(users.alice) returns (uint256 amount) {
            claimAmount = amount;
        } catch {
            claimAmount = 0;
        }
        assertEq(claimAmount, 0, "User should not be able to claim before the next week cursor");

        // Skip to thursday of the next week, now eligible to claim
        skip(1 days);
        vm.prank(users.alice);
        claimAmount = stakingRewardDistributor.claim(users.alice);
        assertGt(claimAmount, 0, "User should be able to claim on the next week cursor");
    }

    function testRewardDistributionRules() public {
        // Start on Thursday 00:00 UTC (timestamp 7 days)
        uint256 startTime = 7 days;
        vm.warp(startTime);

        // Deploy contracts
        stakeWeight =
            newStakeWeight(users.admin, StakeWeight.Init({ admin: users.admin, config: address(walletConnectConfig) }));

        stakingRewardDistributor = newStakingRewardDistributor({
            initialOwner: users.admin,
            init: StakingRewardDistributor.Init({
                admin: users.admin,
                startTime: startTime,
                emergencyReturn: users.emergencyHolder,
                config: address(walletConnectConfig)
            })
        });

        vm.startPrank(users.admin);
        walletConnectConfig.updateStakeWeight(address(stakeWeight));
        vm.stopPrank();

        // Setup reward amount for each week
        uint256 weeklyReward = 1000 ether;

        // Test Position 1: Lock ends at start of week 2 - Should get rewards for week 1 only
        _setupUserLock(users.alice, startTime + 1 weeks, 100 ether);

        // Test Position 4: Lock ends at start of week 7 - Should get rewards for weeks 1-6
        address payable userDave = payable(address(420));
        _setupUserLock(userDave, startTime + 6 weeks, 100 ether);

        // Test Position 2: Lock ends at start of week 4 - Should get rewards for week 2-3
        // Starts Tuesday week 1, ends start of week 4 - Eligible for week 2 and 3
        vm.warp(startTime + 5 days); // Tuesday of week 1
        _setupUserLock(users.bob, startTime + 3 weeks, 100 ether);

        // Test Position 3: Should get rewards for weeks 2-5
        // Starts at week 2, ends start of week 7 - Eligible for weeks 2-6
        vm.warp(startTime + 1 weeks);
        _setupUserLock(users.carol, startTime + 6 weeks, 100 ether);

        // Inject rewards for weeks 1-7
        for (uint256 i = 0; i < 7; i++) {
            uint256 weekTimestamp = startTime + (i * 1 weeks);
            deal(address(l2wct), users.admin, weeklyReward);
            vm.startPrank(users.admin);
            l2wct.approve(address(stakingRewardDistributor), weeklyReward);
            stakingRewardDistributor.injectReward(weekTimestamp, weeklyReward);
            vm.stopPrank();
        }

        // Start testing claims from week 2 cursor (when week 1 rewards become claimable)
        vm.warp(startTime + 1 weeks);
        _assertClaim(users.alice, "Alice should be able to claim week 1 rewards");
        _assertNoClaim(users.bob, "Bob should not be able to claim yet");
        _assertNoClaim(users.carol, "Carol should not be able to claim yet");
        _assertClaim(userDave, "Dave should be able to claim week 1 rewards");

        // Week 3 cursor (week 2 rewards become claimable)
        vm.warp(startTime + 2 weeks);
        _assertNoClaim(users.alice, "Alice should not be able to claim anymore");
        _assertClaim(users.bob, "Bob should be able to claim week 2 rewards");
        _assertClaim(users.carol, "Carol should be able to claim week 2 rewards");
        _assertClaim(userDave, "Dave should be able to claim week 2 rewards");

        // Week 4 cursor
        vm.warp(startTime + 3 weeks);
        _assertNoClaim(users.alice, "Alice should not be able to claim");
        _assertClaim(users.bob, "Bob should be able to claim week 3 rewards");
        _assertClaim(users.carol, "Carol should be able to claim week 3 rewards");
        _assertClaim(userDave, "Dave should be able to claim week 3 rewards");

        // Week 5 cursor
        vm.warp(startTime + 4 weeks);
        _assertNoClaim(users.alice, "Alice should not be able to claim");
        _assertNoClaim(users.bob, "Bob should not be able to claim anymore");
        _assertClaim(users.carol, "Carol should be able to claim week 4 rewards");
        _assertClaim(userDave, "Dave should be able to claim week 4 rewards");

        // Week 6 cursor
        vm.warp(startTime + 5 weeks);
        _assertNoClaim(users.alice, "Alice should not be able to claim");
        _assertNoClaim(users.bob, "Bob should not be able to claim");
        _assertClaim(users.carol, "Carol should be able to claim week 5 rewards");
        _assertClaim(userDave, "Dave should be able to claim week 5 rewards");

        // Week 7 cursor
        vm.warp(startTime + 6 weeks);
        _assertNoClaim(users.alice, "Alice should not be able to claim");
        _assertNoClaim(users.bob, "Bob should not be able to claim");
        _assertClaim(users.carol, "Carol should be able to claim week 6 rewards");
        _assertClaim(userDave, "Dave should be able to claim week 6 rewards");

        // Week 8 cursor
        vm.warp(startTime + 7 weeks);
        _assertNoClaim(users.alice, "Alice should not be able to claim");
        _assertNoClaim(users.bob, "Bob should not be able to claim");
        _assertNoClaim(users.carol, "Carol should not be able to claim");
        _assertNoClaim(userDave, "Dave should not be able to claim anymore");
    }

    function testMinimumClaim() public {
        // We start on week 30
        uint256 startTime = _timestampToFloorWeek(block.timestamp + 30 weeks);
        // On Wednesday of week 29th at 23:59:59 UTC, user locks for 2 weeks (1 second left of this week + 1 week)
        // So user is fully locked for week 30 (beginning to end)
        vm.warp(startTime - 1);
        _setupUserLock(users.alice, startTime + 2 weeks, 100 ether);

        // inject reward for week 30
        uint256 injectAmount = 1000 ether;
        deal(address(l2wct), address(users.admin), injectAmount);
        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), injectAmount);
        stakingRewardDistributor.injectReward(startTime, injectAmount);
        vm.stopPrank();

        vm.warp(startTime + 1 weeks);
        _assertClaim(users.alice, "Alice should be able to claim week 30 rewards");
    }

    function testExactMinimumClaim() public {
        // We start on week 30
        uint256 startTime = _timestampToFloorWeek(block.timestamp + 30 weeks);
        // On start of week 30, user locks for 1 weeks
        // So user is fully locked for week 30 (beginning to end)
        vm.warp(startTime);
        _setupUserLock(users.alice, startTime + 1 weeks, 100 ether);

        // inject reward for week 30
        uint256 injectAmount = 1000 ether;
        deal(address(l2wct), address(users.admin), injectAmount);
        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), injectAmount);
        stakingRewardDistributor.injectReward(startTime, injectAmount);
        vm.stopPrank();

        vm.warp(startTime + 1 weeks);
        _assertClaim(users.alice, "Alice should be able to claim week 30 rewards");
    }

    function _assertNoClaim(address user, string memory message) internal {
        uint256 claimAmount;
        vm.prank(user);
        try stakingRewardDistributor.claim(user) returns (uint256 amount) {
            claimAmount = amount;
        } catch {
            claimAmount = 0;
        }
        assertEq(claimAmount, 0, message);
    }

    function _assertClaim(address user, string memory message) internal {
        uint256 claimAmount;
        vm.prank(user);
        claimAmount = stakingRewardDistributor.claim(user);
        assertGt(claimAmount, 0, message);
    }

    function _setupUsersAndLocksWithSetUnlockTimes(
        uint256 unlockTime,
        address[] memory testUsers,
        uint256[] memory amounts
    )
        internal
    {
        for (uint256 i = 0; i < testUsers.length; i++) {
            _setupUserLock(testUsers[i], unlockTime, amounts[i]);
        }
    }

    function _setupUsersAndLocks(
        address[] memory testUsers,
        uint256[] memory unlockTimes,
        uint256[] memory amounts
    )
        internal
    {
        for (uint256 i = 0; i < testUsers.length; i++) {
            _setupUserLock(testUsers[i], unlockTimes[i], amounts[i]);
        }
    }

    function _setupUserLock(address user, uint256 unlockTime, uint256 amount) internal {
        if (amount > 0) {
            deal(address(l2wct), user, amount);
            vm.startPrank(user);
            l2wct.approve(address(stakeWeight), amount);
            stakeWeight.createLock(amount, unlockTime);
            vm.stopPrank();
        }
    }
}
