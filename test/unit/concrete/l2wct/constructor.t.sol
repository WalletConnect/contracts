// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { WCT } from "src/WCT.sol";
import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { L2WCT } from "src/L2WCT.sol";
import { MockBridge } from "test/mocks/MockBridge.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Base_Test } from "test/Base.t.sol";

contract Constructor_L2WCT_Unit_Concrete_Test is Base_Test {
    address public remoteToken;
    string public name;
    string public symbol;

    function setUp() public override {
        super.setUp();

        // New Config
        vm.startPrank(users.admin);

        // Deploy WCT as a proxy
        WCT.Init memory wctInit = WCT.Init({ initialOwner: users.admin });

        wct = WCT(
            UnsafeUpgrades.deployTransparentProxy(
                address(new WCT()), users.admin, abi.encodeCall(WCT.initialize, (wctInit))
            )
        );

        // New L2WCT
        remoteToken = address(wct);
        name = "WalletConnect";
        symbol = "WCT";

        deployMockBridge();

        l2wct = new L2WCT(users.admin, users.manager, address(mockBridge), remoteToken);

        vm.stopPrank();
    }

    function test_revertWhen_RemoteTokenIsZero() public {
        vm.expectRevert(L2WCT.InvalidAddress.selector);
        new L2WCT(users.admin, users.manager, address(mockBridge), address(0));
    }

    function test_revertWhen_BridgeIsZero() public {
        vm.expectRevert(L2WCT.InvalidAddress.selector);
        new L2WCT(users.admin, users.manager, address(0), remoteToken);
    }

    function test_revertWhen_InitialAdminIsZero() public {
        vm.expectRevert(L2WCT.InvalidAddress.selector);
        new L2WCT(address(0), users.manager, address(mockBridge), remoteToken);
    }

    function test_revertWhen_InitialManagerIsZero() public {
        vm.expectRevert(L2WCT.InvalidAddress.selector);
        new L2WCT(users.admin, address(0), address(mockBridge), remoteToken);
    }

    function test_constructor() public view {
        assertTrue(l2wct.hasRole(l2wct.DEFAULT_ADMIN_ROLE(), users.admin));
        assertTrue(l2wct.hasRole(l2wct.MANAGER_ROLE(), users.manager));
        assertEq(l2wct.BRIDGE(), address(mockBridge));
        assertEq(l2wct.REMOTE_TOKEN(), remoteToken);
        assertEq(l2wct.name(), name);
        assertEq(l2wct.symbol(), symbol);
        assertEq(l2wct.transferRestrictionsDisabledAfter(), type(uint256).max);
    }
}
