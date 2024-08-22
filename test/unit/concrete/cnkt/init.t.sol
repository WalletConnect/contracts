// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";

import { CNKT } from "src/CNKT.sol";

import { Base_Test } from "../../../Base.t.sol";

contract Init_CNKT_Unit_Concrete_Test is Base_Test {
    function test_Init() external {
        // Deploy & init the contract.
        CNKT token = CNKT(
            UnsafeUpgrades.deployTransparentProxy(
                address(new CNKT()),
                users.admin,
                abi.encodeCall(CNKT.initialize, CNKT.Init({ initialOwner: users.admin }))
            )
        );

        // Assert that the owner has been set
        address actualOwner = token.owner();
        address expectedOwner = users.admin;
        assertEq(actualOwner, expectedOwner, "owner");
    }
}
