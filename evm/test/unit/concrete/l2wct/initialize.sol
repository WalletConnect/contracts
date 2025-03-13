// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { WCT } from "src/WCT.sol";
import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { L2WCT } from "src/L2WCT.sol";
import { MockBridge } from "test/mocks/MockBridge.sol";
import { Base_Test } from "test/Base.t.sol";

contract Initialize_L2WCT_Unit_Concrete_Test is Base_Test {
    address public remoteToken;
    string public name;
    string public symbol;

    function setUp() public override {
        super.setUp();

        // New Config
        vm.startPrank(users.admin);

        // Deploy WCT as a proxy
        WCT.Init memory wctInit = WCT.Init({ initialOwner: users.admin, initialMinter: address(nttManager) });

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

        l2wct = L2WCT(UnsafeUpgrades.deployTransparentProxy(address(new L2WCT()), users.admin, ""));

        vm.stopPrank();
    }

    function test_revertWhen_InitialAdminIsZero() public {
        L2WCT.Init memory init = L2WCT.Init({
            initialAdmin: address(0),
            initialManager: users.manager,
            initialMinter: address(nttManager),
            initialBridge: address(mockBridge)
        });
        vm.expectRevert(L2WCT.InvalidAddress.selector);
        l2wct.initialize(init);
    }

    function test_revertWhen_InitialManagerIsZero() public {
        L2WCT.Init memory init = L2WCT.Init({
            initialAdmin: users.admin,
            initialManager: address(0),
            initialMinter: address(nttManager),
            initialBridge: address(mockBridge)
        });
        vm.expectRevert(L2WCT.InvalidAddress.selector);
        l2wct.initialize(init);
    }

    // TODO: Bridge0 is allowed
    // TODO: Minter0 is allowed

    function test_initialize() public {
        L2WCT.Init memory init = L2WCT.Init({
            initialAdmin: users.admin,
            initialManager: users.manager,
            initialMinter: address(nttManager),
            initialBridge: address(mockBridge)
        });

        l2wct.initialize(init);

        assertTrue(l2wct.hasRole(l2wct.DEFAULT_ADMIN_ROLE(), users.admin));
        assertTrue(l2wct.hasRole(l2wct.MANAGER_ROLE(), users.manager));
        assertEq(l2wct.minter(), address(nttManager));
        assertEq(l2wct.crosschainBridge(), address(mockBridge));
        assertEq(l2wct.name(), name);
        assertEq(l2wct.symbol(), symbol);
        assertEq(l2wct.transferRestrictionsDisabledAfter(), type(uint256).max);
    }
}
