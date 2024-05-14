// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { CNCT } from "src/CNCT.sol";

import { Base_Test } from "../../../Base.t.sol";

contract Constructor_CNCT_Unit_Concrete_Test is Base_Test {
    function test_Constructor() external {
        // Construct the contract.
        CNCT token = new CNCT({ initialOwner: users.admin });

        // Assert that the owner has been set
        address actualOwner = token.owner();
        address expectedOwner = users.admin;
        assertEq(actualOwner, expectedOwner, "owner");
    }
}
