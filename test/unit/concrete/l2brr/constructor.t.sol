// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { L2BRR } from "src/L2BRR.sol";
import { BakersSyndicateConfig } from "src/BakersSyndicateConfig.sol";
import { MockBridge } from "test/mocks/MockBridge.sol";
import { BRR } from "src/BRR.sol";
import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
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
        bakersSyndicateConfig = BakersSyndicateConfig(
            UnsafeUpgrades.deployTransparentProxy(
                address(new BakersSyndicateConfig()),
                users.admin,
                abi.encodeCall(BakersSyndicateConfig.initialize, (BakersSyndicateConfig.Init({ admin: users.admin })))
            )
        );
        mockBridge = new MockBridge(bakersSyndicateConfig);
        // Deploy BRR as a proxy
        BRR.Init memory brrInit = BRR.Init({ initialOwner: users.admin });
        brr = BRR(
            UnsafeUpgrades.deployTransparentProxy(
                address(new BRR()), users.admin, abi.encodeCall(BRR.initialize, (brrInit))
            )
        );
        // Update config
        bakersSyndicateConfig.updateBrr(address(brr));

        // New L2BRR
        initialOwner = users.admin;
        remoteToken = address(brr);
        name = "Brownie";
        symbol = "BRR";

        l2brr = new L2BRR(initialOwner, address(mockBridge), remoteToken);

        bakersSyndicateConfig.updateL2brr(address(l2brr));
        vm.stopPrank();
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
