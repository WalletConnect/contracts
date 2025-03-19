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
import { NttManager, IManagerBase, Implementation } from "src/utils/wormhole/NttManagerFlat.sol";
import { console } from "forge-std/console.sol";
import { IERC7802 } from "src/interfaces/IERC7802.sol";
import { INttToken } from "src/interfaces/INttToken.sol";

contract L2WCTNttUpgradeAdditional_ForkTest is Base_Test {
    uint256 public constant YEAR = 365 days;
    TimelockController public timelock;
    NttManager public wormholeNttManager;
    address public admin;
    address public manager;
    address public minter;
    address public user1;
    address public user2;
    address public user3;
    ProxyAdmin public proxyAdmin;
    address public bridge;

    // Whitelisted addresses from the provided list
    address[] public whitelistedFromAddresses;
    address[] public whitelistedToAddresses;

    function setUp() public override {
        // Fork Optimism mainnet at the specified block
        vm.createSelectFork("optimism", 133_119_400);

        // Read deployments and params from deployment scripts
        OptimismDeployments memory deps = new OptimismDeploy().readOptimismDeployments(block.chainid);

        // Label all deployments from deps for better debug logs
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
        l2wct = L2WCT(address(deps.l2wct));

        // Get the proxy admin for upgrading
        address proxyAdminAddress = Eip1967Logger.getAdmin(vm, address(l2wct));
        proxyAdmin = ProxyAdmin(proxyAdminAddress);

        // Deploy the new L2WCT implementation
        L2WCT newImpl = new L2WCT();

        // Upgrade the proxy to the new implementation
        // We need to use the actual admin of the proxy, which is the timelock
        vm.startPrank(address(timelock));
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(l2wct))),
            address(newImpl),
            "" // No initialization data needed
        );
        vm.stopPrank();

        // Deploy the NttManager
        wormholeNttManager = new NttManager(
            address(l2wct), // token
            IManagerBase.Mode.BURNING, // mode
            uint16(block.chainid), // chainId
            365 days, // rateLimitDuration
            false // skipRateLimiting
        );

        // Deploy the NttManager proxy
        nttManager = NttManager(
            address(
                new TransparentUpgradeableProxy(
                    address(wormholeNttManager),
                    address(timelock),
                    abi.encodeWithSelector(Implementation.initialize.selector)
                )
            )
        );

        // Create users
        minter = makeAddr("minter");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        bridge = makeAddr("bridge");

        // Initialize the whitelisted addresses from the provided list
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

    function testLegacyStoragePreservation() public {
        // Test that the legacy storage variables are preserved
        address remoteToken = l2wct.remoteToken();
        address legacyBridge = l2wct.bridge();

        // These should match the values from the legacy contract
        assertEq(l2wct.l1Token(), remoteToken, "l1Token getter should match remoteToken");
        assertEq(l2wct.l2Bridge(), legacyBridge, "l2Bridge getter should match bridge");
    }

    function testNewBridgeFunctionality() public {
        // Set a new bridge using the timelock (admin)
        vm.startPrank(address(timelock));
        l2wct.setBridge(bridge);
        vm.stopPrank();

        // Verify the new bridge is set correctly
        assertEq(l2wct.crosschainBridge(), bridge, "New bridge should be set correctly");

        // Test crosschain mint functionality
        vm.startPrank(bridge);
        uint256 mintAmount = 1000 * 10 ** 18;
        l2wct.crosschainMint(user1, mintAmount);
        assertEq(l2wct.balanceOf(user1), mintAmount, "User1 should have received tokens via crosschain mint");

        // Test crosschain burn functionality
        vm.startPrank(user1);
        l2wct.approve(bridge, mintAmount);
        vm.stopPrank();

        vm.startPrank(bridge);
        l2wct.crosschainBurn(user1, mintAmount / 2);
        assertEq(l2wct.balanceOf(user1), mintAmount / 2, "User1 should have half tokens left after crosschain burn");
        vm.stopPrank();
    }

    function testAllowedAddressesAfterUpgrade() public {
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

    function testDisableTransferRestrictions() public {
        uint256 mintAmount = 1000 * 10 ** 18;

        // Set a direct minter using the timelock (admin)
        vm.startPrank(address(timelock));
        l2wct.setMinter(minter);
        vm.stopPrank();

        // Mint tokens to users
        vm.startPrank(minter);
        l2wct.mint(user1, mintAmount);
        l2wct.mint(user2, mintAmount);
        vm.stopPrank();

        // Disable transfer restrictions
        vm.startPrank(address(timelock));
        l2wct.disableTransferRestrictions();
        vm.stopPrank();

        // Now any transfer should work
        vm.startPrank(user1);
        l2wct.transfer(user2, mintAmount / 2);
        assertEq(
            l2wct.balanceOf(user2),
            mintAmount + mintAmount / 2,
            "User2 should have received tokens after restrictions disabled"
        );
        vm.stopPrank();

        vm.startPrank(user2);
        l2wct.transfer(user1, mintAmount / 4);
        assertEq(
            l2wct.balanceOf(user1),
            mintAmount / 2 + mintAmount / 4,
            "User1 should have received tokens back after restrictions disabled"
        );
        vm.stopPrank();
    }

    function testERC7802Compliance() public {
        // Check that the contract supports the IERC7802 interface
        bytes4 erc7802InterfaceId = type(IERC7802).interfaceId;
        assertTrue(l2wct.supportsInterface(erc7802InterfaceId), "L2WCT should support IERC7802 interface");

        // Test that the contract implements the required functions
        uint256 mintAmount = 1000 * 10 ** 18;

        // Set a direct minter using the timelock (admin)
        vm.startPrank(address(timelock));
        l2wct.setMinter(minter);
        vm.stopPrank();

        // Mint tokens to user1
        vm.startPrank(minter);
        l2wct.mint(user1, mintAmount);
        vm.stopPrank();

        // Test that the token can be burned by the owner
        vm.startPrank(user1);
        l2wct.burn(mintAmount / 2);
        assertEq(l2wct.balanceOf(user1), mintAmount / 2, "User1 should have half tokens left after burning");
        vm.stopPrank();
    }

    function testNttTokenInterface() public {
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

    function testWhitelistedAddresses() public {
        uint256 mintAmount = 1000 * 10 ** 18;

        // Set a direct minter using the timelock (admin)
        vm.startPrank(address(timelock));
        l2wct.setMinter(minter);
        vm.stopPrank();

        // Mint tokens to all whitelisted addresses and some non-whitelisted addresses
        vm.startPrank(minter);

        // Mint to all "from" whitelisted addresses
        for (uint256 i = 0; i < whitelistedFromAddresses.length; i++) {
            l2wct.mint(whitelistedFromAddresses[i], mintAmount);
        }

        // Mint to a non-whitelisted address
        address nonWhitelisted = makeAddr("nonWhitelisted");
        l2wct.mint(nonWhitelisted, mintAmount);
        vm.stopPrank();

        // Test transfers from whitelisted "from" addresses to non-whitelisted addresses
        for (uint256 i = 0; i < whitelistedFromAddresses.length; i++) {
            address sender = whitelistedFromAddresses[i];
            vm.startPrank(sender);

            // Should succeed because sender is whitelisted for "from"
            l2wct.transfer(nonWhitelisted, 1 ether);

            vm.stopPrank();

            // Verify the transfer worked
            assertEq(
                l2wct.balanceOf(nonWhitelisted),
                mintAmount + ((i + 1) * 1 ether),
                "Transfer from whitelisted 'from' address should succeed"
            );
        }

        // Test transfers to whitelisted "to" addresses from non-whitelisted addresses
        vm.startPrank(nonWhitelisted);
        for (uint256 i = 0; i < whitelistedToAddresses.length; i++) {
            address recipient = whitelistedToAddresses[i];

            // Should succeed because recipient is whitelisted for "to"
            l2wct.transfer(recipient, 1 ether);

            // Verify the transfer worked
            assertEq(
                l2wct.balanceOf(recipient), mintAmount + 1 ether, "Transfer to whitelisted 'to' address should succeed"
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

    function testWhitelistedAddressesPreserved() public {
        // Check that the whitelisted addresses from the legacy contract are still valid after upgrade

        // First, verify that the whitelisted addresses are set correctly in the contract
        for (uint256 i = 0; i < whitelistedFromAddresses.length; i++) {
            address whitelistedAddr = whitelistedFromAddresses[i];
            bool isAllowedFrom = l2wct.allowedFrom(whitelistedAddr);
            assertTrue(isAllowedFrom, "Address should be whitelisted for 'from' direction");
        }

        for (uint256 i = 0; i < whitelistedToAddresses.length; i++) {
            address whitelistedAddr = whitelistedToAddresses[i];
            bool isAllowedTo = l2wct.allowedTo(whitelistedAddr);
            assertTrue(isAllowedTo, "Address should be whitelisted for 'to' direction");
        }

        // Now test a few transfers to verify the whitelist is working
        uint256 mintAmount = 1000 * 10 ** 18;

        // Set a direct minter using the timelock (admin)
        vm.startPrank(address(timelock));
        l2wct.setMinter(minter);
        vm.stopPrank();

        // Mint tokens to a whitelisted 'from' address and a non-whitelisted address
        vm.startPrank(minter);
        address whitelistedFrom = whitelistedFromAddresses[0]; // First whitelisted 'from' address
        address nonWhitelisted = makeAddr("nonWhitelisted");
        l2wct.mint(whitelistedFrom, mintAmount);
        l2wct.mint(nonWhitelisted, mintAmount);
        vm.stopPrank();

        // Test transfer from whitelisted 'from' address to non-whitelisted address (should succeed)
        vm.startPrank(whitelistedFrom);
        l2wct.transfer(nonWhitelisted, mintAmount / 2);
        assertEq(
            l2wct.balanceOf(nonWhitelisted),
            mintAmount + mintAmount / 2,
            "Transfer from whitelisted 'from' address should succeed"
        );
        vm.stopPrank();

        // Test transfer from non-whitelisted address to whitelisted 'to' address (should succeed)
        address whitelistedTo = whitelistedToAddresses[0]; // First whitelisted 'to' address
        vm.startPrank(nonWhitelisted);
        l2wct.transfer(whitelistedTo, mintAmount / 4);
        assertEq(l2wct.balanceOf(whitelistedTo), mintAmount / 4, "Transfer to whitelisted 'to' address should succeed");
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
