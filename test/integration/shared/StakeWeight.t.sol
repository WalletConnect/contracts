// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { StakeWeight } from "src/StakeWeight.sol";
import { console2 } from "forge-std/console2.sol";
import { Integration_Test } from "../Integration.t.sol";

/// @notice Common logic needed by all StakeWeight integration tests, both concrete and fuzz tests.
abstract contract StakeWeight_Integration_Shared_Test is Integration_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        super.setUp();

        // Disable transfer restrictions.
        vm.prank(address(users.admin));
        l2wct.disableTransferRestrictions();
    }

    function _createLockForUser(address user, uint256 amount, uint256 _lockTime) internal {
        deal(address(l2wct), user, amount);
        vm.startPrank(user);
        l2wct.approve(address(stakeWeight), amount);
        stakeWeight.createLock(amount, _lockTime);
        vm.stopPrank();
    }

    function _pause() internal {
        vm.prank(users.pauser);
        pauser.setIsStakeWeightPaused(true);
    }

    function _mineBlocks(uint256 blocks) internal {
        vm.roll(block.number + blocks);
        vm.warp(block.timestamp + blocks * defaults.SECONDS_PER_BLOCK());
    }

    function _calculateBias(uint256 amount, uint256 lockTime, uint256 currentTime) internal view returns (uint256) {
        lockTime = _timestampToFloorWeek(lockTime);

        console2.log("Calculating bias:");
        console2.log("  amount:", amount);
        console2.log("  lockTime:", lockTime);
        console2.log("  currentTime:", currentTime);
        uint256 maxLock = stakeWeight.MAX_LOCK();
        uint256 slope = amount / maxLock;
        uint256 bias = slope * (lockTime - currentTime);

        return bias;
    }
}
