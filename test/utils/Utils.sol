// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.25;

import { CommonBase } from "forge-std/Base.sol";

abstract contract Utils is CommonBase {
    /// @dev Stops the active prank and sets a new one.
    function resetPrank(address msgSender) internal {
        vm.stopPrank();
        vm.startPrank(msgSender);
    }
}
