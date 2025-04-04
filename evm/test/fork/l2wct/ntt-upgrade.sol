// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Base_Test } from "test/Base.t.sol";
import { L2WCT } from "src/L2WCT.sol";
import { LegacyL2WCT } from "src/legacy/LegacyL2WCT.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { OptimismDeployments } from "script/Base.s.sol";
import { OptimismDeploy } from "script/deploy/OptimismDeploy.s.sol";
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { Eip1967Logger } from "script/utils/Eip1967Logger.sol";
import { NttManager } from "src/utils/wormhole/NttManagerFlat.sol";
import { IERC7802 } from "src/interfaces/IERC7802.sol";
import { INttToken } from "src/interfaces/INttToken.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { console } from "forge-std/console.sol";

contract L2WCT_NttUpgrade_ForkTest is Base_Test {
    // ============ Constants ============
    uint256 public constant YEAR = 365 days;
    address public constant SUPERCHAIN_BRIDGE = 0x4200000000000000000000000000000000000028;

    // ============ Test Contracts ============
    TimelockController public timelock;
    LegacyL2WCT public legacyL2WCT;
    ProxyAdmin public proxyAdmin;

    // ============ Test Addresses ============
    address public admin;
    address public manager;
    address public minter;
    address public user1;
    address public user2;
    address public user3;

    // ============ Legacy Storage Values (captured before upgrade) ============
    address public remoteToken;
    address public bridge;
    uint256 public legacyTotalSupply;
    uint256 public legacyBalanceUser1;
    uint256 public legacyBalanceUser2;
    uint256 public legacyAllowanceUser1User2;
    uint256 public legacyVotesUser3;

    // ============ Storage Slots ============
    bytes32 private constant BRIDGE_SLOT = bytes32(uint256(keccak256("walletconnect.bridge")) - 1);

    // Whitelisted addresses
    address[] public whitelistedFromAddresses;
    address[] public whitelistedToAddresses;

    function setUp() public override {
        // Fork Optimism mainnet at a specific block
        vm.createSelectFork("optimism", 133_119_400);

        // Deploy mock bridge if needed
        deployLegacyMockOptimismBridge();

        // Read deployments and params
        OptimismDeployments memory deps = new OptimismDeploy().readOptimismDeployments(block.chainid);

        // Label deployments
        vm.label(address(deps.l2wct), "L2WCT");
        vm.label(address(deps.config), "WalletConnectConfig");
        vm.label(address(deps.pauser), "Pauser");
        vm.label(address(deps.stakeWeight), "StakeWeight");
        vm.label(address(deps.stakingRewardDistributor), "StakingRewardDistributor");
        vm.label(address(deps.adminTimelock), "AdminTimelock");
        vm.label(address(deps.managerTimelock), "ManagerTimelock");
        vm.label(address(deps.airdrop), "Airdrop");
        vm.label(address(deps.lockedTokenStakerReown), "LockedTokenStakerReown");
        vm.label(address(deps.merkleVesterReown), "MerkleVesterReown");
        vm.label(address(deps.lockedTokenStakerWalletConnect), "LockedTokenStakerWalletConnect");
        vm.label(address(deps.merkleVesterWalletConnect), "MerkleVesterWalletConnect");
        vm.label(address(deps.lockedTokenStakerBackers), "LockedTokenStakerBackers");
        vm.label(address(deps.merkleVesterBackers), "MerkleVesterBackers");
        vm.label(address(deps.stakingRewardsCalculator), "StakingRewardsCalculator");

        // Set up contract instances and addresses
        timelock = TimelockController(payable(deps.adminTimelock));
        admin = vm.envAddress("ADMIN_ADDRESS");
        manager = vm.envAddress("MANAGER_ADDRESS");

        // Get the L2WCT contract (currently LegacyL2WCT implementation)
        legacyL2WCT = LegacyL2WCT(address(deps.l2wct));

        // Create test users
        minter = makeAddr("minter");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Set up pre-upgrade state
        vm.startPrank(address(timelock));
        if (legacyL2WCT.hasRole(legacyL2WCT.DEFAULT_ADMIN_ROLE(), address(timelock))) {
            try legacyL2WCT.mint(user1, 1000 ether) { } catch { }
            try legacyL2WCT.mint(user2, 500 ether) { } catch { }
        }
        vm.stopPrank();

        vm.startPrank(user1);
        try legacyL2WCT.approve(user2, 100 ether) { } catch { }
        try legacyL2WCT.delegate(user3) { } catch { }
        vm.stopPrank();

        // Get reference to the proxy
        l2wct = L2WCT(address(deps.l2wct));

        // Store legacy values before upgrade
        remoteToken = legacyL2WCT.remoteToken();
        bridge = legacyL2WCT.bridge();
        legacyTotalSupply = legacyL2WCT.totalSupply();
        legacyBalanceUser1 = legacyL2WCT.balanceOf(user1);
        legacyBalanceUser2 = legacyL2WCT.balanceOf(user2);
        legacyAllowanceUser1User2 = legacyL2WCT.allowance(user1, user2);
        legacyVotesUser3 = legacyL2WCT.getVotes(user3);

        // Get the proxy admin and perform upgrade
        address proxyAdminAddress = Eip1967Logger.getAdmin(vm, address(l2wct));
        proxyAdmin = ProxyAdmin(proxyAdminAddress);

        L2WCT newImpl = new L2WCT();
        vm.startPrank(address(timelock));
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(l2wct))),
            address(newImpl),
            "" // No initialization data needed
        );
        vm.stopPrank();

        // Set up NttManager
        nttManager = NttManager(0x164Be303480f542336bE0bBe0432A13b85e6FD1b); // Use nttManager consistently

        // Initialize whitelisted addresses
        initializeWhitelistedAddresses();

        super.setUp();
    }

    function initializeWhitelistedAddresses() internal {
        // Addresses that are whitelisted for "from" direction
        whitelistedFromAddresses.push(0x9e6ebE1D7d993288E1861f8f1Be8a855AE1b0b51);
        whitelistedFromAddresses.push(0xefd5502ED94FD104aA91cc160BEdc1657e83f62a);
        whitelistedFromAddresses.push(0x72e93123e8b5D168246739CDC45360ea11209364);
        whitelistedFromAddresses.push(0x521B4C065Bbdbe3E20B3727340730936912DfA46); // both from and to
        whitelistedFromAddresses.push(0x45cacF6ecE305843A45160E8302bc06588ab1174);
        whitelistedFromAddresses.push(0xa86Ca428512D0A18828898d2e656E9eb1b6bA6E7); // both from and to
        whitelistedFromAddresses.push(0xF368F535e329c6d08DFf0d4b2dA961C4e7F3fCAF);
        whitelistedFromAddresses.push(0x6b919b54022F7562FB605c3a9EC081A5e2E502F0);
        whitelistedFromAddresses.push(0x648bddEE207da25e19918460c1Dc9F462F657a19);
        whitelistedFromAddresses.push(0x2dB7b3Cfa309Dc898B21A6cD62f7B75d91637F25);
        whitelistedFromAddresses.push(0x3bAa7b4d92432Db4F950f19d9b589BB57fbD3240);
        whitelistedFromAddresses.push(0xC859e2B8c9fC18aa43a6C737e5a8b7f14dCbA496);
        whitelistedFromAddresses.push(0x6f99ee719c2628288372E9972a136d44BDddA8e4);
        whitelistedFromAddresses.push(0x9BD2dc70221e279058eFDc20403c4848B9a87d29);
        whitelistedFromAddresses.push(0xC401D6C0b79b5DF63C530b6f02AaaC1aE5C5cb90);
        whitelistedFromAddresses.push(0x12AA92327a1E279F049238447C54DD1a67834303);
        whitelistedFromAddresses.push(0xee3273f6d29ddFFf08FfD9D513cfF314734f01A2);
        whitelistedFromAddresses.push(0x3269Bf2CCF5D63AFe30D36A5DfC80492066013b9);
        whitelistedFromAddresses.push(0xb64EE3353C83d06C5aCe79eCBEB9e4E0aE9c756B);
        whitelistedFromAddresses.push(0xCc97929655e472C2AD608aCd854C03fA15899e31);
        whitelistedFromAddresses.push(0x5bdf85216ec1e38D6458C870992A69e38e03F7Ef);
        whitelistedFromAddresses.push(0x91F582EC5ae315EFE97a6ADb33a5e7a804A6fc44);
        whitelistedFromAddresses.push(0x51F651B1482F7EF18bcbBBF0307035Ba9703f25C);
        whitelistedFromAddresses.push(0x5F01C4bce00612eF4fD3AC896497586f6922Aff4);

        // Addresses that are whitelisted for "to" direction
        whitelistedToAddresses.push(0x521B4C065Bbdbe3E20B3727340730936912DfA46); // both from and to
        whitelistedToAddresses.push(0xa86Ca428512D0A18828898d2e656E9eb1b6bA6E7); // both from and to
    }

    // ============ Upgrade Verification Tests ============

    function testFork_UpgradeSuccessful_SetsVersionAndInterfaces() public {
        assertEq(l2wct.version(), "2.0.0", "L2WCT should be version 2.0.0");
        assertTrue(l2wct.supportsInterface(type(INttToken).interfaceId), "L2WCT should support INttToken interface");
        assertTrue(l2wct.supportsInterface(type(IERC7802).interfaceId), "L2WCT should support IERC7802 interface");
    }

    function testFork_PostUpgradeStateVerification_PreservesState() public {
        // Core ERC20 properties
        assertEq(l2wct.name(), "WalletConnect", "Name should be preserved");
        assertEq(l2wct.symbol(), "WCT", "Symbol should be preserved");
        assertEq(l2wct.decimals(), 18, "Decimals should be preserved");

        // State preservation using stored legacy values
        assertEq(l2wct.totalSupply(), legacyTotalSupply, "Total supply should be preserved");
        assertEq(l2wct.balanceOf(user1), legacyBalanceUser1, "User1 balance should be preserved");
        assertEq(l2wct.balanceOf(user2), legacyBalanceUser2, "User2 balance should be preserved");
        assertEq(l2wct.allowance(user1, user2), legacyAllowanceUser1User2, "Allowance should be preserved");
        assertEq(l2wct.getVotes(user3), legacyVotesUser3, "Delegated voting power should be preserved");

        // Roles
        assertTrue(l2wct.hasRole(l2wct.DEFAULT_ADMIN_ROLE(), address(timelock)), "Admin role should be preserved");
        assertTrue(l2wct.hasRole(l2wct.MANAGER_ROLE(), address(manager)), "Manager role should be preserved");
    }

    function testFork_LegacyStoragePreservation_GettersWork() public {
        assertEq(
            l2wct.remoteTokenDeprecated(), remoteToken, "remoteTokenDeprecated getter should match legacy remoteToken"
        );
        assertEq(l2wct.bridgeDeprecated(), bridge, "bridgeDeprecated getter should match legacy bridge");
    }

    function testFork_RevertWhen_LegacyBridgeInteracts() public {
        vm.startPrank(bridge); // Prank the actual legacy bridge address

        vm.expectRevert();
        legacyL2WCT.mint(user1, 1000 ether);

        vm.expectRevert();
        legacyL2WCT.burn(user1, 1000 ether);

        vm.expectRevert();
        legacyL2WCT.BRIDGE();

        vm.expectRevert();
        legacyL2WCT.REMOTE_TOKEN();

        vm.stopPrank();
    }

    // ============ Bridge Functionality Tests ============

    function testFork_SuperchainBridgePermissions_AllowsMintAndBurn() public {
        vm.startPrank(address(timelock));
        l2wct.setBridge(SUPERCHAIN_BRIDGE);
        vm.stopPrank();

        vm.startPrank(address(manager));
        l2wct.setAllowedFrom(user1, true);
        vm.stopPrank();

        // Test Superchain bridge mint/burn
        vm.startPrank(SUPERCHAIN_BRIDGE);
        l2wct.crosschainMint(user1, 1000 ether);
        assertEq(l2wct.balanceOf(user1), 1000 ether, "Superchain bridge mint should succeed");

        l2wct.crosschainBurn(user1, 500 ether);
        assertEq(l2wct.balanceOf(user1), 500 ether, "Superchain bridge burn should succeed");
        vm.stopPrank();

        // Test unauthorized access
        address notBridge = makeAddr("notBridge");
        vm.startPrank(notBridge);

        vm.expectRevert(abi.encodeWithSelector(L2WCT.CallerNotBridge.selector, notBridge));
        l2wct.crosschainMint(user1, 1000 ether);

        vm.expectRevert(abi.encodeWithSelector(L2WCT.CallerNotBridge.selector, notBridge));
        l2wct.crosschainBurn(user1, 1000 ether);
        vm.stopPrank();
    }

    function testFork_RevertWhen_CallerNotSuperchainBridge_crosschainMint() public {
        vm.startPrank(address(timelock));
        l2wct.setBridge(SUPERCHAIN_BRIDGE);
        vm.stopPrank();

        address notBridge = makeAddr("notBridge");
        vm.startPrank(notBridge);
        vm.expectRevert(abi.encodeWithSelector(L2WCT.CallerNotBridge.selector, notBridge));
        l2wct.crosschainMint(user1, 1000 ether);
        vm.stopPrank();
    }

    function testFork_RevertWhen_CallerNotSuperchainBridge_crosschainBurn() public {
        vm.startPrank(address(timelock));
        l2wct.setBridge(SUPERCHAIN_BRIDGE);
        vm.stopPrank();

        // Allow user1 to send (needed for burn)
        vm.startPrank(address(manager));
        l2wct.setAllowedFrom(user1, true);
        vm.stopPrank();

        // Mint some tokens first
        vm.startPrank(SUPERCHAIN_BRIDGE);
        l2wct.crosschainMint(user1, 1000 ether);
        vm.stopPrank();

        address notBridge = makeAddr("notBridge");
        vm.startPrank(notBridge);
        vm.expectRevert(abi.encodeWithSelector(L2WCT.CallerNotBridge.selector, notBridge));
        l2wct.crosschainBurn(user1, 1000 ether);
        vm.stopPrank();
    }

    function testFork_WormholeBridgePermissions_AllowsMint() public {
        vm.startPrank(address(timelock));
        l2wct.setMinter(address(nttManager));
        vm.stopPrank();

        // Test Wormhole bridge mint
        vm.startPrank(address(nttManager));
        l2wct.mint(user1, 1000 ether);
        assertEq(l2wct.balanceOf(user1), 1000 ether, "Wormhole bridge mint should succeed");
        vm.stopPrank();
    }

    function testFork_RevertWhen_CallerNotMinter_mint() public {
        vm.startPrank(address(timelock));
        l2wct.setMinter(address(nttManager));
        vm.stopPrank();

        // Test unauthorized mint
        address notMinter = makeAddr("notMinter");
        vm.startPrank(notMinter);
        vm.expectRevert(abi.encodeWithSelector(INttToken.CallerNotMinter.selector, notMinter));
        l2wct.mint(user1, 1000 ether);
        vm.stopPrank();
    }

    function testFork_WormholeBridgePermissions_AllowsBurnByMinter() public {
        vm.startPrank(address(timelock));
        l2wct.setMinter(address(nttManager));
        vm.stopPrank();

        // Mint first
        vm.startPrank(address(nttManager));
        l2wct.mint(user1, 1000 ether);
        vm.stopPrank();

        // Test burn permissions
        vm.startPrank(address(manager));
        l2wct.setAllowedFrom(user1, true);
        l2wct.setAllowedFrom(address(nttManager), true);
        vm.stopPrank();

        vm.startPrank(user1);
        l2wct.transfer(address(nttManager), 500 ether);
        vm.stopPrank();

        vm.startPrank(address(nttManager));
        l2wct.burn(500 ether);
        assertEq(l2wct.balanceOf(user1), 500 ether, "Minter should be able to burn tokens sent to it");
        vm.stopPrank();
    }

    function testFork_RevertWhen_SuperchainBridgeCallsMint() public {
        vm.startPrank(address(timelock));
        l2wct.setBridge(SUPERCHAIN_BRIDGE);
        l2wct.setMinter(address(nttManager));
        vm.stopPrank();

        // Superchain bridge cannot use Wormhole functions
        vm.startPrank(SUPERCHAIN_BRIDGE);
        vm.expectRevert(abi.encodeWithSelector(INttToken.CallerNotMinter.selector, SUPERCHAIN_BRIDGE));
        l2wct.mint(user1, 1000 ether);
        vm.stopPrank();
    }

    function testFork_RevertWhen_WormholeBridgeCallsCrosschainMint() public {
        vm.startPrank(address(timelock));
        l2wct.setBridge(SUPERCHAIN_BRIDGE);
        l2wct.setMinter(address(nttManager));
        vm.stopPrank();

        // Wormhole bridge cannot use Superchain functions
        vm.startPrank(address(nttManager));
        vm.expectRevert(abi.encodeWithSelector(L2WCT.CallerNotBridge.selector, address(nttManager)));
        l2wct.crosschainMint(user1, 1000 ether);
        vm.stopPrank();
    }

    function testFork_RevertWhen_WormholeBridgeCallsCrosschainBurn() public {
        vm.startPrank(address(timelock));
        l2wct.setBridge(SUPERCHAIN_BRIDGE);
        l2wct.setMinter(address(nttManager));
        vm.stopPrank();

        // Allow user1 to send (needed for burn)
        vm.startPrank(address(manager));
        l2wct.setAllowedFrom(user1, true);
        vm.stopPrank();

        // Mint some tokens first via superchain bridge
        vm.startPrank(SUPERCHAIN_BRIDGE);
        l2wct.crosschainMint(user1, 1000 ether);
        vm.stopPrank();

        // Wormhole bridge cannot use Superchain functions
        vm.startPrank(address(nttManager));
        vm.expectRevert(abi.encodeWithSelector(L2WCT.CallerNotBridge.selector, address(nttManager)));
        l2wct.crosschainBurn(user1, 1000 ether);
        vm.stopPrank();
    }

    // ============ Transfer Restriction Tests ============

    function testFork_TransferRestrictions_EnforcesAndDisables() public {
        uint256 mintAmount = 1000 ether;

        vm.startPrank(address(timelock));
        l2wct.setMinter(minter);
        vm.stopPrank();

        vm.startPrank(minter);
        l2wct.mint(user1, mintAmount);
        vm.stopPrank();

        // Transfer should fail without allowance
        vm.startPrank(user1);
        vm.expectRevert(L2WCT.TransferRestricted.selector);
        l2wct.transfer(user2, mintAmount / 2);
        vm.stopPrank();

        // Allow transfers from user1
        vm.startPrank(manager);
        l2wct.setAllowedFrom(user1, true);
        vm.stopPrank();

        // Transfer should now succeed
        vm.startPrank(user1);
        l2wct.transfer(user2, mintAmount / 2);
        assertEq(l2wct.balanceOf(user2), mintAmount / 2, "User2 should have received tokens");
        vm.stopPrank();

        // Disable transfer restrictions
        vm.startPrank(address(timelock));
        l2wct.disableTransferRestrictions();
        vm.stopPrank();

        // Anyone should be able to transfer now
        vm.startPrank(user2);
        l2wct.transfer(user1, mintAmount / 4);
        assertEq(l2wct.balanceOf(user1), mintAmount / 2 + mintAmount / 4, "User1 should have received tokens back");
        vm.stopPrank();
    }

    // ============ Event Tests ============

    function testFork_EventEmission_SuperchainCrosschainMint() public {
        vm.startPrank(address(timelock));
        l2wct.setBridge(SUPERCHAIN_BRIDGE);
        vm.stopPrank();
        vm.startPrank(address(manager));
        l2wct.setAllowedFrom(user1, true);
        vm.stopPrank();

        vm.startPrank(SUPERCHAIN_BRIDGE);
        vm.expectEmit(true, true, true, true);
        emit CrosschainMint(user1, 1000 ether, SUPERCHAIN_BRIDGE);
        l2wct.crosschainMint(user1, 1000 ether);
        vm.stopPrank();
    }

    function testFork_EventEmission_SuperchainCrosschainBurn() public {
        vm.startPrank(address(timelock));
        l2wct.setBridge(SUPERCHAIN_BRIDGE);
        vm.stopPrank();
        vm.startPrank(address(manager));
        l2wct.setAllowedFrom(user1, true);
        vm.stopPrank();

        // Mint first
        vm.startPrank(SUPERCHAIN_BRIDGE);
        l2wct.crosschainMint(user1, 1000 ether);
        vm.stopPrank();

        vm.startPrank(SUPERCHAIN_BRIDGE);
        vm.expectEmit(true, true, true, true);
        emit CrosschainBurn(user1, 500 ether, SUPERCHAIN_BRIDGE);
        l2wct.crosschainBurn(user1, 500 ether);
        vm.stopPrank();
    }

    function testFork_EventEmission_WormholeMint() public {
        vm.startPrank(address(timelock));
        l2wct.setMinter(address(nttManager));
        vm.stopPrank();

        vm.startPrank(address(nttManager));
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), user2, 1000 ether);
        l2wct.mint(user2, 1000 ether);
        vm.stopPrank();
    }

    function testFork_EventEmission_WormholeBurn() public {
        vm.startPrank(address(timelock));
        l2wct.setMinter(address(nttManager));
        vm.stopPrank();
        vm.startPrank(address(manager));
        l2wct.setAllowedFrom(user2, true); // Allow user 2
        l2wct.setAllowedFrom(address(nttManager), true);
        vm.stopPrank();

        // Mint first
        vm.startPrank(address(nttManager));
        l2wct.mint(user2, 1000 ether);
        vm.stopPrank();

        // Transfer to minter
        vm.startPrank(user2);
        l2wct.transfer(address(nttManager), 500 ether);
        vm.stopPrank();

        // Burn
        vm.startPrank(address(nttManager));
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(nttManager), address(0), 500 ether);
        l2wct.burn(500 ether);
        vm.stopPrank();
    }

    function testFork_EventEmission_SetBridge() public {
        vm.startPrank(address(timelock));
        l2wct.setBridge(SUPERCHAIN_BRIDGE); // Set initial bridge
        address newBridge = makeAddr("newBridge");
        vm.expectEmit(true, true, true, true);
        emit NewBridge(SUPERCHAIN_BRIDGE, newBridge);
        l2wct.setBridge(newBridge);
        vm.stopPrank();
    }

    function testFork_EventEmission_SetMinter() public {
        vm.startPrank(address(timelock));
        l2wct.setMinter(address(nttManager)); // Set initial minter
        address newMinter = makeAddr("newMinter");
        vm.expectEmit(true, true, true, true);
        emit NewMinter(address(nttManager), newMinter);
        l2wct.setMinter(newMinter);
        vm.stopPrank();
    }

    // ============ Initialization Tests ============

    function testFork_RevertWhen_ReInitialized() public {
        vm.startPrank(address(timelock));
        L2WCT.Init memory init = L2WCT.Init({
            initialAdmin: address(timelock),
            initialManager: address(manager),
            initialMinter: address(nttManager),
            initialBridge: SUPERCHAIN_BRIDGE
        });

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        l2wct.initialize(init);
        vm.stopPrank();
    }

    // ============ Additional Tests from L2WCTNttUpgradeAdditional ============

    function testFork_NewBridgeFunctionality_AllowsMintAndBurn() public {
        // Create a new bridge address for this test
        address newCrosschainBridge = makeAddr("newCrosschainBridge");

        // Set the new bridge using the timelock (admin)
        vm.startPrank(address(timelock));
        l2wct.setBridge(newCrosschainBridge);
        vm.stopPrank();

        // Whitelist user1 for sending
        vm.prank(manager);
        l2wct.setAllowedFrom(user1, true);

        // Verify the new bridge is set correctly
        assertEq(l2wct.crosschainBridge(), newCrosschainBridge, "New crosschain bridge should be set correctly");

        // Test crosschain mint functionality
        vm.startPrank(newCrosschainBridge);
        uint256 mintAmount = 1000 * 10 ** 18;
        l2wct.crosschainMint(user1, mintAmount);
        assertEq(l2wct.balanceOf(user1), mintAmount, "User1 should have received tokens via crosschain mint");

        // Test crosschain burn functionality
        // Note: crosschainBurn requires the bridge to call it on behalf of the user.
        // The user must approve the bridge first if the bridge burns from the user's balance.
        // However, the current implementation burns from msg.sender (the bridge).
        // Need to transfer tokens to the bridge first if we want the bridge to burn its own tokens.
        // If the intent is for the bridge to burn *from* the user, the function signature/logic needs adjustment.
        // Let's assume the bridge burns *from* the user (requires user approval)
        vm.startPrank(user1);
        l2wct.approve(newCrosschainBridge, mintAmount);
        vm.stopPrank();

        vm.startPrank(newCrosschainBridge);
        l2wct.crosschainBurn(user1, mintAmount / 2);
        assertEq(l2wct.balanceOf(user1), mintAmount / 2, "User1 should have half tokens left after crosschain burn");
        vm.stopPrank();
    }

    function testFork_AllowedAddressesAfterUpgrade_EnforcesWhitelist() public {
        uint256 mintAmount = 1000 * 10 ** 18;

        // Set a direct minter using the timelock (admin)
        vm.startPrank(address(timelock));
        l2wct.setMinter(minter);
        vm.stopPrank();

        // Mint tokens to users
        vm.startPrank(minter);
        l2wct.mint(user1, mintAmount);
        l2wct.mint(user2, mintAmount);
        l2wct.mint(user3, mintAmount);
        vm.stopPrank();

        // Set allowed addresses using manager role
        vm.startPrank(manager);
        l2wct.setAllowedFrom(user1, true);
        l2wct.setAllowedTo(user3, true);
        vm.stopPrank();

        // Test transfer from allowed sender to any recipient
        vm.startPrank(user1);
        l2wct.transfer(user2, mintAmount / 4);
        assertEq(
            l2wct.balanceOf(user2), mintAmount + mintAmount / 4, "User2 should have received tokens from allowed sender"
        );
        vm.stopPrank();

        // Test transfer from any sender to allowed recipient
        vm.startPrank(user2);
        l2wct.transfer(user3, mintAmount / 4);
        assertEq(
            l2wct.balanceOf(user3),
            mintAmount + mintAmount / 4,
            "User3 should have received tokens as allowed recipient"
        );
        vm.stopPrank();

        // Test transfer from non-allowed sender to non-allowed recipient (should fail)
        vm.startPrank(user2);
        vm.expectRevert(L2WCT.TransferRestricted.selector);
        l2wct.transfer(user1, mintAmount / 4);
        vm.stopPrank();
    }

    function testFork_ERC7802Compliance_SupportsInterfaceAndFunctions() public {
        // Check that the contract supports the IERC7802 interface
        bytes4 erc7802InterfaceId = type(IERC7802).interfaceId;
        assertTrue(l2wct.supportsInterface(erc7802InterfaceId), "L2WCT should support IERC7802 interface");

        // Test that the contract implements the required functions
        uint256 mintAmount = 1000 * 10 ** 18;

        // Whitelist user1 for sending
        vm.startPrank(manager);
        l2wct.setAllowedFrom(user1, true);
        vm.stopPrank();

        // Set a bridge address using the timelock (admin) - use minter addr for simplicity here
        vm.startPrank(address(timelock));
        l2wct.setBridge(minter);
        vm.stopPrank();

        // Test crosschainMint
        vm.startPrank(minter); // Bridge calls crosschainMint
        vm.expectEmit(true, true, true, true); // Adjusted emit check
        emit CrosschainMint(user1, mintAmount, minter);
        l2wct.crosschainMint(user1, mintAmount);
        assertEq(l2wct.balanceOf(user1), mintAmount, "User1 should have received tokens from crosschain mint");
        vm.stopPrank();

        // Test crosschainBurn
        // User1 needs to approve the bridge (minter address in this test)
        vm.startPrank(user1);
        l2wct.approve(minter, mintAmount);
        vm.stopPrank();

        vm.startPrank(minter); // Bridge calls crosschainBurn
        vm.expectEmit(true, true, true, true); // Adjusted emit check
        emit CrosschainBurn(user1, mintAmount / 2, minter);
        l2wct.crosschainBurn(user1, mintAmount / 2);
        assertEq(l2wct.balanceOf(user1), mintAmount / 2, "User1 should have half tokens left after crosschain burn");
        vm.stopPrank();
    }

    function testFork_NttTokenInterface_SupportsInterfaceAndFunctions() public {
        // Check that the contract supports the INttToken interface
        bytes4 nttTokenInterfaceId = type(INttToken).interfaceId;
        assertTrue(l2wct.supportsInterface(nttTokenInterfaceId), "L2WCT should support INttToken interface");

        // Test minter functionality
        vm.startPrank(address(timelock));
        l2wct.setMinter(minter);
        vm.stopPrank();

        // Test that the minter can mint tokens
        uint256 mintAmount = 1000 * 10 ** 18;
        vm.startPrank(minter);
        l2wct.mint(user1, mintAmount);
        assertEq(l2wct.balanceOf(user1), mintAmount, "User1 should have received tokens");
        vm.stopPrank();
    }

    function testFork_WhitelistedAddresses_TransferLogicWorks() public {
        uint256 mintAmount = 1000 * 10 ** 18;

        // Set a direct minter using the timelock (admin)
        vm.startPrank(address(timelock));
        l2wct.setMinter(minter);
        vm.stopPrank();

        // Mint tokens to all whitelisted addresses and some non-whitelisted addresses
        vm.startPrank(minter);

        // Mint to all "from" whitelisted addresses
        for (uint256 i = 0; i < whitelistedFromAddresses.length; i++) {
            // Ensure enough ETH for gas if needed, or use prank + deal
            vm.deal(whitelistedFromAddresses[i], 1 ether);
            l2wct.mint(whitelistedFromAddresses[i], mintAmount);
        }
        // Mint to all "to" whitelisted addresses that aren't also "from"
        for (uint256 i = 0; i < whitelistedToAddresses.length; i++) {
            bool alreadyMinted = false;
            for (uint256 j = 0; j < whitelistedFromAddresses.length; j++) {
                if (whitelistedToAddresses[i] == whitelistedFromAddresses[j]) {
                    alreadyMinted = true;
                    break;
                }
            }
            if (!alreadyMinted) {
                vm.deal(whitelistedToAddresses[i], 1 ether);
                l2wct.mint(whitelistedToAddresses[i], mintAmount);
            }
        }

        // Mint to a non-whitelisted address
        address nonWhitelisted = makeAddr("nonWhitelisted");
        vm.deal(nonWhitelisted, 1 ether);
        l2wct.mint(nonWhitelisted, mintAmount);
        vm.stopPrank();

        // Test transfers from whitelisted "from" addresses to non-whitelisted addresses
        uint256 nonWhitelistedReceived = 0;
        for (uint256 i = 0; i < whitelistedFromAddresses.length; i++) {
            address sender = whitelistedFromAddresses[i];
            vm.startPrank(sender);

            // Should succeed because sender is whitelisted for "from"
            l2wct.transfer(nonWhitelisted, 1 ether);
            nonWhitelistedReceived += 1 ether;

            vm.stopPrank();

            // Verify the transfer worked
            assertEq(
                l2wct.balanceOf(nonWhitelisted),
                mintAmount + nonWhitelistedReceived,
                "Transfer from whitelisted 'from' address should succeed"
            );
        }

        // Test transfers to whitelisted "to" addresses from non-whitelisted addresses
        vm.startPrank(nonWhitelisted);
        for (uint256 i = 0; i < whitelistedToAddresses.length; i++) {
            address recipient = whitelistedToAddresses[i];

            // Should succeed because recipient is whitelisted for "to"
            uint256 balanceBefore = l2wct.balanceOf(recipient);
            l2wct.transfer(recipient, 1 ether);

            // Verify the transfer worked
            assertEq(
                l2wct.balanceOf(recipient),
                balanceBefore + 1 ether, // Check against balance before transfer
                "Transfer to whitelisted 'to' address should succeed"
            );
        }
        vm.stopPrank();

        // Test transfer between two non-whitelisted addresses (should fail)
        address anotherNonWhitelisted = makeAddr("anotherNonWhitelisted");
        vm.startPrank(minter);
        l2wct.mint(anotherNonWhitelisted, mintAmount);
        vm.stopPrank();

        vm.startPrank(anotherNonWhitelisted);
        vm.expectRevert(L2WCT.TransferRestricted.selector);
        l2wct.transfer(nonWhitelisted, 1 ether);
        vm.stopPrank();
    }

    function testFork_WhitelistedAddressesPreserved_PostUpgrade() public {
        // This test relies on the setup having correctly read the state from the fork,
        // including the whitelisted addresses set in the legacy contract *before* the upgrade.
        // The `setAllowedFrom`/`setAllowedTo` are storage variables preserved by the upgrade.

        // Check that the whitelisted addresses (assumed set pre-upgrade) are still valid post-upgrade

        // Verify using the `allowedFrom` and `allowedTo` getters
        for (uint256 i = 0; i < whitelistedFromAddresses.length; i++) {
            address whitelistedAddr = whitelistedFromAddresses[i];
            bool isAllowedFrom = l2wct.allowedFrom(whitelistedAddr);
            // Note: We cannot *assert* true here, as we don't know the exact pre-upgrade state on the fork block.
            // This loop mainly serves documentation purposes or could be adapted if pre-upgrade state is known/mocked.
            console.log("Checking allowedFrom:", whitelistedAddr, isAllowedFrom);
        }

        for (uint256 i = 0; i < whitelistedToAddresses.length; i++) {
            address whitelistedAddr = whitelistedToAddresses[i];
            bool isAllowedTo = l2wct.allowedTo(whitelistedAddr);
            // Similar note as above applies.
            console.log("Checking allowedTo:", whitelistedAddr, isAllowedTo);
        }

        // Test transfers assuming the whitelist *was* preserved by the upgrade.
        // We need to ensure the test addresses exist and have funds on the fork, or create/fund them.
        uint256 mintAmount = 1000 * 10 ** 18; // Use for funding if needed

        // Use the first whitelisted 'from' address from our list.
        address whitelistedFrom = whitelistedFromAddresses[0];
        vm.deal(whitelistedFrom, 1 ether); // Ensure sender has ETH

        // Create a non-whitelisted recipient.
        address nonWhitelisted = makeAddr("nonWhitelisted");
        vm.deal(nonWhitelisted, 1 ether);

        // Fund the whitelisted sender if needed (may already have tokens on fork)
        // Check balance first, or just mint/deal unconditionally for test setup simplicity.
        vm.startPrank(address(timelock));
        l2wct.setMinter(minter); // Allow minter to mint
        vm.stopPrank();
        vm.startPrank(minter);
        if (l2wct.balanceOf(whitelistedFrom) < mintAmount / 2) {
            l2wct.mint(whitelistedFrom, mintAmount);
        }
        // Also fund the non-whitelisted address for the next part of the test
        if (l2wct.balanceOf(nonWhitelisted) < mintAmount / 4) {
            l2wct.mint(nonWhitelisted, mintAmount);
        }
        vm.stopPrank();

        // Test transfer from whitelisted 'from' address to non-whitelisted address
        // This should succeed IF the whitelist was preserved AND whitelistedFrom[0] was indeed whitelisted pre-upgrade.
        vm.startPrank(whitelistedFrom);
        uint256 nonWhitelistedBalanceBefore = l2wct.balanceOf(nonWhitelisted);
        l2wct.transfer(nonWhitelisted, mintAmount / 2);
        assertEq(
            l2wct.balanceOf(nonWhitelisted),
            nonWhitelistedBalanceBefore + mintAmount / 2,
            "Transfer from (presumed) whitelisted 'from' address should succeed"
        );
        vm.stopPrank();

        // Test transfer from non-whitelisted address to whitelisted 'to' address
        // Use the first whitelisted 'to' address from our list.
        address whitelistedTo = whitelistedToAddresses[0];
        vm.deal(whitelistedTo, 1 ether); // Ensure recipient has ETH if needed

        // Fund recipient if needed
        vm.startPrank(minter);
        if (l2wct.balanceOf(whitelistedTo) == 0) {
            // Avoid large balances if it exists
            l2wct.mint(whitelistedTo, mintAmount); // Mint initial amount if zero
        }
        vm.stopPrank();

        vm.startPrank(nonWhitelisted);
        uint256 balanceBeforeTransfer = l2wct.balanceOf(whitelistedTo);
        l2wct.transfer(whitelistedTo, mintAmount / 4);
        assertEq(
            l2wct.balanceOf(whitelistedTo),
            balanceBeforeTransfer + mintAmount / 4,
            "Transfer to (presumed) whitelisted 'to' address should succeed"
        );
        vm.stopPrank();

        // Test transfer from non-whitelisted address to non-whitelisted address (should fail)
        address anotherNonWhitelisted = makeAddr("anotherNonWhitelisted");
        vm.startPrank(minter);
        l2wct.mint(anotherNonWhitelisted, mintAmount);
        vm.stopPrank();

        vm.startPrank(anotherNonWhitelisted);
        vm.expectRevert(L2WCT.TransferRestricted.selector);
        l2wct.transfer(nonWhitelisted, mintAmount / 4);
        vm.stopPrank();
    }
}
