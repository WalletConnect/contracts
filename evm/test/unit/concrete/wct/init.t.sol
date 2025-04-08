// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { WCT } from "src/WCT.sol";

import { Base_Test } from "../../../Base.t.sol";

contract Init_WCT_Unit_Concrete_Test is Base_Test {
    function test_Init() external {
        // Deploy & init the contract.
        WCT token = WCT(
            UnsafeUpgrades.deployTransparentProxy(
                address(new WCT()), users.admin, abi.encodeCall(WCT.initialize, WCT.Init({ initialAdmin: users.admin }))
            )
        );

        // Assert that the admin role has been granted
        bytes32 DEFAULT_ADMIN_ROLE = 0x00;
        assertTrue(token.hasRole(DEFAULT_ADMIN_ROLE, users.admin), "admin role not granted");
    }

    function test_RevertWhen_ReInitialized() external {
        // Deploy & init the contract.
        WCT token = WCT(
            UnsafeUpgrades.deployTransparentProxy(
                address(new WCT()), users.admin, abi.encodeCall(WCT.initialize, WCT.Init({ initialAdmin: users.admin }))
            )
        );

        // Try to initialize again
        vm.startPrank(users.admin);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        token.initialize(WCT.Init({ initialAdmin: users.alice })); // Use different args just in case
        vm.stopPrank();
    }
}
