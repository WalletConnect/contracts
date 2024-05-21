// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

import { WalletConnectConfig } from "./../WalletConnectConfig.sol";

library UtilLib {
    error ZeroAddress();
    error CallerNotWalletConnectContract();

    /// @notice zero address check modifier
    function checkNonZeroAddress(address addr) internal pure {
        if (addr == address(0)) revert ZeroAddress();
    }

    //checks if caller is a wallet connect contract address
    function onlyWalletConnectContract(
        address addr,
        WalletConnectConfig walletConnectConfig,
        bytes32 contractName
    )
        internal
        view
    {
        if (!walletConnectConfig.onlyWalletConnectContract(addr, contractName)) {
            revert CallerNotWalletConnectContract();
        }
    }
}
