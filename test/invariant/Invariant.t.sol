// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

import { StdInvariant } from "forge-std/StdInvariant.sol";

import { Base_Test } from "../Base.t.sol";

/// @notice Common logic needed by all invariant tests.
abstract contract Invariant_Test is StdInvariant, Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Base_Test.setUp();
        deployCoreConditionally();
    }
}
