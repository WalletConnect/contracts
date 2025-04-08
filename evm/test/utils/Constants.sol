// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25;

abstract contract Constants {
    uint256 internal constant MAX_UINT256 = type(uint256).max;
    uint256 internal constant WCT_MAX_SUPPLY = type(uint208).max;
    address internal constant BRIDGE_ADDRESS = address(0x4200000000000000000000000000000000000010);
    address internal constant SUPERCHAIN_BRIDGE_ADDRESS = address(0x4200000000000000000000000000000000000028);
}
