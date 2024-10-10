// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { Base_Test } from "test/Base.t.sol";

contract SetRecipient_StakingRewardDistributor_Unit_Concrete_Test is Base_Test {
    address public user;
    address public newRecipient;

    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
        user = users.alice;
        newRecipient = users.bob;
    }

    function test_WhenNewRecipientIsSameAsOldRecipient() public {
        vm.startPrank(user);

        address oldRecipient = stakingRewardDistributor.getRecipient(user);

        vm.expectEmit(true, true, true, true);
        emit UpdateRecipient(user, address(0), oldRecipient);

        stakingRewardDistributor.setRecipient(oldRecipient);

        assertEq(
            stakingRewardDistributor.getRecipient(user),
            oldRecipient,
            "It should update the recipient (even if it's the same)"
        );
    }

    function test_WhenNewRecipientIsDifferentFromOldRecipient() public {
        vm.startPrank(user);

        address oldRecipient = stakingRewardDistributor.getRecipient(user);

        vm.expectEmit(true, true, true, true);
        emit UpdateRecipient(user, address(0), newRecipient);

        stakingRewardDistributor.setRecipient(newRecipient);

        assertEq(stakingRewardDistributor.getRecipient(user), newRecipient, "It should update the recipient");
        assertNotEq(
            stakingRewardDistributor.getRecipient(user),
            oldRecipient,
            "New recipient should be different from old recipient"
        );
    }

    function test_WhenUserAlreadyHasCustomRecipientSet() public {
        vm.startPrank(user);

        stakingRewardDistributor.setRecipient(newRecipient);

        address oldRecipient = newRecipient;
        address finalRecipient = users.carol;

        vm.expectEmit(true, true, true, true);
        emit UpdateRecipient(user, oldRecipient, finalRecipient);

        stakingRewardDistributor.setRecipient(finalRecipient);

        assertEq(stakingRewardDistributor.getRecipient(user), finalRecipient, "It should update the recipient");
        assertNotEq(
            stakingRewardDistributor.getRecipient(user),
            oldRecipient,
            "New recipient should be different from old recipient"
        );
    }
}
