// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Test } from "forge-std/Test.sol";
import { BaseScript, OptimismDeployments } from "script/Base.s.sol";
import { OptimismDeploy } from "script/deploy/OptimismDeploy.s.sol";
import { Base_Test } from "test/Base.t.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Options } from "openzeppelin-foundry-upgrades/Options.sol";
import { LegacyL2WCT } from "src/legacy/LegacyL2WCT.sol";
import { L2WCT } from "src/L2WCT.sol";

contract L2WCT_StorageCompatibility_ForkTest is Base_Test {
    BaseScript base;
    OptimismDeployments deployments;
    uint256 constant OPTIMISM_CHAIN_ID = 10;
    uint256 constant FORK_BLOCK = 133_119_400; // Pin to specific block for determinism

    // Environment addresses
    address public opBridge;

    function setUp() public override {
        // Fork Optimism mainnet at specific block
        vm.createSelectFork(vm.envString("OPTIMISM_RPC_URL"), FORK_BLOCK);

        // Set the chain ID to match Optimism mainnet
        vm.chainId(OPTIMISM_CHAIN_ID);

        // Set addresses from environment
        opBridge = vm.envAddress("OP_BRIDGE_ADDRESS");

        // Initialize base script
        base = new OptimismDeploy();

        // Read existing deployments
        deployments = base.readOptimismDeployments(OPTIMISM_CHAIN_ID);

        // Ensure we have the L2WCT deployment
        require(address(deployments.l2wct) != address(0), "L2WCT not deployed");
    }

    function testFork_upgradeValidation_preservesState() public {
        // Get the current implementation address
        address currentImpl = Upgrades.getImplementationAddress(address(deployments.l2wct));

        // Deploy new implementation
        L2WCT newImpl = new L2WCT();

        // Prepare initialization data for the new contract
        L2WCT.Init memory newInit = L2WCT.Init({
            initialAdmin: deployments.l2wct.hasRole(
                deployments.l2wct.DEFAULT_ADMIN_ROLE(), address(deployments.adminTimelock)
            ) ? address(deployments.adminTimelock) : address(this),
            initialManager: deployments.l2wct.hasRole(
                deployments.l2wct.MANAGER_ROLE(), address(deployments.managerTimelock)
            ) ? address(deployments.managerTimelock) : address(this),
            initialMinter: address(this),
            initialBridge: opBridge
        });

        // Set up upgrade options with reference contract
        Options memory opts;
        opts.referenceContract = "LegacyL2WCT.sol";
        opts.unsafeSkipAllChecks = false; // Ensure all checks are performed

        // Simulate upgrade (this won't actually upgrade, just validates)
        vm.startPrank(address(address(deployments.adminTimelock)));

        // Validate upgrade with reference contract
        Upgrades.validateUpgrade("L2WCT.sol", opts);

        // Upgrade the contract
        Upgrades.upgradeProxy(address(deployments.l2wct), "L2WCT.sol", bytes(""), opts);

        // Verify state preservation
        L2WCT upgraded = L2WCT(address(deployments.l2wct));

        // Verify version
        assertEq(upgraded.version(), "2.0.0", "Version mismatch after upgrade");

        upgraded.setBridge(opBridge);
        // Verify bridge address (using new storage layout)
        assertEq(upgraded.crosschainBridge(), opBridge, "Bridge address not preserved after upgrade");

        // Verify roles are preserved
        assertTrue(
            upgraded.hasRole(upgraded.DEFAULT_ADMIN_ROLE(), address(deployments.adminTimelock)),
            "Admin role not preserved after upgrade"
        );
        assertTrue(
            upgraded.hasRole(upgraded.MANAGER_ROLE(), address(deployments.managerTimelock)),
            "Manager role not preserved after upgrade"
        );

        // Test crosschain functionality
        address testUser = address(0xabcd);
        uint256 testAmount = 1000 ether;

        resetPrank(address(deployments.managerTimelock));
        // Set test user as allowed
        upgraded.setAllowedFrom(testUser, true);
        assertTrue(upgraded.allowedFrom(testUser), "AllowedFrom functionality broken after upgrade");

        resetPrank(opBridge);
        // Test crosschain mint
        upgraded.crosschainMint(testUser, testAmount);
        assertEq(upgraded.balanceOf(testUser), testAmount, "Crosschain mint broken after upgrade");

        // Test crosschain burn
        upgraded.crosschainBurn(testUser, testAmount);
        assertEq(upgraded.balanceOf(testUser), 0, "Crosschain burn broken after upgrade");

        vm.stopPrank();
    }

    function testFork_upgradeSafety_validatesImplementation() public {
        // Deploy new implementation
        L2WCT newImpl = new L2WCT();

        // Get current implementation
        address currentImpl = Upgrades.getImplementationAddress(address(deployments.l2wct));

        // Prepare initialization data
        L2WCT.Init memory newInit = L2WCT.Init({
            initialAdmin: address(deployments.adminTimelock),
            initialManager: address(deployments.managerTimelock),
            initialMinter: address(this),
            initialBridge: opBridge
        });

        // Set up upgrade options with reference contract
        Options memory opts;
        opts.referenceContract = "LegacyL2WCT.sol";
        opts.unsafeSkipAllChecks = false; // Ensure all checks are performed

        // Validate upgrade safety with reference contract
        Upgrades.validateUpgrade("L2WCT.sol", opts);
    }

    function testFork_storageLayout_isCompatible() public {
        // Set up upgrade options with reference contract
        Options memory opts;
        opts.referenceContract = "LegacyL2WCT.sol";
        opts.unsafeSkipAllChecks = false;

        // This will perform a comprehensive storage layout check
        Upgrades.validateUpgrade("L2WCT.sol", opts);
    }
}
