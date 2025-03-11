// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Base_Test } from "test/Base.t.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract WalletConnectConfig_Test is Base_Test {
    // Test addresses
    address constant TEST_CONTRACT = address(0x1234);

    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function testInitialization() public {
        assertTrue(walletConnectConfig.hasRole(walletConnectConfig.DEFAULT_ADMIN_ROLE(), users.admin));
    }

    function testContractUpdates() public {
        vm.startPrank(users.admin);

        // Test L2WCT update
        walletConnectConfig.updateL2wct(TEST_CONTRACT);
        assertEq(walletConnectConfig.getL2wct(), TEST_CONTRACT);
        assertTrue(walletConnectConfig.isWalletConnectContract(TEST_CONTRACT, walletConnectConfig.L2WCT_TOKEN()));

        // Test Pauser update
        walletConnectConfig.updatePauser(TEST_CONTRACT);
        assertEq(walletConnectConfig.getPauser(), TEST_CONTRACT);
        assertTrue(walletConnectConfig.isWalletConnectContract(TEST_CONTRACT, walletConnectConfig.PAUSER()));

        vm.stopPrank();
    }

    function testContractUpdateRevertNotAdmin() public {
        vm.startPrank(users.alice);

        vm.expectRevert(accessControlError(users.alice, walletConnectConfig.DEFAULT_ADMIN_ROLE()));
        walletConnectConfig.updateL2wct(TEST_CONTRACT);

        vm.expectRevert(accessControlError(users.alice, walletConnectConfig.DEFAULT_ADMIN_ROLE()));
        walletConnectConfig.updatePauser(TEST_CONTRACT);

        vm.stopPrank();
    }

    function testContractUpdateRevertZeroAddress() public {
        vm.startPrank(users.admin);

        vm.expectRevert(WalletConnectConfig.InvalidAddress.selector);
        walletConnectConfig.updateL2wct(address(0));

        vm.expectRevert(WalletConnectConfig.InvalidAddress.selector);
        walletConnectConfig.updatePauser(address(0));

        vm.stopPrank();
    }

    function testContractUpdateRevertIdenticalValue() public {
        vm.startPrank(users.admin);

        // First update
        walletConnectConfig.updateL2wct(TEST_CONTRACT);

        // Try to update with same value
        vm.expectRevert(WalletConnectConfig.IdenticalValue.selector);
        walletConnectConfig.updateL2wct(TEST_CONTRACT);

        vm.stopPrank();
    }

    function testContractRecognition() public {
        vm.startPrank(users.admin);

        // Set contract address
        walletConnectConfig.updateL2wct(TEST_CONTRACT);

        // Verify recognition
        assertTrue(walletConnectConfig.isWalletConnectContract(TEST_CONTRACT, walletConnectConfig.L2WCT_TOKEN()));
        assertFalse(walletConnectConfig.isWalletConnectContract(address(0x5678), walletConnectConfig.L2WCT_TOKEN()));

        vm.stopPrank();
    }

    function testAllContractUpdates() public {
        vm.startPrank(users.admin);

        // Test all contract updates
        walletConnectConfig.updatePermissionedNodeRegistry(TEST_CONTRACT);
        assertEq(walletConnectConfig.getPermissionedNodeRegistry(), TEST_CONTRACT);

        walletConnectConfig.updateNodeRewardManager(TEST_CONTRACT);
        assertEq(walletConnectConfig.getNodeRewardManager(), TEST_CONTRACT);

        walletConnectConfig.updateWalletRewardManager(TEST_CONTRACT);
        assertEq(walletConnectConfig.getWalletRewardManager(), TEST_CONTRACT);

        walletConnectConfig.updateStakeWeight(TEST_CONTRACT);
        assertEq(walletConnectConfig.getStakeWeight(), TEST_CONTRACT);

        walletConnectConfig.updateOracle(TEST_CONTRACT);
        assertEq(walletConnectConfig.getOracle(), TEST_CONTRACT);

        vm.stopPrank();
    }

    // Helper for access control error message
    function accessControlError(address account, bytes32 role) internal pure returns (bytes memory) {
        return abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", account, role);
    }
}
