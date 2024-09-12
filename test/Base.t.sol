// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { CNKT } from "src/CNKT.sol";
import { L2CNKT } from "src/L2CNKT.sol";
import { Pauser } from "src/Pauser.sol";
import { PermissionedNodeRegistry } from "src/PermissionedNodeRegistry.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";
import { RewardManager } from "src/RewardManager.sol";
import { Staking } from "src/Staking.sol";
import { MockBridge } from "./mocks/MockBridge.sol";

import { Test } from "forge-std/Test.sol";

import { Users } from "./utils/Types.sol";
import { Events } from "./utils/Events.sol";
import { Defaults } from "./utils/Defaults.sol";
import { Constants } from "./utils/Constants.sol";
import { Utils } from "./utils/Utils.sol";

/// @notice Base test contract with common logic needed by all tests.
abstract contract Base_Test is Test, Events, Constants, Utils {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users internal users;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    Defaults internal defaults;
    CNKT internal cnkt;
    L2CNKT internal l2cnkt;
    Pauser internal pauser;
    PermissionedNodeRegistry internal permissionedNodeRegistry;
    WalletConnectConfig internal walletConnectConfig;
    RewardManager internal rewardManager;
    Staking internal staking;

    /*//////////////////////////////////////////////////////////////////////////
                                   MOCKS
    //////////////////////////////////////////////////////////////////////////*/

    MockBridge internal mockBridge;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // Create users for testing.
        users = Users({
            admin: createUser("Admin"),
            manager: createUser("Manager"),
            pauser: createUser("Pauser"),
            timelockCanceller: createUser("TimelockCanceller"),
            attacker: createUser("Attacker"),
            treasury: createUser("Treasury"),
            permissionedNode: createUser("PermissionedNode"),
            nonPermissionedNode: createUser("NonPermissionedNode"),
            bob: createUser("Bob"),
            alice: createUser("Alice")
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
        // Deploy the proxy contracts
        walletConnectConfig = WalletConnectConfig(
            UnsafeUpgrades.deployTransparentProxy(
                address(new WalletConnectConfig()),
                users.admin,
                abi.encodeCall(WalletConnectConfig.initialize, WalletConnectConfig.Init({ admin: users.admin }))
            )
        );

        pauser = Pauser(
            UnsafeUpgrades.deployTransparentProxy(
                address(new Pauser()),
                users.admin,
                abi.encodeCall(Pauser.initialize, Pauser.Init({ admin: users.admin }))
            )
        );

        rewardManager = RewardManager(
            UnsafeUpgrades.deployTransparentProxy(
                address(new RewardManager()),
                users.admin,
                abi.encodeCall(
                    RewardManager.initialize,
                    RewardManager.Init({
                        owner: users.admin,
                        maxRewardsPerEpoch: defaults.EPOCH_REWARD_EMISSION(),
                        bakersSyndicateConfig: walletConnectConfig
                    })
                )
            )
        );
        staking = Staking(
            UnsafeUpgrades.deployTransparentProxy(
                address(new Staking()),
                users.admin,
                abi.encodeCall(
                    Staking.initialize,
                    Staking.Init({
                        admin: users.admin,
                        config: walletConnectConfig,
                        duration: defaults.STAKING_REWARD_DURATION()
                    })
                )
            )
        );

        cnkt = CNKT(
            UnsafeUpgrades.deployTransparentProxy(
                address(new CNKT()),
                users.admin,
                abi.encodeCall(CNKT.initialize, CNKT.Init({ initialOwner: users.admin }))
            )
        );

        // Deploy the non-proxy contracts
        deployMockBridge();

        permissionedNodeRegistry =
            new PermissionedNodeRegistry({ initialAdmin: users.admin, maxNodes_: defaults.MAX_REGISTRY_NODES() });

        l2cnkt = new L2CNKT(users.admin, users.manager, address(mockBridge), address(cnkt));

        // Update the WalletConnectConfig with the necessary contracts.
        walletConnectConfig.updateCNKT(address(cnkt));
        walletConnectConfig.updateL2cnkt(address(l2cnkt));
        walletConnectConfig.updatePermissionedNodeRegistry(address(permissionedNodeRegistry));
        walletConnectConfig.updateRewardManager(address(rewardManager));
        walletConnectConfig.updatePauser(address(pauser));
        walletConnectConfig.updateStaking(address(staking));
        walletConnectConfig.updateWalletConnectRewardsVault(users.treasury);

        // Add roles
        vm.startPrank(users.admin);
        pauser.grantRole(pauser.PAUSER_ROLE(), users.admin);
        pauser.grantRole(pauser.UNPAUSER_ROLE(), users.admin);
        vm.stopPrank();

        // Label the contracts.
        vm.label({ account: address(walletConnectConfig), newLabel: "WalletConnectConfig" });
        vm.label({ account: address(cnkt), newLabel: "CNKT" });
        vm.label({ account: address(l2cnkt), newLabel: "L2CNKT" });
        vm.label({ account: address(pauser), newLabel: "Pauser" });
        vm.label({ account: address(permissionedNodeRegistry), newLabel: "PermissionedNodeRegistry" });
        vm.label({ account: address(rewardManager), newLabel: "RewardManager" });
        vm.label({ account: address(staking), newLabel: "Staking" });
        vm.label({ account: address(mockBridge), newLabel: "MockBridge" });
    }

    function fundRewardsVaultAndApprove() internal {
        // Fund the RewardManager with CNKT.
        cnkt.mint(address(users.treasury), defaults.REWARD_BUDGET());
        vm.startPrank({ msgSender: users.treasury });
        // Approve the Staking contract to spend CNKT.
        cnkt.approve(address(staking), defaults.REWARD_BUDGET());
        vm.stopPrank();
    }

    function deployMockBridge() internal {
        deployCodeTo("MockBridge.sol:MockBridge", "", BRIDGE_ADDRESS);
        mockBridge = MockBridge(BRIDGE_ADDRESS);
    }
}
