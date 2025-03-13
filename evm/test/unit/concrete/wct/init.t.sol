// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";

import { WCT } from "src/WCT.sol";

import { Base_Test } from "../../../Base.t.sol";

contract Init_WCT_Unit_Concrete_Test is Base_Test {
    function test_Init() external {
        // Deploy & init the contract.
        WCT token = WCT(
            UnsafeUpgrades.deployTransparentProxy(
                address(new WCT()),
                users.admin,
                abi.encodeCall(
                    WCT.initialize, WCT.Init({ initialOwner: users.admin, initialMinter: address(nttManager) })
                )
            )
        );

        // Assert that the owner has been set
        address actualOwner = token.owner();
        address expectedOwner = users.admin;
        assertEq(actualOwner, expectedOwner, "owner");

        // Assert that the minter has been set
        address actualMinter = token.minter();
        address expectedMinter = address(nttManager);
        assertEq(actualMinter, expectedMinter, "minter");
    }
}
