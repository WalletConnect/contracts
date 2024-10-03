// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Base_Test } from "./Base.t.sol";
import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";
import { StakeWeight } from "src/StakeWeight.sol";

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
        assertEq(address(stakingRewardDistributor.rewardToken()), address(l2wct));
        assertEq(address(stakingRewardDistributor.stakeWeight()), address(stakeWeight));
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
