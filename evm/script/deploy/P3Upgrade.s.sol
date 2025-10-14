// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Pauser } from "src/Pauser.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { LockedTokenStaker } from "src/LockedTokenStaker.sol";
import { OptimismDeployments, BaseScript } from "script/Base.s.sol";
import { Eip1967Logger } from "script/utils/Eip1967Logger.sol";
import { newLockedTokenStaker } from "script/helpers/Proxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Options } from "openzeppelin-foundry-upgrades/Options.sol";

/**
 * @title P3Upgrade
 * @notice Deployment script for P3 Staking upgrade implementations and new LockedTokenStakers
 * @dev This deploys NEW implementations and NEW LockedTokenStakers (with proxies)
 *      The actual upgrades are executed via timelock (see docs/P3_UPGRADE_EXECUTION_GUIDE.md)
 */
contract P3Upgrade is BaseScript {
    // Store deployed addresses
    address public newPauserImpl;
    address public newStakeWeightImpl;
    address public newSRDImpl;

    // New LockedTokenStakers with P3 support
    LockedTokenStaker public newLockedTokenStakerReown;
    LockedTokenStaker public newLockedTokenStakerWalletConnect;
    LockedTokenStaker public newLockedTokenStakerBackers;

    /**
     * @notice Deploy all new implementations for P3 upgrade
     */
    function deployImplementations() public broadcast returns (address, address, address) {
        console2.log("=== Deploying P3 Upgrade Implementations ===");

        // Deploy Pauser implementation (with StakingRewardDistributor pause support)
        console2.log("Deploying new Pauser implementation...");
        newPauserImpl = address(new Pauser());
        console2.log("Pauser implementation:", newPauserImpl);

        // Deploy StakeWeight implementation (with permanent locks)
        console2.log("Deploying new StakeWeight implementation...");
        newStakeWeightImpl = address(new StakeWeight());
        console2.log("StakeWeight implementation:", newStakeWeightImpl);

        // Validate StakeWeight upgrade
        console2.log("Validating StakeWeight upgrade...");
        Options memory opts;
        opts.referenceContract = "OldStakeWeight.sol:OldStakeWeight";
        opts.unsafeSkipStorageCheck = false;
        Upgrades.validateUpgrade("StakeWeight.sol:StakeWeight", opts);
        console2.log("StakeWeight upgrade validation: PASSED");

        // Deploy StakingRewardDistributor implementation (with AccessControl)
        console2.log("Deploying new StakingRewardDistributor implementation...");
        newSRDImpl = address(new StakingRewardDistributor());
        console2.log("StakingRewardDistributor implementation:", newSRDImpl);

        console2.log("\n=== Implementation Deployment Complete ===");
        console2.log("Pauser:                    ", newPauserImpl);
        console2.log("StakeWeight:               ", newStakeWeightImpl);
        console2.log("StakingRewardDistributor:  ", newSRDImpl);

        return (newPauserImpl, newStakeWeightImpl, newSRDImpl);
    }

    /**
     * @notice Deploy new LockedTokenStakers with proxies (P3 support)
     * @dev Uses OpenZeppelin v5 TransparentUpgradeableProxy pattern
     *      Each proxy auto-deploys its own ProxyAdmin (owned by Admin Timelock)
     *      Uses CREATE2 with "-p3" suffix to avoid salt collision with old deployments
     */
    function deployLockedTokenStakers() public broadcast {
        console2.log("\n=== Deploying New LockedTokenStakers (P3) ===");
        console2.log("NOTE: Each proxy will auto-deploy its own ProxyAdmin");

        OptimismDeployments memory deps = readOptimismDeployments(block.chainid);

        // Verify prerequisites
        require(address(deps.adminTimelock) != address(0), "Admin Timelock not deployed");
        require(address(deps.config) != address(0), "WalletConnectConfig not deployed");
        require(address(deps.merkleVesterReown) != address(0), "MerkleVesterReown not set");
        require(address(deps.merkleVesterWalletConnect) != address(0), "MerkleVesterWalletConnect not set");
        require(address(deps.merkleVesterBackers) != address(0), "MerkleVesterBackers not set");

        // Deploy LockedTokenStaker Reown (P3)
        console2.log("Deploying LockedTokenStaker Reown (P3)...");
        newLockedTokenStakerReown = newLockedTokenStaker({
            initialOwner: address(deps.adminTimelock),
            init: LockedTokenStaker.Init({
                vesterContract: address(deps.merkleVesterReown), config: address(deps.config)
            }),
            identifier: "reown"
        });
        console2.log("LockedTokenStaker Reown (P3) proxy:", address(newLockedTokenStakerReown));
        console2.log("  Implementation:", Eip1967Logger.getImplementation(vm, address(newLockedTokenStakerReown)));
        console2.log("  ProxyAdmin:    ", Eip1967Logger.getAdmin(vm, address(newLockedTokenStakerReown)));

        // Deploy LockedTokenStaker WalletConnect (P3)
        console2.log("Deploying LockedTokenStaker WalletConnect (P3)...");
        newLockedTokenStakerWalletConnect = newLockedTokenStaker({
            initialOwner: address(deps.adminTimelock),
            init: LockedTokenStaker.Init({
                vesterContract: address(deps.merkleVesterWalletConnect), config: address(deps.config)
            }),
            identifier: "walletconnect"
        });
        console2.log("LockedTokenStaker WalletConnect (P3) proxy:", address(newLockedTokenStakerWalletConnect));
        console2.log(
            "  Implementation:", Eip1967Logger.getImplementation(vm, address(newLockedTokenStakerWalletConnect))
        );
        console2.log("  ProxyAdmin:    ", Eip1967Logger.getAdmin(vm, address(newLockedTokenStakerWalletConnect)));

        // Deploy LockedTokenStaker Backers (P3)
        console2.log("Deploying LockedTokenStaker Backers (P3)...");
        newLockedTokenStakerBackers = newLockedTokenStaker({
            initialOwner: address(deps.adminTimelock),
            init: LockedTokenStaker.Init({
                vesterContract: address(deps.merkleVesterBackers), config: address(deps.config)
            }),
            identifier: "backers"
        });
        console2.log("LockedTokenStaker Backers (P3) proxy:", address(newLockedTokenStakerBackers));
        console2.log("  Implementation:", Eip1967Logger.getImplementation(vm, address(newLockedTokenStakerBackers)));
        console2.log("  ProxyAdmin:    ", Eip1967Logger.getAdmin(vm, address(newLockedTokenStakerBackers)));

        console2.log("\n=== New LockedTokenStakers Deployed ===");
        console2.log("NOTE: These need to be whitelisted in MerkleVesters by Benefactor multisigs");
        console2.log("See docs/P3_UPGRADE_EXECUTION_GUIDE.md Phase 3");
    }

    /**
     * @notice Full P3 deployment (implementations + LockedTokenStakers)
     */
    function run() public {
        // Deploy implementations
        deployImplementations();

        // Deploy new LockedTokenStakers
        deployLockedTokenStakers();

        // Write to JSON if broadcasting
        if (vm.envOr("BROADCAST", false)) {
            writeP3DeploymentsToJson();
        }

        console2.log("\n=== P3 Upgrade Deployment Complete ===");
        console2.log("\nNext Steps:");
        console2.log("1. Verify all deployments on Optimism block explorer");
        console2.log("2. Prepare timelock batch with these implementation addresses:");
        console2.log("   - Pauser:                   ", newPauserImpl);
        console2.log("   - StakeWeight:              ", newStakeWeightImpl);
        console2.log("   - StakingRewardDistributor: ", newSRDImpl);
        console2.log("3. Add new LockedTokenStakers to MerkleVesters:");
        console2.log("   - Reown:        ", address(newLockedTokenStakerReown));
        console2.log("   - WalletConnect:", address(newLockedTokenStakerWalletConnect));
        console2.log("   - Backers:      ", address(newLockedTokenStakerBackers));
        console2.log("\nSee docs/P3_UPGRADE_EXECUTION_GUIDE.md for complete instructions");
    }

    /**
     * @notice Verify all deployments
     */
    function verify() public view {
        console2.log("=== Verifying P3 Deployments ===");

        OptimismDeployments memory deps = readOptimismDeployments(block.chainid);

        // Verify implementations are contracts
        require(newPauserImpl.code.length > 0, "Pauser impl not deployed");
        require(newStakeWeightImpl.code.length > 0, "StakeWeight impl not deployed");
        require(newSRDImpl.code.length > 0, "SRD impl not deployed");

        // Verify LockedTokenStakers are proxies
        address ltsReownImpl = Eip1967Logger.getImplementation(vm, address(newLockedTokenStakerReown));
        address ltsWalletConnectImpl = Eip1967Logger.getImplementation(vm, address(newLockedTokenStakerWalletConnect));
        address ltsBackersImpl = Eip1967Logger.getImplementation(vm, address(newLockedTokenStakerBackers));

        require(ltsReownImpl != address(0), "LockedTokenStaker Reown not a proxy");
        require(ltsWalletConnectImpl != address(0), "LockedTokenStaker WalletConnect not a proxy");
        require(ltsBackersImpl != address(0), "LockedTokenStaker Backers not a proxy");

        // Verify ProxyAdmin ownership
        address ltsReownAdmin = Eip1967Logger.getAdmin(vm, address(newLockedTokenStakerReown));
        address ltsWalletConnectAdmin = Eip1967Logger.getAdmin(vm, address(newLockedTokenStakerWalletConnect));
        address ltsBackersAdmin = Eip1967Logger.getAdmin(vm, address(newLockedTokenStakerBackers));

        require(
            ProxyAdmin(ltsReownAdmin).owner() == address(deps.adminTimelock),
            "LockedTokenStaker Reown ProxyAdmin not owned by Admin Timelock"
        );
        require(
            ProxyAdmin(ltsWalletConnectAdmin).owner() == address(deps.adminTimelock),
            "LockedTokenStaker WalletConnect ProxyAdmin not owned by Admin Timelock"
        );
        require(
            ProxyAdmin(ltsBackersAdmin).owner() == address(deps.adminTimelock),
            "LockedTokenStaker Backers ProxyAdmin not owned by Admin Timelock"
        );

        // Verify initialization
        require(
            address(newLockedTokenStakerReown.vesterContract()) == address(deps.merkleVesterReown),
            "LockedTokenStaker Reown vester mismatch"
        );
        require(
            address(newLockedTokenStakerWalletConnect.vesterContract()) == address(deps.merkleVesterWalletConnect),
            "LockedTokenStaker WalletConnect vester mismatch"
        );
        require(
            address(newLockedTokenStakerBackers.vesterContract()) == address(deps.merkleVesterBackers),
            "LockedTokenStaker Backers vester mismatch"
        );

        console2.log("All verifications passed!");
    }

    /**
     * @notice Log deployment calldata for timelock batch
     * @dev Expects caller to pass implementation addresses (typically parsed from
     *      deployments/{chainId}-p3-upgrade.json). Validates addresses are non-zero
     *      and outputs encoded ProxyAdmin.upgradeAndCall() calldata for each upgrade.
     * @param pauserImpl Address of new Pauser implementation
     * @param stakeWeightImpl Address of new StakeWeight implementation
     * @param srdImpl Address of new StakingRewardDistributor implementation
     */
    function logTimelockCalldata(address pauserImpl, address stakeWeightImpl, address srdImpl) public view {
        require(pauserImpl != address(0), "Pauser impl is zero");
        require(stakeWeightImpl != address(0), "StakeWeight impl is zero");
        require(srdImpl != address(0), "SRD impl is zero");

        console2.log("\n=== Timelock Batch Calldata ===");

        OptimismDeployments memory deps = readOptimismDeployments(block.chainid);

        // Pauser upgrade calldata
        bytes memory pauserUpgradeData = abi.encodeWithSelector(
            ProxyAdmin.upgradeAndCall.selector,
            address(deps.pauser), // proxy
            pauserImpl, // new implementation
            "" // no initialization
        );
        console2.log("Pauser ProxyAdmin target:  ", Eip1967Logger.getAdmin(vm, address(deps.pauser)));
        console2.logBytes(pauserUpgradeData);

        // StakeWeight upgrade calldata
        bytes memory stakeWeightUpgradeData = abi.encodeWithSelector(
            ProxyAdmin.upgradeAndCall.selector, address(deps.stakeWeight), stakeWeightImpl, ""
        );
        console2.log("\nStakeWeight ProxyAdmin target:", Eip1967Logger.getAdmin(vm, address(deps.stakeWeight)));
        console2.logBytes(stakeWeightUpgradeData);

        // SRD upgrade + migration calldata
        bytes memory srdMigrationData = abi.encodeWithSelector(StakingRewardDistributor.migrateToAccessControl.selector);
        bytes memory srdUpgradeData = abi.encodeWithSelector(
            ProxyAdmin.upgradeAndCall.selector,
            address(deps.stakingRewardDistributor),
            srdImpl,
            srdMigrationData // ATOMIC migration
        );
        console2.log(
            "\nSRD ProxyAdmin target:      ", Eip1967Logger.getAdmin(vm, address(deps.stakingRewardDistributor))
        );
        console2.logBytes(srdUpgradeData);

        console2.log("\n=== Implementation Addresses ===");
        console2.log("Pauser:                    ", pauserImpl);
        console2.log("StakeWeight:               ", stakeWeightImpl);
        console2.log("StakingRewardDistributor:  ", srdImpl);
    }

    /**
     * @notice Write P3 deployment information to JSON file
     */
    function writeP3DeploymentsToJson() public {
        string memory json = "{}";

        // Add chain ID
        json = stdJson.serialize("json", "chainId", block.chainid);

        // Add new implementation addresses
        string memory implJson = "{}";
        implJson = stdJson.serialize("implJson", "Pauser", newPauserImpl);
        implJson = stdJson.serialize("implJson", "StakeWeight", newStakeWeightImpl);
        implJson = stdJson.serialize("implJson", "StakingRewardDistributor", newSRDImpl);
        json = stdJson.serialize("json", "NewImplementations", implJson);

        // Add new LockedTokenStaker proxies with full details
        if (address(newLockedTokenStakerReown) != address(0)) {
            string memory ltsReownJson = "{}";
            ltsReownJson = stdJson.serialize("ltsReownJson", "proxy", address(newLockedTokenStakerReown));
            ltsReownJson = stdJson.serialize(
                "ltsReownJson",
                "implementation",
                Eip1967Logger.getImplementation(vm, address(newLockedTokenStakerReown))
            );
            ltsReownJson = stdJson.serialize(
                "ltsReownJson", "admin", Eip1967Logger.getAdmin(vm, address(newLockedTokenStakerReown))
            );
            json = stdJson.serialize("json", "LockedTokenStakerReownP3", ltsReownJson);
        }

        if (address(newLockedTokenStakerWalletConnect) != address(0)) {
            string memory ltsWalletConnectJson = "{}";
            ltsWalletConnectJson =
                stdJson.serialize("ltsWalletConnectJson", "proxy", address(newLockedTokenStakerWalletConnect));
            ltsWalletConnectJson = stdJson.serialize(
                "ltsWalletConnectJson",
                "implementation",
                Eip1967Logger.getImplementation(vm, address(newLockedTokenStakerWalletConnect))
            );
            ltsWalletConnectJson = stdJson.serialize(
                "ltsWalletConnectJson", "admin", Eip1967Logger.getAdmin(vm, address(newLockedTokenStakerWalletConnect))
            );
            json = stdJson.serialize("json", "LockedTokenStakerWalletConnectP3", ltsWalletConnectJson);
        }

        if (address(newLockedTokenStakerBackers) != address(0)) {
            string memory ltsBackersJson = "{}";
            ltsBackersJson = stdJson.serialize("ltsBackersJson", "proxy", address(newLockedTokenStakerBackers));
            ltsBackersJson = stdJson.serialize(
                "ltsBackersJson",
                "implementation",
                Eip1967Logger.getImplementation(vm, address(newLockedTokenStakerBackers))
            );
            ltsBackersJson = stdJson.serialize(
                "ltsBackersJson", "admin", Eip1967Logger.getAdmin(vm, address(newLockedTokenStakerBackers))
            );
            json = stdJson.serialize("json", "LockedTokenStakerBackersP3", ltsBackersJson);
        }

        // Write to file with P3-specific name
        string memory deploymentsPath = string.concat(vm.projectRoot(), "/deployments/");
        vm.createDir(deploymentsPath, true);
        string memory filePath = string.concat(deploymentsPath, vm.toString(block.chainid), "-p3-upgrade.json");
        vm.writeFile(filePath, json);

        console2.log("\n=== P3 Deployments written to JSON ===");
        console2.log("File: %s", filePath);
    }
}
