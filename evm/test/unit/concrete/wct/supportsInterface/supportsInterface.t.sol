// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { WCT } from "src/WCT.sol";
import { INttToken } from "src/interfaces/INttToken.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { Base_Test } from "test/Base.t.sol";

contract SupportsInterface_WCT_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function test_SupportsINttTokenInterface() external view {
        assertTrue(wct.supportsInterface(type(INttToken).interfaceId), "WCT should support INttToken interface");
    }

    // Add tests for other relevant interfaces if necessary
    // e.g., IERC20, IAccessControl, IERC165 etc.
    function test_SupportsIERC165Interface() external view {
        assertTrue(wct.supportsInterface(type(IERC165).interfaceId), "WCT should support IERC165");
    }

    function test_SupportsIAccessControlInterface() external view {
        assertTrue(wct.supportsInterface(type(IAccessControl).interfaceId), "WCT should support IAccessControl");
    }
}
