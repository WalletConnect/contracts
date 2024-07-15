// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { BRR } from "src/BRR.sol";

import { Base_Test } from "../../../Base.t.sol";

contract Constructor_BRR_Unit_Concrete_Test is Base_Test {
    function test_Constructor() external {
        // Construct the contract.
        BRR token = new BRR({ initialOwner: users.admin });

        // Assert that the owner has been set
        address actualOwner = token.owner();
        address expectedOwner = users.admin;
        assertEq(actualOwner, expectedOwner, "owner");
    }
}
