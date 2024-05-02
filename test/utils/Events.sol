// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Abstract contract containing all the events emitted.
abstract contract Events {
    /*//////////////////////////////////////////////////////////////////////////
                                      ERC-20
    //////////////////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 value);

    /*//////////////////////////////////////////////////////////////////////////
                                      GENERICS
    //////////////////////////////////////////////////////////////////////////*/

    event TransferAdmin(address indexed oldAdmin, address indexed newAdmin);
}
