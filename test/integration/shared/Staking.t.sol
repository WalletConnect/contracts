// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Integration_Test } from "../Integration.t.sol";

contract Staking_Integration_Shared_Test is Integration_Test {
    function stakeFrom(address staker, uint256 amount) internal {
        _stakeFrom(staker, amount);
    }

    function _stakeFrom(address staker, uint256 amount) private {
        vm.startPrank(address(mockBridge));
        l2wct.mint(staker, amount);
        vm.startPrank(staker);
        l2wct.approve(address(staking), amount);
        staking.stake(amount);
        vm.stopPrank();
    }
}
