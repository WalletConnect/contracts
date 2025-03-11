// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakeWeight_Integration_Shared_Test } from "./StakeWeight.t.sol";
import { StakingRewardsCalculator } from "src/StakingRewardsCalculator.sol";
import { SimpleAccount } from "test/mocks/SimpleAccount.sol";

contract StakingRewardsCalculator_Integration_Shared_Test is StakeWeight_Integration_Shared_Test {
    StakingRewardsCalculator public calculator;

    uint256 private constant WEEKS_IN_YEAR = 52;
    int256 private constant MILLION = 1_000_000;

    function setUp() public virtual override {
        super.setUp();

        // Make users.admin a SimpleAccount
        deployCodeTo("SimpleAccount.sol:SimpleAccount", "", users.admin);

        // Deploy calculator
        calculator = new StakingRewardsCalculator();

        vm.label(address(calculator), "StakingRewardsCalculator");

        // Warp to next week to ensure clean week boundaries
        vm.warp(_timestampToFloorWeek(block.timestamp + 1 weeks));

        // Disable transfer restrictions
        vm.prank(users.admin);
        l2wct.disableTransferRestrictions();
    }
}
