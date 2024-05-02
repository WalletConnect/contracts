// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { WalletConnectToken } from "src/WalletConnectToken.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test } from "forge-std/src/Test.sol";

import { Users } from "./utils/Types.sol";
import { Events } from "./utils/Events.sol";

/// @notice Base test contract with common logic needed by all tests.
abstract contract Base_Test is Test, Events {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users internal users;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    WalletConnectToken internal walletConnectToken;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // Create users for testing.
        users = Users({ mintManagerOwner: createUser("MintManagerOwner"), attacker: createUser("Attacker") });

        // Deploy the base test contracts.
        walletConnectToken = new WalletConnectToken(users.mintManagerOwner);

        // Label the base test contracts.
        vm.label({ account: address(walletConnectToken), newLabel: "WalletConnectToken" });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Generates a user, labels its address, and funds it with test assets.
    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({ account: user, newBalance: 100 ether });
        return user;
    }
}
