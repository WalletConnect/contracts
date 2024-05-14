// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { CNCT } from "src/CNCT.sol";
import { Pauser } from "src/Pauser.sol";
import { PermissionedNodeRegistry } from "src/PermissionedNodeRegistry.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";

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

    CNCT internal cnct;
    Pauser internal pauser;
    PermissionedNodeRegistry internal permissionedNodeRegistry;
    WalletConnectConfig internal walletConnectConfig;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // Create users for testing.
        users = Users({ admin: createUser("Admin"), attacker: createUser("Attacker") });

        // Label the base test contracts.
        vm.label({ account: address(cnct), newLabel: "CNCT" });
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

    /// @dev Conditionally deploys WalletConnect Core
    function deployCoreConditionally() internal {
        walletConnectConfig = new WalletConnectConfig(users.admin);
        cnct = new CNCT(users.admin);
        pauser = new Pauser(Pauser.Init({ admin: users.admin, pauser: users.admin, unpauser: users.admin }));
        permissionedNodeRegistry = new PermissionedNodeRegistry(users.admin);

        vm.label({ account: address(walletConnectConfig), newLabel: "WalletConnectConfig" });
        vm.label({ account: address(cnct), newLabel: "CNCT" });
        vm.label({ account: address(pauser), newLabel: "Pauser" });
        vm.label({ account: address(permissionedNodeRegistry), newLabel: "PermissionedNodeRegistry" });
    }
}
