// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { WalletConnectConfig } from "./../WalletConnectConfig.sol";

library UtilLib {
    error ZeroAddress();
    error CallerNotWalletConnectContract();

    /// @notice zero address check modifier
    function checkNonZeroAddress(address addr) internal pure {
        if (addr == address(0)) revert ZeroAddress();
    }

    //checks if caller is a WalletConnect contract address
    function onlyWalletConnectContract(
        address addr,
        WalletConnectConfig bakersSyndicateConfig,
        bytes32 contractName
    )
        internal
        view
    {
        if (!bakersSyndicateConfig.isWalletConnectContract(addr, contractName)) {
            revert CallerNotWalletConnectContract();
        }
    }
}
