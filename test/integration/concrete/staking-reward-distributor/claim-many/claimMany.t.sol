// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakingRewardDistributor, IStakeWeight } from "src/StakingRewardDistributor.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { console2 } from "forge-std/console2.sol";
import { StakeWeight_Integration_Shared_Test } from "../../../shared/StakeWeight.t.sol";

contract ClaimMany_StakingRewardDistributor_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    uint256 constant WEEKS_IN_YEAR = 52;
    uint256 weeklyAmount;

    function setUp() public override {
        super.setUp();
        weeklyAmount = defaults.STAKING_REWARD_BUDGET() / WEEKS_IN_YEAR;
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
            stakingRewardDistributor.injectReward({ _timestamp: weekTimestamp, _amount: weeklyAmount });
        }

        vm.stopPrank();

        uint256 contractBalance = l2wct.balanceOf(address(stakingRewardDistributor));
        assertGt(contractBalance, 0, "No rewards in the contract");
    }

    function test_RevertWhen_ContractKilled() external {
        vm.prank(users.admin);
        stakingRewardDistributor.kill();

        address[] memory claimUsers = new address[](1);
        claimUsers[0] = address(users.alice);

        vm.expectRevert(StakingRewardDistributor.ContractKilled.selector);
        stakingRewardDistributor.claimMany(claimUsers);
    }

    modifier whenContractLive() {
        _;
    }

    function test_RevertWhen_UsersArrayLengthGreaterThan20() external whenContractLive {
        address[] memory claimUsers = new address[](21);
        for (uint256 i = 0; i < 21; i++) {
            claimUsers[i] = address(uint160(i + 1));
        }

        vm.expectRevert(StakingRewardDistributor.TooManyUsers.selector);
        stakingRewardDistributor.claimMany(claimUsers);
    }

    function test_ProcessClaimsForAllUsers() external whenContractLive {
        address[] memory claimUsers = new address[](3);
        claimUsers[0] = users.alice;
        claimUsers[1] = users.bob;
        claimUsers[2] = users.carol;

        uint256 initialAmount = 1000 ether;
        uint256 initialLockTime = block.timestamp + 4 weeks;

        for (uint256 i = 0; i < claimUsers.length; i++) {
            _createLockForUser(claimUsers[i], initialAmount, initialLockTime);
        }

        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        uint256[] memory initialBalances = new uint256[](claimUsers.length);
        for (uint256 i = 0; i < claimUsers.length; i++) {
            initialBalances[i] = l2wct.balanceOf(claimUsers[i]);
        }

        bool result = stakingRewardDistributor.claimMany(claimUsers);
        assertTrue(result, "claimMany should return true");

        for (uint256 i = 0; i < claimUsers.length; i++) {
            uint256 newBalance = l2wct.balanceOf(claimUsers[i]);
            assertGt(newBalance, initialBalances[i], "User balance should increase after claim");
        }
    }

    function test_SkipTransfersForZeroClaimAmounts() external whenContractLive {
        address[] memory claimUsers = new address[](3);
        claimUsers[0] = users.alice;
        claimUsers[1] = users.bob;
        claimUsers[2] = users.carol;

        _createLockForUser(users.alice, 1000 ether, block.timestamp + 4 weeks);

        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        uint256 initialBalance = l2wct.balanceOf(address(stakingRewardDistributor));
        bool result = stakingRewardDistributor.claimMany(claimUsers);
        uint256 finalBalance = l2wct.balanceOf(address(stakingRewardDistributor));

        assertTrue(result, "claimMany should return true");
        assertLt(finalBalance, initialBalance, "Contract balance should decrease");
        assertGt(l2wct.balanceOf(users.alice), 0, "Alice should receive rewards");
        assertEq(l2wct.balanceOf(users.bob), 0, "Bob should not receive rewards");
        assertEq(l2wct.balanceOf(users.carol), 0, "Carol should not receive rewards");
    }

    function test_UpdateLastTokenBalance() external whenContractLive {
        address[] memory claimUsers = new address[](1);
        claimUsers[0] = users.alice;

        _createLockForUser(users.alice, 1000 ether, block.timestamp + 4 weeks);

        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        uint256 initialLastTokenBalance = stakingRewardDistributor.lastTokenBalance();
        stakingRewardDistributor.claimMany(claimUsers);
        uint256 finalLastTokenBalance = stakingRewardDistributor.lastTokenBalance();

        assertLt(finalLastTokenBalance, initialLastTokenBalance, "lastTokenBalance should decrease after claim");
    }
}
