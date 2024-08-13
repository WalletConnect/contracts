// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { BRR } from "src/BRR.sol";
import { L2BRR } from "src/L2BRR.sol";
import { Pauser } from "src/Pauser.sol";
import { PermissionedNodeRegistry } from "src/PermissionedNodeRegistry.sol";
import { BakersSyndicateConfig } from "src/BakersSyndicateConfig.sol";
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
    BRR internal brr;
    L2BRR internal l2brr;
    Pauser internal pauser;
    PermissionedNodeRegistry internal permissionedNodeRegistry;
    BakersSyndicateConfig internal bakersSyndicateConfig;
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
            attacker: createUser("Attacker"),
            treasury: createUser("Treasury"),
            permissionedNode: createUser("PermissionedNode"),
            nonPermissionedNode: createUser("NonPermissionedNode"),
            bob: createUser("Bob"),
            alice: createUser("Alice"),
            timelockCanceller: createUser("TimelockCanceller")
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

    /// @dev Conditionally deploys BakersSyndicate Core
    function deployCoreConditionally() internal {
        // Admin deploys/sets up the contracts.
        vm.startPrank(users.admin);
        // Deploy the proxy contracts
        bakersSyndicateConfig = BakersSyndicateConfig(
            UnsafeUpgrades.deployTransparentProxy(
                address(new BakersSyndicateConfig()),
                users.admin,
                abi.encodeCall(BakersSyndicateConfig.initialize, BakersSyndicateConfig.Init({ admin: users.admin }))
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
                        bakersSyndicateConfig: bakersSyndicateConfig
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
                        owner: users.admin,
                        minStakeAmount: defaults.MIN_STAKE(),
                        isStakingAllowlist: true,
                        bakersSyndicateConfig: bakersSyndicateConfig
                    })
                )
            )
        );

        brr = BRR(
            UnsafeUpgrades.deployTransparentProxy(
                address(new BRR()), users.admin, abi.encodeCall(BRR.initialize, BRR.Init({ initialOwner: users.admin }))
            )
        );

        // Deploy the non-proxy contracts

        permissionedNodeRegistry =
            new PermissionedNodeRegistry({ initialAdmin: users.admin, maxNodes_: defaults.MAX_REGISTRY_NODES() });

        deployMockBridge();

        l2brr = new L2BRR(users.admin, address(mockBridge), address(brr));

        // Update the BakersSyndicateConfig with the necessary contracts.
        bakersSyndicateConfig.updateBrr(address(brr));
        bakersSyndicateConfig.updateL2brr(address(l2brr));
        bakersSyndicateConfig.updatePermissionedNodeRegistry(address(permissionedNodeRegistry));
        bakersSyndicateConfig.updateRewardManager(address(rewardManager));
        bakersSyndicateConfig.updatePauser(address(pauser));
        bakersSyndicateConfig.updateStaking(address(staking));
        bakersSyndicateConfig.updateBakersSyndicateRewardsVault(users.treasury);

        // Add roles
        vm.startPrank(users.admin);
        pauser.grantRole(pauser.PAUSER_ROLE(), users.admin);
        pauser.grantRole(pauser.UNPAUSER_ROLE(), users.admin);
        vm.stopPrank();

        // Label the contracts.
        vm.label({ account: address(bakersSyndicateConfig), newLabel: "BakersSyndicateConfig" });
        vm.label({ account: address(brr), newLabel: "BRR" });
        vm.label({ account: address(l2brr), newLabel: "L2BRR" });
        vm.label({ account: address(pauser), newLabel: "Pauser" });
        vm.label({ account: address(permissionedNodeRegistry), newLabel: "PermissionedNodeRegistry" });
        vm.label({ account: address(rewardManager), newLabel: "RewardManager" });
        vm.label({ account: address(staking), newLabel: "Staking" });
        vm.label({ account: address(mockBridge), newLabel: "MockBridge" });
    }

    function fundRewardsVaultAndApprove() internal {
        // Fund the RewardManager with BRR.
        brr.mint(address(users.treasury), defaults.REWARD_BUDGET());
        vm.startPrank({ msgSender: users.treasury });
        // Approve the Staking contract to spend BRR.
        brr.approve(address(staking), defaults.REWARD_BUDGET());
        vm.stopPrank();
    }

    function deployMockBridge() internal {
        deployCodeTo("MockBridge.sol", abi.encode(address(bakersSyndicateConfig)), BRIDGE_ADDRESS);
        mockBridge = MockBridge(BRIDGE_ADDRESS);
    }
}
