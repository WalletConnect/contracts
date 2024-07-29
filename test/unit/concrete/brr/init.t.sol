// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";

import { BRR } from "src/BRR.sol";

import { Base_Test } from "../../../Base.t.sol";

contract Init_BRR_Unit_Concrete_Test is Base_Test {
    function test_Init() external {
        // Deploy & init the contract.
        BRR token = BRR(
            UnsafeUpgrades.deployTransparentProxy(
                address(new BRR()), users.admin, abi.encodeCall(BRR.initialize, BRR.Init({ initialOwner: users.admin }))
            )
        );

        // Assert that the owner has been set
        address actualOwner = token.owner();
        address expectedOwner = users.admin;
        assertEq(actualOwner, expectedOwner, "owner");
    }
}
