// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { BRR } from "src/BRR.sol";
import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { L2BRR } from "src/L2BRR.sol";
import { MockBridge } from "test/mocks/MockBridge.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Base_Test } from "test/Base.t.sol";

contract Constructor_L2BRR_Unit_Concrete_Test is Base_Test {
    address public initialOwner;
    address public remoteToken;
    string public name;
    string public symbol;

    function setUp() public override {
        super.setUp();

        // New Config
        vm.startPrank(users.admin);

        // Deploy BRR as a proxy
        BRR.Init memory brrInit = BRR.Init({ initialOwner: users.admin });

        brr = BRR(
            UnsafeUpgrades.deployTransparentProxy(
                address(new BRR()), users.admin, abi.encodeCall(BRR.initialize, (brrInit))
            )
        );

        // New L2BRR
        initialOwner = users.admin;
        remoteToken = address(brr);
        name = "Brownie";
        symbol = "BRR";

        l2brr = new L2BRR(initialOwner, BRIDGE_ADDRESS, remoteToken);

        deployMockBridge();

        vm.stopPrank();
    }

    function test_revertWhen_RemoteTokenIsZero() public {
        vm.expectRevert(L2BRR.InvalidAddress.selector);
        new L2BRR(initialOwner, address(mockBridge), address(0));
    }

    function test_revertWhen_BridgeIsZero() public {
        vm.expectRevert(L2BRR.InvalidAddress.selector);
        new L2BRR(initialOwner, address(0), remoteToken);
    }

    function test_revertWhen_InitialOwnerIsZero() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new L2BRR(address(0), address(mockBridge), remoteToken);
    }

    function test_constructor() public view {
        assertEq(l2brr.owner(), initialOwner);
        assertEq(l2brr.BRIDGE(), address(mockBridge));
        assertEq(l2brr.REMOTE_TOKEN(), remoteToken);
        assertEq(l2brr.name(), name);
        assertEq(l2brr.symbol(), symbol);
        assertEq(l2brr.transferRestrictionsDisabledAfter(), type(uint256).max);
    }
}
