// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { VmSafe } from "forge-std/Vm.sol";

library Eip1967Logger {
    function logEip1967(VmSafe vm, string memory name, address proxy) internal view {
        console2.log("%s:", name, proxy);
        console2.log("%s Implementation:", name, getImplementation(vm, proxy));
        console2.log("%s Admin:", name, getAdmin(vm, proxy));
    }

    function getImplementation(VmSafe vm, address proxy) internal view returns (address implementation) {
        bytes32 IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        implementation = slotToAddress(vm, proxy, IMPLEMENTATION_SLOT);
    }

    function getAdmin(VmSafe vm, address proxy) internal view returns (address admin) {
        bytes32 ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        admin = slotToAddress(vm, proxy, ADMIN_SLOT);
    }

    function slotToAddress(VmSafe vm, address proxy, bytes32 slot) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, slot))));
    }
}
