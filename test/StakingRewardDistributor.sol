// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Base_Test } from "./Base.t.sol";
import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

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
        assertFalse(stakingRewardDistributor.canCheckpointToken());
    }

    function testCheckpointToken() public {
        // Setup users and locks
        address payable[] memory testUsers = new address payable[](5);
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

        vm.prank(users.admin);
        stakingRewardDistributor.setCanCheckpointToken(true);

        vm.warp(block.timestamp + 1);
        vm.prank(users.admin);
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
    }

    function testCheckpointTokenAsOwner() public {
        // Setup users and locks
        address payable[] memory testUsers = new address payable[](3);
        testUsers[0] = users.alice;
        testUsers[1] = users.bob;
        testUsers[2] = users.carol;

        uint256[] memory unlockTimes = new uint256[](3);
        unlockTimes[0] = block.timestamp + 30 days;
        unlockTimes[1] = block.timestamp + 30 days;
        unlockTimes[2] = block.timestamp + 30 days;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 80_000e18;
        amounts[1] = 90_000e18;
        amounts[2] = 100_000e18;

        _setupUsersAndLocks(testUsers, unlockTimes, amounts);

        // Test checkpointToken as owner
        uint256 latestTimestamp = block.timestamp;
        uint256 rewardAmount = 888e18;

        deal(address(l2wct), address(stakingRewardDistributor), rewardAmount);

        vm.prank(users.admin);
        stakingRewardDistributor.setCanCheckpointToken(true);

        vm.warp(block.timestamp + 1);
        vm.prank(users.admin);
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
    }

    function testOneUserBalanceEqualsSupply() public {
        // Setup one user with a lock
        address payable[] memory testUsers = new address payable[](1);
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
        stakingRewardDistributor.checkpointToken();

        // Warp to next week
        vm.warp(nextWeekCursor);

        // Checkpoint total supply again after warping
        stakingRewardDistributor.checkpointToken();

        // Check balances and supply after warping and checkpointing
        totalSupplyAt = stakingRewardDistributor.totalSupplyAt(nextWeekCursor);
        userBalanceOfAt = stakingRewardDistributor.balanceOfAt(users.alice, nextWeekCursor);

        assertGt(userBalanceOfAt, 0, "User balance should be greater than zero");
        assertEq(userBalanceOfAt, totalSupplyAt, "User balance should equal total supply");

        // Check if total supply matches the stake weight
        uint256 totalSupplyInStakeWeight = stakeWeight.totalSupplyAt(nextWeekCursor);
        assertEq(totalSupplyAt, totalSupplyInStakeWeight, "Total supply should match stake weight total supply");
    }

    function testTotalBalanceOfAtEqualsToTotalSupplyAt() public {
        // Setup test users
        address payable[] memory testUsers = new address payable[](3);
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

    function _setupUsersAndLocks(
        address payable[] memory testUsers,
        uint256[] memory unlockTimes,
        uint256[] memory amounts
    )
        internal
    {
        for (uint256 i = 0; i < testUsers.length; i++) {
            address user = testUsers[i];
            uint256 amount = amounts[i];
            uint256 unlockTime = unlockTimes[i];

            if (amount > 0) {
                deal(address(l2wct), user, amount);
                vm.startPrank(user);
                l2wct.approve(address(stakeWeight), amount);
                stakeWeight.createLock(amount, unlockTime);
                vm.stopPrank();
            }
        }
    }

    function _calculateBalances(
        address[] memory testUsers,
        uint256[] memory balances
    )
        internal
        view
        returns (uint256 sumOfBalances)
    {
        for (uint256 i = 0; i < testUsers.length; i++) {
            balances[i] = stakeWeight.balanceOf(testUsers[i]);
            sumOfBalances += balances[i];
        }
    }
}
