// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "forge-std/console2.sol";

contract Eip1967Logger {
    function logEip1967(string memory name) public view {
        console2.log("%s:", name, address(this));
        bytes32 IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        address implementation;
        assembly {
            implementation := sload(IMPLEMENTATION_SLOT)
        }
        console2.log("%s Implementation:", name, implementation);
        bytes32 ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        address admin;
        assembly {
            admin := sload(ADMIN_SLOT)
        }
        console2.log("%s Admin:", name, admin);
    }
}
