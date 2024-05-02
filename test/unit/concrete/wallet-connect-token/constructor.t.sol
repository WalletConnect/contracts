// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { WalletConnectToken } from "src/WalletConnectToken.sol";

import { Base_Test } from "../../../Base.t.sol";

contract Constructor_WalletConnectToken_Unit_Concrete_Test is Base_Test {
    function test_Constructor() external {
        // Construct the contract.
        WalletConnectToken token = new WalletConnectToken({ initialOwner: users.mintManagerOwner });

        // Assert that the owner has been set
        address actualOwner = token.owner();
        address expectedOwner = users.mintManagerOwner;
        assertEq(actualOwner, expectedOwner, "owner");
    }
}
