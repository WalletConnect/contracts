// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { BakersSyndicateConfig } from "./../BakersSyndicateConfig.sol";

library UtilLib {
    error ZeroAddress();
    error CallerNotBakersSyndicateContract();

    /// @notice zero address check modifier
    function checkNonZeroAddress(address addr) internal pure {
        if (addr == address(0)) revert ZeroAddress();
    }

    //checks if caller is a BakersSyndicate contract address
    function onlyBakersSyndicateContract(
        address addr,
        BakersSyndicateConfig bakersSyndicateConfig,
        bytes32 contractName
    )
        internal
        view
    {
        if (!bakersSyndicateConfig.isBakersSyndicateContract(addr, contractName)) {
            revert CallerNotBakersSyndicateContract();
        }
    }
}
