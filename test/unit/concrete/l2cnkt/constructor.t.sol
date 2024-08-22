// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { CNKT } from "src/CNKT.sol";
import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { L2CNKT } from "src/L2CNKT.sol";
import { MockBridge } from "test/mocks/MockBridge.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Base_Test } from "test/Base.t.sol";

contract Constructor_L2CNKT_Unit_Concrete_Test is Base_Test {
    address public remoteToken;
    string public name;
    string public symbol;

    function setUp() public override {
        super.setUp();

        // New Config
        vm.startPrank(users.admin);

        // Deploy CNKT as a proxy
        CNKT.Init memory cnktInit = CNKT.Init({ initialOwner: users.admin });

        cnkt = CNKT(
            UnsafeUpgrades.deployTransparentProxy(
                address(new CNKT()), users.admin, abi.encodeCall(CNKT.initialize, (cnktInit))
            )
        );

        // New L2CNKT
        remoteToken = address(cnkt);
        name = "WalletConnect";
        symbol = "CNKT";

        deployMockBridge();

        l2cnkt = new L2CNKT(users.admin, users.manager, address(mockBridge), remoteToken);

        vm.stopPrank();
    }

    function test_revertWhen_RemoteTokenIsZero() public {
        vm.expectRevert(L2CNKT.InvalidAddress.selector);
        new L2CNKT(users.admin, users.manager, address(mockBridge), address(0));
    }

    function test_revertWhen_BridgeIsZero() public {
        vm.expectRevert(L2CNKT.InvalidAddress.selector);
        new L2CNKT(users.admin, users.manager, address(0), remoteToken);
    }

    function test_revertWhen_InitialAdminIsZero() public {
        vm.expectRevert(L2CNKT.InvalidAddress.selector);
        new L2CNKT(address(0), users.manager, address(mockBridge), remoteToken);
    }

    function test_revertWhen_InitialManagerIsZero() public {
        vm.expectRevert(L2CNKT.InvalidAddress.selector);
        new L2CNKT(users.admin, address(0), address(mockBridge), remoteToken);
    }

    function test_constructor() public view {
        assertTrue(l2cnkt.hasRole(l2cnkt.DEFAULT_ADMIN_ROLE(), users.admin));
        assertTrue(l2cnkt.hasRole(l2cnkt.MANAGER_ROLE(), users.manager));
        assertEq(l2cnkt.BRIDGE(), address(mockBridge));
        assertEq(l2cnkt.REMOTE_TOKEN(), remoteToken);
        assertEq(l2cnkt.name(), name);
        assertEq(l2cnkt.symbol(), symbol);
        assertEq(l2cnkt.transferRestrictionsDisabledAfter(), type(uint256).max);
    }
}
