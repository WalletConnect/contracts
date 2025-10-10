// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Base_Test } from "test/Base.t.sol";
import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { L2WCT } from "src/L2WCT.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";
import { Pauser } from "src/Pauser.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import {
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OptimismDeployments } from "script/Base.s.sol";
import { OptimismDeploy } from "script/deploy/OptimismDeploy.s.sol";
import { Eip1967Logger } from "script/utils/Eip1967Logger.sol";

contract StakingRewardDistributorUpgrade_ForkTest is Base_Test {
    // Live addresses from DEPLOYMENT_ADDRESSES.md
    address public constant OPTIMISM_ADMIN_TIMELOCK = 0x61cc6aF18C351351148815c5F4813A16DEe7A7E4;
    address public constant OPTIMISM_MANAGER_TIMELOCK = 0xB5EFe3783Db55B913C79CBdB81C9d2C0a993f5f0;
    address public constant OPTIMISM_MANAGER_MULTISIG = 0x03296182abE56196472d74947F4b87626b171173;
    address public constant TREASURY_MULTISIG = 0xa86Ca428512D0A18828898d2e656E9eb1b6bA6E7;
    address public constant STAKING_REWARD_DISTRIBUTOR_PROXY = 0xF368F535e329c6d08DFf0d4b2dA961C4e7F3fCAF;
    address public constant STAKING_REWARD_DISTRIBUTOR_PROXY_ADMIN = 0x28672bf553c6AB214985868f68A3a491E227aCcB;
    address public constant PAUSER_PROXY_ADMIN = 0x8714E77FA6Aca75A9b21d79295ec7cF04E4821a8;
    address public constant STAKE_WEIGHT_PROXY = 0x521B4C065Bbdbe3E20B3727340730936912DfA46;
    address public constant STAKE_WEIGHT_PROXY_ADMIN = 0x9898b105fe3679f2d31c3A06B58757D913D88e5F;

    TimelockController public adminTimelock;
    TimelockController public managerTimelock;
    ProxyAdmin public proxyAdmin;
    StakingRewardDistributor public stakingRewardDistributorProxy;
    StakingRewardDistributor public newImplementation;
    WalletConnectConfig public config;

    address public admin;

    // Timelock constants
    uint256 public constant MIN_DELAY = 7 days; // Optimism Admin Timelock has 7 day delay
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    uint256 public constant WEEK = 7 days;

    address[] internal targetUsers;
    uint256[5] internal WEEK_OFFSETS = [uint256(0), 4 * WEEK, 12 * WEEK, 26 * WEEK, 52 * WEEK];

    struct DistributorBaseline {
        uint256 totalDistributed;
        uint256 lastTokenBalance;
        uint256 weekCursor;
        uint256 startWeekCursor;
        bool recorded;
    }

    struct DistributorUserBaseline {
        uint256 weekCursor;
        uint256 userEpoch;
        address recipient;
        bool recorded;
    }

    struct DistributorWeekBaseline {
        uint256 balanceOfAt;
        uint256 tokensPerWeek;
        bool recorded;
    }

    DistributorBaseline internal distributorBaseline;
    uint256 internal baselineCurrentWeek;
    mapping(address => DistributorUserBaseline) internal userBaselines;
    mapping(bytes32 => DistributorWeekBaseline) internal weekBaselines;

    function setUp() public override {
        // Fork Optimism at a recent block
        vm.createSelectFork("optimism", 130_432_882);

        // Load deployments
        OptimismDeployments memory deps = new OptimismDeploy().readOptimismDeployments(block.chainid);

        adminTimelock = TimelockController(payable(OPTIMISM_ADMIN_TIMELOCK));
        managerTimelock = TimelockController(payable(OPTIMISM_MANAGER_TIMELOCK));
        proxyAdmin = ProxyAdmin(STAKING_REWARD_DISTRIBUTOR_PROXY_ADMIN);
        stakingRewardDistributorProxy = StakingRewardDistributor(STAKING_REWARD_DISTRIBUTOR_PROXY);
        config = WalletConnectConfig(address(deps.config));

        // Get admin address from env or use a default for testing
        admin = vm.envOr("ADMIN_ADDRESS", 0x398A2749487B2a91f2f543C01F7afD19AEE4b6b0);

        super.setUp();
        _ensureTargetUsersInitialized();
    }

    /// @dev Helper function to upgrade Pauser contract with StakingRewardDistributor pause support
    function _upgradePauser() internal {
        address pauserProxy = config.getPauser();
        ProxyAdmin pauserProxyAdmin = ProxyAdmin(PAUSER_PROXY_ADMIN);

        Pauser newPauserImpl = new Pauser();

        address[] memory pauserTargets = new address[](1);
        pauserTargets[0] = address(pauserProxyAdmin);

        uint256[] memory pauserValues = new uint256[](1);
        pauserValues[0] = 0;

        bytes[] memory pauserPayloads = new bytes[](1);
        pauserPayloads[0] = abi.encodeWithSelector(
            ProxyAdmin.upgradeAndCall.selector, ITransparentUpgradeableProxy(pauserProxy), address(newPauserImpl), ""
        );

        bytes32 pauserSalt = keccak256("PAUSER_UPGRADE_FOR_SRD");

        vm.prank(admin);
        adminTimelock.scheduleBatch(pauserTargets, pauserValues, pauserPayloads, bytes32(0), pauserSalt, MIN_DELAY);

        vm.warp(block.timestamp + MIN_DELAY + 1);

        vm.prank(admin);
        adminTimelock.executeBatch(pauserTargets, pauserValues, pauserPayloads, bytes32(0), pauserSalt);
    }

    function _ensureTargetUsersInitialized() internal {
        if (targetUsers.length != 0) {
            return;
        }
        targetUsers = new address[](10);
        targetUsers[0] = 0xD4ca0fB58552876dF6E9422dCFC5B07b0dB2c229;
        targetUsers[1] = 0x6EC113A5BE0F12C04d81899F80A88490F1A4796c;
        targetUsers[2] = 0xBF8395b92069B85FdD9Ea6FAb19A1C6F2b79dc22;
        targetUsers[3] = 0x2A8f753fB144f0AB4cc77F4a3Ace4543dF0AA7E9;
        targetUsers[4] = 0xb5f5DF3E2C2758794062A7daab910a66566552bf;
        targetUsers[5] = 0x6Af2a94A29237Ee5f4874733811a72A53db658c6;
        targetUsers[6] = 0x5C799a0804882c7973704e2567E22f9cEF382026;
        targetUsers[7] = 0xeC0fE68cD9A79a67dCc0Ca71e1da163e2a3900Ea;
        targetUsers[8] = 0x813C6f672907183FC4d0b44F7124A194447A784d;
        targetUsers[9] = 0x6d135a7eb13eA6C7EE7455ce078081251c78ACfd;
    }

    function _captureBaselinesIfNeeded() internal {
        if (distributorBaseline.recorded) {
            return;
        }

        distributorBaseline.recorded = true;
        distributorBaseline.totalDistributed = stakingRewardDistributorProxy.totalDistributed();
        distributorBaseline.lastTokenBalance = stakingRewardDistributorProxy.lastTokenBalance();
        distributorBaseline.weekCursor = stakingRewardDistributorProxy.weekCursor();
        distributorBaseline.startWeekCursor = stakingRewardDistributorProxy.startWeekCursor();

        baselineCurrentWeek = (block.timestamp / WEEK) * WEEK;

        for (uint256 i = 0; i < targetUsers.length; i++) {
            _captureUserBaseline(targetUsers[i]);
        }
    }

    function _captureUserBaseline(address user) internal {
        DistributorUserBaseline storage baseline = userBaselines[user];
        baseline.weekCursor = stakingRewardDistributorProxy.weekCursorOf(user);
        baseline.userEpoch = stakingRewardDistributorProxy.userEpochOf(user);
        baseline.recipient = stakingRewardDistributorProxy.getRecipient(user);
        baseline.recorded = true;

        uint256 startWeekCursor = distributorBaseline.startWeekCursor;
        for (uint256 i = 0; i < WEEK_OFFSETS.length; i++) {
            uint256 offset = WEEK_OFFSETS[i];
            if (baselineCurrentWeek < offset) {
                continue;
            }
            _recordWeekBaseline(user, baselineCurrentWeek - offset, startWeekCursor);
        }
    }

    function _recordWeekBaseline(address user, uint256 targetWeek, uint256 startWeekCursor) internal {
        if (targetWeek < startWeekCursor) {
            return;
        }

        bytes32 key = keccak256(abi.encode(user, targetWeek));
        DistributorWeekBaseline storage weekBaseline = weekBaselines[key];
        weekBaseline.balanceOfAt = stakingRewardDistributorProxy.balanceOfAt(user, targetWeek);
        weekBaseline.tokensPerWeek = stakingRewardDistributorProxy.tokensPerWeek(targetWeek);
        weekBaseline.recorded = true;
    }

    function _assertBaselines() internal view {
        if (!distributorBaseline.recorded) {
            return;
        }

        assertEq(
            stakingRewardDistributorProxy.totalDistributed(),
            distributorBaseline.totalDistributed,
            "totalDistributed drifted"
        );
        assertEq(
            stakingRewardDistributorProxy.lastTokenBalance(),
            distributorBaseline.lastTokenBalance,
            "lastTokenBalance drifted"
        );
        assertEq(stakingRewardDistributorProxy.weekCursor(), distributorBaseline.weekCursor, "weekCursor drifted");
        assertEq(
            stakingRewardDistributorProxy.startWeekCursor(),
            distributorBaseline.startWeekCursor,
            "startWeekCursor drifted"
        );

        uint256 startWeekCursor = distributorBaseline.startWeekCursor;
        for (uint256 i = 0; i < targetUsers.length; i++) {
            _assertUserBaseline(targetUsers[i], startWeekCursor);
        }
    }

    function _assertUserBaseline(address user, uint256 startWeekCursor) internal view {
        DistributorUserBaseline storage baseline = userBaselines[user];
        if (!baseline.recorded) {
            return;
        }

        assertEq(stakingRewardDistributorProxy.weekCursorOf(user), baseline.weekCursor, "weekCursorOf drifted for user");
        assertEq(stakingRewardDistributorProxy.userEpochOf(user), baseline.userEpoch, "userEpochOf drifted for user");
        assertEq(stakingRewardDistributorProxy.getRecipient(user), baseline.recipient, "recipient drifted for user");

        for (uint256 i = 0; i < WEEK_OFFSETS.length; i++) {
            uint256 offset = WEEK_OFFSETS[i];
            if (baselineCurrentWeek < offset) {
                continue;
            }
            _assertWeekBaseline(user, baselineCurrentWeek - offset, startWeekCursor);
        }
    }

    function _assertWeekBaseline(address user, uint256 targetWeek, uint256 startWeekCursor) internal view {
        if (targetWeek < startWeekCursor) {
            return;
        }

        bytes32 key = keccak256(abi.encode(user, targetWeek));
        DistributorWeekBaseline storage weekBaseline = weekBaselines[key];
        if (!weekBaseline.recorded) {
            return;
        }

        assertEq(
            stakingRewardDistributorProxy.balanceOfAt(user, targetWeek), weekBaseline.balanceOfAt, "balanceOfAt drifted"
        );
        assertEq(
            stakingRewardDistributorProxy.tokensPerWeek(targetWeek), weekBaseline.tokensPerWeek, "tokensPerWeek drifted"
        );
    }

    function testUpgradeToAccessControl() public {
        // Verify initial state - should be owned by treasury
        address currentOwner = Ownable(address(stakingRewardDistributorProxy)).owner();
        assertEq(currentOwner, TREASURY_MULTISIG, "Current owner should be treasury");

        _captureBaselinesIfNeeded();

        // Deploy new implementation with AccessControl
        newImplementation = new StakingRewardDistributor();

        // Prepare upgrade calldata with migration
        bytes memory upgradeData = abi.encodeWithSelector(StakingRewardDistributor.migrateToAccessControl.selector);

        // Prepare timelock batch for atomic upgrade + migration
        address[] memory targets = new address[](1);
        targets[0] = address(proxyAdmin);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory payloads = new bytes[](1);
        payloads[0] = abi.encodeWithSelector(
            ProxyAdmin.upgradeAndCall.selector,
            ITransparentUpgradeableProxy(address(stakingRewardDistributorProxy)),
            address(newImplementation),
            upgradeData
        );

        bytes32 predecessor = bytes32(0);
        bytes32 salt = keccak256("STAKING_REWARD_DISTRIBUTOR_ACCESS_CONTROL_UPGRADE");

        // Schedule the upgrade
        vm.prank(admin);
        adminTimelock.scheduleBatch(targets, values, payloads, predecessor, salt, MIN_DELAY);

        // Get operation hash for execution
        bytes32 operationId = adminTimelock.hashOperationBatch(targets, values, payloads, predecessor, salt);

        // Verify operation is scheduled
        assertTrue(adminTimelock.isOperationPending(operationId), "Operation should be pending");

        // Warp time to after delay
        vm.warp(block.timestamp + MIN_DELAY + 1);

        // Execute the upgrade
        vm.prank(admin);
        adminTimelock.executeBatch(targets, values, payloads, predecessor, salt);

        // Verify upgrade succeeded
        assertTrue(adminTimelock.isOperationDone(operationId), "Operation should be completed");

        // Verify new implementation is set using Eip1967Logger
        address currentImpl = Eip1967Logger.getImplementation(vm, address(stakingRewardDistributorProxy));
        assertEq(currentImpl, address(newImplementation), "Implementation should be updated");

        // Verify AccessControl roles are set correctly
        IAccessControl accessControlled = IAccessControl(address(stakingRewardDistributorProxy));

        // Check DEFAULT_ADMIN_ROLE is granted to timelock
        bytes32 DEFAULT_ADMIN_ROLE = 0x00;
        assertTrue(
            accessControlled.hasRole(DEFAULT_ADMIN_ROLE, OPTIMISM_ADMIN_TIMELOCK),
            "Timelock should have DEFAULT_ADMIN_ROLE"
        );

        // Check REWARD_MANAGER_ROLE is granted to treasury
        bytes32 REWARD_MANAGER_ROLE = keccak256("REWARD_MANAGER_ROLE");
        assertTrue(
            accessControlled.hasRole(REWARD_MANAGER_ROLE, TREASURY_MULTISIG), "Treasury should have REWARD_MANAGER_ROLE"
        );

        // Verify old owner functions no longer work
        vm.expectRevert(); // Should revert because owner() doesn't exist anymore
        Ownable(address(stakingRewardDistributorProxy)).owner();

        _assertBaselines();
    }

    function testRewardManagerCanInjectRewards() public {
        // First upgrade Pauser to add StakingRewardDistributor pause support
        _upgradePauser();

        // Then perform the StakingRewardDistributor upgrade
        testUpgradeToAccessControl();

        // Get L2WCT from config
        address l2wctAddress = config.getL2wct();

        // Deal some tokens to treasury
        deal(l2wctAddress, TREASURY_MULTISIG, 1000e18);

        // Get initial totalDistributed value
        uint256 totalDistributedBefore = stakingRewardDistributorProxy.totalDistributed();

        // Treasury should be able to inject rewards
        vm.startPrank(TREASURY_MULTISIG);
        L2WCT(l2wctAddress).approve(address(stakingRewardDistributorProxy), 100e18);

        // This should work because treasury has REWARD_MANAGER_ROLE
        stakingRewardDistributorProxy.injectRewardForCurrentWeek(100e18);
        vm.stopPrank();

        // Verify rewards were injected (check the delta)
        uint256 totalDistributedAfter = stakingRewardDistributorProxy.totalDistributed();
        assertEq(totalDistributedAfter - totalDistributedBefore, 100e18, "Rewards should be distributed");
    }

    function testOnlyAdminCanKill() public {
        // First perform the upgrade
        testUpgradeToAccessControl();

        // Treasury should NOT be able to kill (only has REWARD_MANAGER_ROLE)
        vm.prank(TREASURY_MULTISIG);
        vm.expectRevert(); // Missing DEFAULT_ADMIN_ROLE
        stakingRewardDistributorProxy.kill();

        // Random address should not be able to kill
        vm.prank(makeAddr("random"));
        vm.expectRevert();
        stakingRewardDistributorProxy.kill();

        // Timelock should be able to kill (has DEFAULT_ADMIN_ROLE)
        // We need to schedule through timelock
        address[] memory targets = new address[](1);
        targets[0] = address(stakingRewardDistributorProxy);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory payloads = new bytes[](1);
        payloads[0] = abi.encodeWithSelector(StakingRewardDistributor.kill.selector);

        bytes32 predecessor = bytes32(0);
        bytes32 salt = keccak256("KILL_STAKING_REWARD_DISTRIBUTOR");

        vm.prank(admin);
        adminTimelock.schedule(targets[0], values[0], payloads[0], predecessor, salt, MIN_DELAY);

        vm.warp(block.timestamp + MIN_DELAY + 1);

        vm.prank(admin);
        adminTimelock.execute(targets[0], values[0], payloads[0], predecessor, salt);

        // Verify contract is killed
        assertTrue(stakingRewardDistributorProxy.isKilled(), "Contract should be killed");
    }

    function testRoleSeparation() public {
        // First perform the upgrade
        testUpgradeToAccessControl();

        IAccessControl accessControlled = IAccessControl(address(stakingRewardDistributorProxy));
        bytes32 DEFAULT_ADMIN_ROLE = 0x00;
        bytes32 REWARD_MANAGER_ROLE = keccak256("REWARD_MANAGER_ROLE");

        // Verify role separation
        assertTrue(accessControlled.hasRole(DEFAULT_ADMIN_ROLE, OPTIMISM_ADMIN_TIMELOCK), "Timelock should be admin");
        assertTrue(
            accessControlled.hasRole(REWARD_MANAGER_ROLE, TREASURY_MULTISIG), "Treasury should be reward manager"
        );

        // Timelock should NOT have REWARD_MANAGER_ROLE initially
        assertFalse(
            accessControlled.hasRole(REWARD_MANAGER_ROLE, OPTIMISM_ADMIN_TIMELOCK),
            "Timelock should not have REWARD_MANAGER_ROLE"
        );

        // But timelock can grant it to itself if needed (has DEFAULT_ADMIN_ROLE)
        // Schedule granting REWARD_MANAGER_ROLE to another address
        address newRewardManager = makeAddr("newRewardManager");

        address[] memory targets = new address[](1);
        targets[0] = address(stakingRewardDistributorProxy);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory payloads = new bytes[](1);
        payloads[0] = abi.encodeWithSelector(IAccessControl.grantRole.selector, REWARD_MANAGER_ROLE, newRewardManager);

        bytes32 predecessor = bytes32(0);
        bytes32 salt = keccak256("GRANT_NEW_REWARD_MANAGER");

        vm.prank(admin);
        adminTimelock.schedule(targets[0], values[0], payloads[0], predecessor, salt, MIN_DELAY);

        vm.warp(block.timestamp + MIN_DELAY + 1);

        vm.prank(admin);
        adminTimelock.execute(targets[0], values[0], payloads[0], predecessor, salt);

        // Verify new reward manager has the role
        assertTrue(
            accessControlled.hasRole(REWARD_MANAGER_ROLE, newRewardManager), "New reward manager should have role"
        );
    }

    function testMigrationCanOnlyBeCalledOnce() public {
        // First perform the upgrade
        testUpgradeToAccessControl();

        // Try to call migration again - should revert
        vm.expectRevert(); // Already initialized
        stakingRewardDistributorProxy.migrateToAccessControl();
    }

    function testPauserIntegration() public {
        // First, upgrade the Pauser contract to add the new pause flag
        _upgradePauser();

        address pauserProxy = config.getPauser();

        // Second, upgrade StakeWeight to add permanent staking support
        ProxyAdmin stakeWeightProxyAdmin = ProxyAdmin(STAKE_WEIGHT_PROXY_ADMIN);
        StakeWeight newStakeWeightImpl = new StakeWeight();

        address[] memory stakeWeightTargets = new address[](1);
        stakeWeightTargets[0] = address(stakeWeightProxyAdmin);

        uint256[] memory stakeWeightValues = new uint256[](1);
        stakeWeightValues[0] = 0;

        bytes[] memory stakeWeightPayloads = new bytes[](1);
        stakeWeightPayloads[0] = abi.encodeWithSelector(
            ProxyAdmin.upgradeAndCall.selector,
            ITransparentUpgradeableProxy(STAKE_WEIGHT_PROXY),
            address(newStakeWeightImpl),
            ""
        );

        bytes32 stakeWeightSalt = keccak256("STAKE_WEIGHT_PERMANENT_UPGRADE");

        vm.prank(admin);
        adminTimelock.scheduleBatch(
            stakeWeightTargets, stakeWeightValues, stakeWeightPayloads, bytes32(0), stakeWeightSalt, MIN_DELAY
        );

        vm.warp(block.timestamp + MIN_DELAY + 1);

        vm.prank(admin);
        adminTimelock.executeBatch(
            stakeWeightTargets, stakeWeightValues, stakeWeightPayloads, bytes32(0), stakeWeightSalt
        );

        // Third, perform the StakingRewardDistributor upgrade
        testUpgradeToAccessControl();

        // Test pausing functionality
        Pauser pauser = Pauser(pauserProxy);

        address pauserAddress = 0x2D723C20Cb297E8F3F8cd885584623F97B5A7583;

        // Pause with the pauser address (has PAUSER_ROLE)
        vm.prank(pauserAddress);
        pauser.setIsStakingRewardDistributorPaused(true);

        // Verify pause works
        vm.prank(makeAddr("user"));
        vm.expectRevert(StakingRewardDistributor.Paused.selector);
        stakingRewardDistributorProxy.claim(makeAddr("user"));

        // Unpause needs UNPAUSER_ROLE, which is held by the admin (timelock)
        // We'll schedule an unpause through the timelock
        address[] memory unpauseTargets = new address[](1);
        unpauseTargets[0] = pauserProxy;

        uint256[] memory unpauseValues = new uint256[](1);
        unpauseValues[0] = 0;

        bytes[] memory unpausePayloads = new bytes[](1);
        unpausePayloads[0] = abi.encodeWithSelector(Pauser.setIsStakingRewardDistributorPaused.selector, false);

        bytes32 unpauseSalt = keccak256("UNPAUSE_STAKING_REWARD_DISTRIBUTOR");

        // Manager Multisig proposes the unpause
        vm.prank(OPTIMISM_MANAGER_MULTISIG);
        managerTimelock.schedule(
            unpauseTargets[0], unpauseValues[0], unpausePayloads[0], bytes32(0), unpauseSalt, MIN_DELAY
        );

        vm.warp(block.timestamp + MIN_DELAY + 1);

        // Manager Multisig executes (has EXECUTOR_ROLE)
        vm.prank(OPTIMISM_MANAGER_MULTISIG);
        managerTimelock.execute(unpauseTargets[0], unpauseValues[0], unpausePayloads[0], bytes32(0), unpauseSalt);

        // Now claim should work since all contracts are upgraded
        vm.prank(makeAddr("user"));
        stakingRewardDistributorProxy.claim(makeAddr("user"));

        // Test proves complete integration:
        // 1. Pauser upgrade with new StakingRewardDistributor pause flag
        // 2. StakeWeight upgrade with permanent staking support
        // 3. StakingRewardDistributor upgrade with AccessControl
        // 4. All pause/unpause mechanisms work with correct roles
    }
}
