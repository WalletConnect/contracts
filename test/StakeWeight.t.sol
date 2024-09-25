// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Base_Test } from "./Base.t.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract StakeWeight_Test is Base_Test {
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

    function testCreateLock() public {
        uint256 amount = 100e18;
        uint256 unlockTime = block.timestamp + YEAR;

        vm.prank(users.alice);
        stakeWeight.createLock(amount, unlockTime);

        (int128 lockedAmount, uint256 end) = stakeWeight.locks(users.alice);
        assertEq(uint256(int256(lockedAmount)), amount);
        assertEq(end, _timestampToFloorWeek(unlockTime));
    }

    function testIncreaseLockAmount() public {
        uint256 initialAmount = 100e18;
        uint256 additionalAmount = 50e18;
        uint256 unlockTime = block.timestamp + YEAR;

        vm.startPrank(users.alice);
        stakeWeight.createLock(initialAmount, unlockTime);
        stakeWeight.increaseLockAmount(additionalAmount);
        vm.stopPrank();

        (int128 lockedAmount,) = stakeWeight.locks(users.alice);
        assertEq(uint256(int256(lockedAmount)), initialAmount + additionalAmount);
    }

    function testIncreaseUnlockTime() public {
        uint256 amount = 100e18;
        uint256 initialUnlockTime = block.timestamp + YEAR;
        uint256 initialUnlockTimeRounded = _timestampToFloorWeek(initialUnlockTime);

        uint256 newUnlockTime = initialUnlockTimeRounded + YEAR;

        vm.startPrank(users.alice);
        stakeWeight.createLock(amount, initialUnlockTime);
        (, uint256 initialEnd) = stakeWeight.locks(users.alice);
        assertEq(initialEnd, initialUnlockTimeRounded, "Initial unlock time rounded incorrectly");
        stakeWeight.increaseUnlockTime(newUnlockTime);
        vm.stopPrank();

        (, uint256 finalEnd) = stakeWeight.locks(users.alice);
        assertEq(finalEnd, _timestampToFloorWeek(newUnlockTime), "Final unlock time rounded incorrectly");
    }

    function testWithdrawAfterLockExpired() public {
        uint256 amount = 1000e18;
        uint256 unlockTime = block.timestamp + YEAR;

        // Create lock for user Alice
        vm.startPrank(users.alice);
        l2wct.approve(address(stakeWeight), type(uint256).max);
        stakeWeight.createLock(amount, unlockTime);
        vm.stopPrank();

        // Fast forward to after lock expiration
        vm.warp(unlockTime + 1 weeks);

        uint256 aliceBalanceBefore = l2wct.balanceOf(users.alice);

        // Withdraw all tokens
        vm.prank(users.alice);
        stakeWeight.withdrawAll();

        uint256 aliceBalanceAfter = l2wct.balanceOf(users.alice);

        // Check balance increase
        assertEq(aliceBalanceAfter - aliceBalanceBefore, amount, "Incorrect amount withdrawn");

        // Check lock is cleared
        (int128 lockedAmount, uint256 end) = stakeWeight.locks(users.alice);
        assertEq(uint256(int256(lockedAmount)), 0, "Locked amount should be zero");
        assertEq(end, 0, "Lock end time should be zero");
    }

    function testBalanceOf() public {
        uint256 amount = 100e18;
        uint256 unlockTime = block.timestamp + YEAR;

        vm.prank(users.alice);
        stakeWeight.createLock(amount, unlockTime);

        uint256 balance = stakeWeight.balanceOf(users.alice);
        assertGt(balance, 0);
        assertLe(balance, amount);
    }

    function testTotalSupply() public {
        uint256 amount1 = 100e18;
        uint256 amount2 = 200e18;
        uint256 unlockTime = block.timestamp + YEAR;

        vm.prank(users.alice);
        stakeWeight.createLock(amount1, unlockTime);

        vm.prank(users.bob);
        stakeWeight.createLock(amount2, unlockTime);

        uint256 totalSupply = stakeWeight.totalSupply();
        assertGt(totalSupply, 0);
        assertLe(totalSupply, amount1 + amount2);
    }

    function testTotalSupplyWithMultipleUsers() public {
        address[5] memory testUsers;

        for (uint256 i; i < testUsers.length; i++) {
            testUsers[i] = address(uint160(i + 1));
        }

        uint256[5] memory unlockTimes;

        unlockTimes[0] = block.timestamp + 30 days;
        unlockTimes[1] = block.timestamp + 365 days;
        unlockTimes[2] = block.timestamp + 30 days;
        unlockTimes[3] = block.timestamp + 180 days;
        unlockTimes[4] = block.timestamp + 180 days;

        uint256[5] memory amounts;
        amounts[0] = 1000e18;
        amounts[1] = 1000e18;
        amounts[2] = 5000e18;
        amounts[3] = 100_000e18;
        amounts[4] = 2500e18;

        _setupUsersAndLocks(testUsers, unlockTimes, amounts);

        vm.warp(block.timestamp + 2);

        uint256[5] memory balances;

        uint256 sumOfBalances = _calculateBalances(testUsers, balances);

        uint256 totalSupply = stakeWeight.totalSupply();

        assertEq(totalSupply, sumOfBalances, "Total supply should equal sum of individual balances");
    }

    function testBalanceAtSpecificBlockNumber() public {
        address[] memory testUsers = new address[](3);
        testUsers[0] = users.alice;
        testUsers[1] = users.bob;
        testUsers[2] = users.carol;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 80_000e18;
        amounts[1] = 90_000e18;
        amounts[2] = 100_000e18;

        uint256 lockDuration = 30 days;

        for (uint256 i = 0; i < testUsers.length; i++) {
            vm.startPrank(testUsers[i]);
            deal(address(l2wct), testUsers[i], amounts[i]);
            l2wct.approve(address(stakeWeight), amounts[i]);
            stakeWeight.createLock(amounts[i], block.timestamp + lockDuration);
            vm.stopPrank();
        }

        uint256 initialBlock = block.number;
        uint256 initialTotalSupply = stakeWeight.totalSupply();
        uint256 initialSumOfBalances;

        for (uint256 i = 0; i < testUsers.length; i++) {
            initialSumOfBalances += stakeWeight.balanceOf(testUsers[i]);
        }

        assertEq(initialSumOfBalances, initialTotalSupply, "Initial total balance should equal initial total supply");

        vm.warp(block.timestamp + lockDuration - 1 hours);
        vm.roll(initialBlock + 1000);

        uint256 midwayTotalSupply = stakeWeight.totalSupply();
        uint256 midwaySumOfBalances;

        for (uint256 i = 0; i < testUsers.length; i++) {
            midwaySumOfBalances += stakeWeight.balanceOf(testUsers[i]);
        }

        assertEq(midwaySumOfBalances, midwayTotalSupply, "Midway total balance should equal midway total supply");

        vm.warp(block.timestamp + 2 hours);
        vm.roll(initialBlock + 2000);

        uint256 finalTotalSupply = stakeWeight.totalSupply();
        uint256 finalSumOfBalances;

        for (uint256 i = 0; i < testUsers.length; i++) {
            finalSumOfBalances += stakeWeight.balanceOf(testUsers[i]);
        }

        assertEq(finalSumOfBalances, finalTotalSupply, "Final total balance should equal final total supply");
    }

    function testZeroBalanceAfterExpiry() public {
        uint256 amount = 80_000e18;
        uint256 lockDuration = 4 weeks;
        uint256 unlockTime = _timestampToFloorWeek(block.timestamp + lockDuration);

        deal(address(l2wct), users.alice, amount);
        vm.startPrank(users.alice);
        l2wct.approve(address(stakeWeight), amount);
        stakeWeight.createLock(amount, unlockTime);
        vm.stopPrank();

        uint256 initialBlock = block.number;
        uint256 initialBalance = stakeWeight.balanceOf(users.alice);
        assertGt(initialBalance, 0, "Initial balance should be greater than zero");

        // Check balance at various points during the lock period
        for (uint256 i = 1; i <= 4; i++) {
            vm.warp(_timestampToFloorWeek(block.timestamp + 1 weeks));
            vm.roll(initialBlock + (i * 100));
            uint256 currentBalance = stakeWeight.balanceOf(users.alice);
            if (i < 4) {
                assertGt(currentBalance, 0, "Balance should be greater than zero before expiry");
            }
        }

        // Check balance after expiry
        vm.warp(_timestampToFloorWeek(unlockTime + 1));
        vm.roll(initialBlock + 500);
        uint256 finalBalance = stakeWeight.balanceOf(users.alice);
        assertEq(finalBalance, 0, "Final balance should be zero after lock expiry");
    }

    function _setupUsersAndLocks(
        address[5] memory testUsers,
        uint256[5] memory unlockTimes,
        uint256[5] memory amounts
    )
        internal
    {
        for (uint256 i = 0; i < testUsers.length; i++) {
            address user = testUsers[i];
            uint256 amount = amounts[i];
            uint256 unlockTime = unlockTimes[i];

            deal(address(l2wct), user, amount);
            vm.startPrank(user);
            l2wct.approve(address(stakeWeight), amount);
            stakeWeight.createLock(amount, unlockTime);
            vm.stopPrank();
        }
    }

    function _calculateBalances(
        address[5] memory testUsers,
        uint256[5] memory balances
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
