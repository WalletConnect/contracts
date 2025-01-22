// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Base_Test } from "test/Base.t.sol";
import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";

contract GetRecipient_StakingRewardDistributor_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();

        vm.prank(users.admin);
        l2wct.disableTransferRestrictions();
    }

    function test_WhenUserHasNoCustomRecipientSet() public view {
        address recipient = stakingRewardDistributor.getRecipient(users.alice);
        assertEq(recipient, users.alice, "It should return the user's address");
    }

    function test_WhenUserHasCustomRecipientSet() public {
        // Set a custom recipient for the user
        vm.prank(users.alice);
        stakingRewardDistributor.setRecipient(users.bob);

        address recipient = stakingRewardDistributor.getRecipient(users.alice);
        assertEq(recipient, users.bob, "It should return the custom recipient address");
    }
}
