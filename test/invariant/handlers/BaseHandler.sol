// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { CNKT } from "src/CNKT.sol";
import { L2CNKT } from "src/L2CNKT.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import { StdUtils } from "forge-std/StdUtils.sol";
import { CommonBase } from "forge-std/Base.sol";
import { Constants } from "test/utils/Constants.sol";
import { Utils } from "test/utils/Utils.sol";

/// @notice Base contract with common logic needed by all handler contracts.
abstract contract BaseHandler is Constants, StdCheats, StdUtils, CommonBase, Utils {
    /*//////////////////////////////////////////////////////////////////////////
                                    STATE-VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Maps function names to the number of times they have been called.
    mapping(string func => uint256 calls) public calls;

    /// @dev The total number of calls made to this contract.
    uint256 public totalCalls;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    CNKT public cnkt;
    L2CNKT public l2cnkt;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(CNKT cnkt_, L2CNKT l2cnkt_) {
        cnkt = cnkt_;
        l2cnkt = l2cnkt_;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Simulates the passage of time. The time jump is upper bounded so that streams don't settle too quickly.
    /// @param timeJumpSeed A fuzzed value needed for generating random time warps.
    modifier adjustTimestamp(uint256 timeJumpSeed) {
        uint256 timeJump = bound(timeJumpSeed, 2 minutes, 40 days);
        vm.warp(block.timestamp + timeJump);
        _;
    }

    /// @dev Records a function call for instrumentation purposes.
    modifier instrument(string memory functionName) {
        calls[functionName]++;
        totalCalls++;
        _;
    }

    /// @dev Makes the provided sender the caller.
    modifier useNewSender(address sender) {
        resetPrank(sender);
        _;
    }
}
