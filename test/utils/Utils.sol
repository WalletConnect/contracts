// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25;

import { CommonBase } from "forge-std/Base.sol";

abstract contract Utils is CommonBase {
    /// @dev Stops the active prank and sets a new one.
    function resetPrank(address msgSender) internal {
        vm.stopPrank();
        vm.startPrank(msgSender);
    }

    /// @dev Converts a timestamp to the floor of the week it belongs to.
    function _timestampToFloorWeek(uint256 _timestamp) internal pure returns (uint256) {
        return (_timestamp / 1 weeks) * 1 weeks;
    }
}
