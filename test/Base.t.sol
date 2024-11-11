// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { WCT } from "src/WCT.sol";
import { L2WCT } from "src/L2WCT.sol";
import { Pauser } from "src/Pauser.sol";
import { PermissionedNodeRegistry } from "src/PermissionedNodeRegistry.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";
import { RewardManager } from "src/RewardManager.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { Staking } from "src/Staking.sol";
import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { LockedTokenStaker } from "src/LockedTokenStaker.sol";
import { MerkleVester, IPostClaimHandler } from "src/interfaces/MerkleVester.sol";
import { MockBridge } from "./mocks/MockBridge.sol";
import {
    newPauser,
    newStaking,
    newRewardManager,
    newWalletConnectConfig,
    newWCT,
    newL2WCT,
    newStakeWeight,
    newStakingRewardDistributor
} from "script/helpers/Proxy.sol";
import { Eip1967Logger } from "script/utils/Eip1967Logger.sol";

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
    WCT internal wct;
    L2WCT internal l2wct;
    Pauser internal pauser;
    PermissionedNodeRegistry internal permissionedNodeRegistry;
    WalletConnectConfig internal walletConnectConfig;
    RewardManager internal nodeRewardManager;
    Staking internal staking;
    StakeWeight internal stakeWeight;
    StakingRewardDistributor internal stakingRewardDistributor;
    LockedTokenStaker internal lockedTokenStaker;
    MerkleVester internal vester;
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
            emergencyHolder: createUser("EmergencyHolder"),
            treasury: createUser("Treasury"),
            attacker: createUser("Attacker"),
            permissionedNode: createUser("PermissionedNode"),
            nonPermissionedNode: createUser("NonPermissionedNode"),
            bob: createUser("Bob"),
            alice: createUser("Alice"),
            carol: createUser("Carol")
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
        walletConnectConfig = newWalletConnectConfig({
            initialOwner: users.admin,
            init: WalletConnectConfig.Init({ admin: users.admin })
        });

        pauser =
            newPauser({ initialOwner: users.admin, init: Pauser.Init({ admin: users.admin, pauser: users.pauser }) });

        nodeRewardManager = newRewardManager({
            initialOwner: users.admin,
            init: RewardManager.Init({
                owner: users.admin,
                maxRewardsPerEpoch: defaults.EPOCH_REWARD_EMISSION(),
                walletConnectConfig: walletConnectConfig
            })
        });

        stakeWeight =
            newStakeWeight(users.admin, StakeWeight.Init({ admin: users.admin, config: address(walletConnectConfig) }));

        staking = newStaking({
            initialOwner: users.admin,
            init: Staking.Init({ admin: users.admin, config: walletConnectConfig, duration: stakeWeight.maxLock() })
        });

        wct = newWCT({ initialOwner: users.admin, init: WCT.Init({ initialOwner: users.admin }) });

        // Dependency for L2WCT
        deployMockBridge();

        l2wct = newL2WCT({
            initialOwner: users.admin,
            init: L2WCT.Init({
                initialAdmin: users.admin,
                initialManager: users.manager,
                bridge: address(mockBridge),
                remoteToken: address(wct)
            })
        });

        stakingRewardDistributor = newStakingRewardDistributor({
            initialOwner: users.admin,
            init: StakingRewardDistributor.Init({
                admin: users.admin,
                startTime: block.timestamp,
                emergencyReturn: users.emergencyHolder,
                config: address(walletConnectConfig)
            })
        });

        // Deploy the non-proxy contracts
        permissionedNodeRegistry =
            new PermissionedNodeRegistry({ initialAdmin: users.admin, maxNodes_: defaults.MAX_REGISTRY_NODES() });

        IPostClaimHandler[] memory postClaimHandlers = new IPostClaimHandler[](0);

        vester = new MerkleVester(
            address(l2wct),
            users.admin,
            0, // No claim fee
            address(0), // No fee collector
            address(0), // No fee setter
            postClaimHandlers, // No post claim handlers
            0, // Max claim fee
            true // Direct claim allowed
        );

        lockedTokenStaker =
            new LockedTokenStaker({ vesterContract_: MerkleVester(address(vester)), config_: walletConnectConfig });

        // Update the WalletConnectConfig with the necessary contracts.
        walletConnectConfig.updateL2wct(address(l2wct));
        walletConnectConfig.updatePermissionedNodeRegistry(address(permissionedNodeRegistry));
        walletConnectConfig.updateNodeRewardManager(address(nodeRewardManager));
        walletConnectConfig.updatePauser(address(pauser));
        walletConnectConfig.updateStakeWeight(address(stakeWeight));

        vm.stopPrank();

        // Label the contracts.
        vm.label({ account: address(walletConnectConfig), newLabel: "WalletConnectConfig" });
        vm.label({ account: address(wct), newLabel: "WCT" });
        vm.label({ account: address(l2wct), newLabel: "L2WCT" });
        vm.label({ account: address(pauser), newLabel: "Pauser" });
        vm.label({ account: address(permissionedNodeRegistry), newLabel: "PermissionedNodeRegistry" });
        vm.label({ account: address(nodeRewardManager), newLabel: "NodeRewardManager" });
        vm.label({ account: address(stakeWeight), newLabel: "StakeWeight" });
        vm.label({ account: address(mockBridge), newLabel: "MockBridge" });
        vm.label({ account: address(stakingRewardDistributor), newLabel: "StakingRewardDistributor" });
        vm.label({ account: address(vester), newLabel: "MerkleVester" });
        vm.label({ account: address(lockedTokenStaker), newLabel: "LockedTokenStaker" });
    }

    function deployMockBridge() internal {
        deployCodeTo("MockBridge.sol:MockBridge", "", BRIDGE_ADDRESS);
        mockBridge = MockBridge(BRIDGE_ADDRESS);
    }

    function disableTransferRestrictions() internal {
        vm.prank(users.admin);
        l2wct.disableTransferRestrictions();
    }

    modifier notFromProxyAdmin(address msgSender, address proxy) {
        address admin = Eip1967Logger.getAdmin(vm, proxy);
        vm.assume(admin != msgSender);
        _;
    }
}
