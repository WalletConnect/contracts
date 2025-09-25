// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { WCT } from "src/WCT.sol";
import { L2WCT } from "src/L2WCT.sol";
import { LegacyL2WCT } from "src/legacy/LegacyL2WCT.sol";
import { Pauser } from "src/Pauser.sol";
import { PermissionedNodeRegistry } from "src/PermissionedNodeRegistry.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";
import { RewardManager } from "src/RewardManager.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { Staking } from "src/Staking.sol";
import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { LockedTokenStaker } from "src/LockedTokenStaker.sol";
import { MerkleVester, IPostClaimHandler } from "src/utils/magna/MerkleVester.sol";
import { MockBridge } from "./mocks/MockBridge.sol";
import {
    newPauser,
    newStaking,
    newRewardManager,
    newWalletConnectConfig,
    newWCT,
    newL2WCT,
    newStakeWeight,
    newStakingRewardDistributor,
    newLockedTokenStaker
} from "script/helpers/Proxy.sol";
import { Eip1967Logger } from "script/utils/Eip1967Logger.sol";
import { NttManager, IManagerBase, Implementation } from "src/utils/wormhole/NttManagerFlat.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
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
    NttManager internal nttManager;

    /*//////////////////////////////////////////////////////////////////////////
                                   MOCKS
    //////////////////////////////////////////////////////////////////////////*/

    // Represents the *legacy* Optimism bridge used before the upgrade
    MockBridge internal legacyMockOptimismBridge; // Renamed

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

        // Deploy legacy bridge dependency for initial L2WCT deployment
        deployLegacyMockOptimismBridge(); // Renamed

        wct = newWCT({ initialOwner: users.admin, init: WCT.Init({ initialAdmin: users.admin }) });

        // --- L2WCT Upgrade Simulation ---
        // 1. Deploy the *legacy* L2WCT implementation via proxy first.
        //    This preserves the contract address across upgrades (important for CREATE2 consistency).
        //    The initializer uses the legacy bridge and remote token parameters.
        address legacyL2WCTProxy = address(
            newL2WCT({
                initialOwner: users.admin,
                init: LegacyL2WCT.Init({
                    initialAdmin: users.admin,
                    initialManager: users.manager,
                    bridge: address(legacyMockOptimismBridge), // Use legacy bridge for init
                    remoteToken: address(wct) // Use legacy remote token for init
                 })
            })
        );

        // 2. Deploy the *new* L2WCT implementation logic contract.
        L2WCT newL2WCTImpl = new L2WCT();

        // 3. Get the ProxyAdmin associated with the proxy.
        ProxyAdmin proxyAdmin = ProxyAdmin(Eip1967Logger.getAdmin(vm, legacyL2WCTProxy));

        // 4. Upgrade the proxy to point to the new implementation.
        //    No specific initialization data is needed for the upgrade itself here,
        //    as the relevant state (like minter) is set via separate function calls later.
        //    The Superchain bridge address is implicitly set in the new implementation's logic.
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(legacyL2WCTProxy), address(newL2WCTImpl), "");

        // 5. Cast the proxy address to the new L2WCT interface for further interaction.
        l2wct = L2WCT(legacyL2WCTProxy);
        // --- End L2WCT Upgrade Simulation ---

        address nttManagerImplementation = address(
            new NttManager(
                address(l2wct), // token
                IManagerBase.Mode.BURNING, // mode
                uint16(block.chainid), // chainId
                1 days, // rateLimitDuration
                false // skipRateLimiting
            )
        );

        // Add NttManager deployment
        nttManager = NttManager(
            address(
                new TransparentUpgradeableProxy(
                    nttManagerImplementation, users.admin, abi.encodeWithSelector(Implementation.initialize.selector)
                )
            )
        );

        l2wct.setMinter(address(nttManager));
        l2wct.setBridge(SUPERCHAIN_BRIDGE_ADDRESS);

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

        lockedTokenStaker = newLockedTokenStaker({
            initialOwner: users.admin,
            init: LockedTokenStaker.Init({
                vesterContract: address(vester),
                config: address(walletConnectConfig)
            }),
            identifier: "test"
        });

        // Update the WalletConnectConfig with the necessary contracts.
        walletConnectConfig.updateL2wct(address(l2wct));
        walletConnectConfig.updatePermissionedNodeRegistry(address(permissionedNodeRegistry));
        walletConnectConfig.updateNodeRewardManager(address(nodeRewardManager));
        walletConnectConfig.updatePauser(address(pauser));
        walletConnectConfig.updateStakeWeight(address(stakeWeight));
        walletConnectConfig.updateStakingRewardDistributor(address(stakingRewardDistributor));

        vm.stopPrank();

        // Label the contracts.
        vm.label({ account: address(walletConnectConfig), newLabel: "WalletConnectConfig" });
        vm.label({ account: address(wct), newLabel: "WCT" });
        vm.label({ account: address(l2wct), newLabel: "L2WCT" });
        vm.label({ account: address(pauser), newLabel: "Pauser" });
        vm.label({ account: address(permissionedNodeRegistry), newLabel: "PermissionedNodeRegistry" });
        vm.label({ account: address(nodeRewardManager), newLabel: "NodeRewardManager" });
        vm.label({ account: address(stakeWeight), newLabel: "StakeWeight" });
        vm.label({ account: address(legacyMockOptimismBridge), newLabel: "LegacyMockOptimismBridge" }); // Renamed
        vm.label({ account: address(stakingRewardDistributor), newLabel: "StakingRewardDistributor" });
        vm.label({ account: address(vester), newLabel: "MerkleVester" });
        vm.label({ account: address(lockedTokenStaker), newLabel: "LockedTokenStaker" });
    }

    // Deploys the mock for the *legacy* Optimism bridge
    function deployLegacyMockOptimismBridge() internal {
        // Renamed
        // Deploy to the specific address used by the legacy L2WCT contract
        deployCodeTo("MockBridge.sol:MockBridge", "", BRIDGE_ADDRESS);
        legacyMockOptimismBridge = MockBridge(BRIDGE_ADDRESS); // Renamed
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
