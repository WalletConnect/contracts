// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { CNCT } from "src/CNCT.sol";
import { Pauser } from "src/Pauser.sol";
import { PermissionedNodeRegistry } from "src/PermissionedNodeRegistry.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";
import { RewardManager } from "src/RewardManager.sol";

import { Test } from "forge-std/src/Test.sol";

import { Users } from "./utils/Types.sol";
import { Events } from "./utils/Events.sol";
import { Defaults } from "./utils/Defaults.sol";

/// @notice Base test contract with common logic needed by all tests.
abstract contract Base_Test is Test, Events {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users internal users;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    Defaults internal defaults;
    CNCT internal cnct;
    Pauser internal pauser;
    PermissionedNodeRegistry internal permissionedNodeRegistry;
    WalletConnectConfig internal walletConnectConfig;
    RewardManager internal rewardManager;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // Create users for testing.
        users =
            Users({ admin: createUser("Admin"), attacker: createUser("Attacker"), treasury: createUser("Treasury") });

        defaults = new Defaults();
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
        // Admin deploys/sets up the contracts.
        vm.startPrank(users.admin);
        // Deploy the contracts.
        walletConnectConfig = new WalletConnectConfig(users.admin);
        cnct = new CNCT(users.admin);
        pauser = new Pauser(Pauser.Init({ admin: users.admin, pauser: users.admin, unpauser: users.admin }));
        permissionedNodeRegistry = new PermissionedNodeRegistry(users.admin);
        rewardManager = new RewardManager({
            initialOwner: users.admin,
            initialRewardsPerEpoch: defaults.EPOCH_REWARD_EMISSION(),
            walletConnectConfig_: walletConnectConfig
        });

        // Update the WalletConnectConfig with the necessary contracts.
        walletConnectConfig.updateCnct(address(cnct));
        walletConnectConfig.updatePermissionedNodeRegistry(address(permissionedNodeRegistry));

        // Fund the RewardManager with CNCT.
        cnct.mint(address(users.treasury), defaults.REWARD_BUDGET());
        vm.startPrank({ msgSender: users.treasury });
        cnct.approve(address(rewardManager), defaults.REWARD_BUDGET());
        vm.stopPrank();

        // Label the contracts.
        vm.label({ account: address(walletConnectConfig), newLabel: "WalletConnectConfig" });
        vm.label({ account: address(cnct), newLabel: "CNCT" });
        vm.label({ account: address(pauser), newLabel: "Pauser" });
        vm.label({ account: address(permissionedNodeRegistry), newLabel: "PermissionedNodeRegistry" });
        vm.label({ account: address(rewardManager), newLabel: "RewardManager" });
    }
}
