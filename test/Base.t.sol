// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { BRR } from "src/BRR.sol";
import { Pauser } from "src/Pauser.sol";
import { PermissionedNodeRegistry } from "src/PermissionedNodeRegistry.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";
import { RewardManager } from "src/RewardManager.sol";
import { Staking } from "src/Staking.sol";

import { Test } from "forge-std/src/Test.sol";

import { Users } from "./utils/Types.sol";
import { Events } from "./utils/Events.sol";
import { Defaults } from "./utils/Defaults.sol";
import { Constants } from "./utils/Constants.sol";

/// @notice Base test contract with common logic needed by all tests.
abstract contract Base_Test is Test, Events, Constants {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users internal users;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    Defaults internal defaults;
    BRR internal brr;
    Pauser internal pauser;
    PermissionedNodeRegistry internal permissionedNodeRegistry;
    WalletConnectConfig internal walletConnectConfig;
    RewardManager internal rewardManager;
    Staking internal staking;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // Create users for testing.
        users = Users({
            admin: createUser("Admin"),
            attacker: createUser("Attacker"),
            treasury: createUser("Treasury"),
            permissionedNode: createUser("PermissionedNode"),
            nonPermissionedNode: createUser("NonPermissionedNode")
        });

        defaults = new Defaults();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Generates a user, labels its address, and funds it with test assets.
    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({ account: user, newBalance: 100 ether });
        vm.label({ account: user, newLabel: name });
        return user;
    }

    /// @dev Conditionally deploys WalletConnect Core
    function deployCoreConditionally() internal {
        // Admin deploys/sets up the contracts.
        vm.startPrank(users.admin);
        // Deploy the contracts.
        walletConnectConfig = new WalletConnectConfig(users.admin);
        brr = new BRR(users.admin);
        pauser = new Pauser(Pauser.Init({ admin: users.admin, pauser: users.admin, unpauser: users.admin }));
        permissionedNodeRegistry =
            new PermissionedNodeRegistry({ initialOwner: users.admin, maxNodes_: defaults.MAX_REGISTRY_NODES() });
        rewardManager = new RewardManager({
            initialOwner: users.admin,
            initialMaxRewardsPerEpoch: defaults.EPOCH_REWARD_EMISSION(),
            walletConnectConfig_: walletConnectConfig
        });
        staking = new Staking({
            initialOwner: users.admin,
            initialMinStakeAmount: defaults.MIN_STAKE(),
            walletConnectConfig_: walletConnectConfig
        });

        // Update the WalletConnectConfig with the necessary contracts.
        walletConnectConfig.updateBrr(address(brr));
        walletConnectConfig.updatePermissionedNodeRegistry(address(permissionedNodeRegistry));
        walletConnectConfig.updateRewardManager(address(rewardManager));
        walletConnectConfig.updatePauser(address(pauser));
        walletConnectConfig.updateStaking(address(staking));
        walletConnectConfig.updateWalletConnectRewardsVault(users.treasury);

        vm.stopPrank();

        // Label the contracts.
        vm.label({ account: address(walletConnectConfig), newLabel: "WalletConnectConfig" });
        vm.label({ account: address(brr), newLabel: "BRR" });
        vm.label({ account: address(pauser), newLabel: "Pauser" });
        vm.label({ account: address(permissionedNodeRegistry), newLabel: "PermissionedNodeRegistry" });
        vm.label({ account: address(rewardManager), newLabel: "RewardManager" });
        vm.label({ account: address(staking), newLabel: "Staking" });
    }

    function fundRewardsVaultAndApprove() internal {
        // Fund the RewardManager with BRR.
        brr.mint(address(users.treasury), defaults.REWARD_BUDGET());
        vm.startPrank({ msgSender: users.treasury });
        // Approve the Staking contract to spend BRR.
        brr.approve(address(staking), defaults.REWARD_BUDGET());
        vm.stopPrank();
    }
}
