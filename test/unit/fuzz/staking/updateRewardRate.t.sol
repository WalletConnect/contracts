// SPDX-License-Identifier: MIT

import { Base_Test } from "test/Base.t.sol";
import { Staking } from "src/Staking.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity >=0.8.25 <0.9.0;

contract UpdateRewardRate_Staking_Unit_Fuzz_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function testFuzz_updateRewardRate(uint256 newRewardRate, address sender) public {
        vm.startPrank(sender);

        // Ensure the contract has enough balance for rewards
        uint256 initialBalance = 1_000_000 * 1e18; // 1 million tokens
        deal(address(l2cnkt), address(staking), initialBalance);

        if (sender != staking.owner()) {
            vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, sender));
            staking.updateRewardRate(newRewardRate);
        } else {
            uint256 oldRewardRate = staking.rewardRate();

            if (newRewardRate == oldRewardRate) {
                vm.expectRevert(Staking.NoChange.selector);
                staking.updateRewardRate(newRewardRate);
            } else if (newRewardRate == 0) {
                vm.expectRevert(Staking.InvalidRewardRate.selector);
                staking.updateRewardRate(newRewardRate);
            } else {
                uint256 duration = staking.duration();
                uint256 expectedRewardAmount = newRewardRate * duration;

                if (expectedRewardAmount > initialBalance) {
                    vm.expectRevert(Staking.InsufficientRewardBalance.selector);
                    staking.updateRewardRate(newRewardRate);
                } else {
                    vm.expectEmit(true, true, true, true);
                    emit RewardRateUpdated(oldRewardRate, newRewardRate);
                    staking.updateRewardRate(newRewardRate);

                    assertEq(staking.rewardRate(), newRewardRate, "Reward rate should be updated");
                }
            }
        }
    }
}
