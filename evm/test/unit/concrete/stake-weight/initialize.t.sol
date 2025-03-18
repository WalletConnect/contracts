// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Base_Test } from "test/Base.t.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract Initialize_StakeWeight_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function test_WhenInitializedWithValidInputs() public view {
        // Check that the admin is set correctly
        assertTrue(stakeWeight.hasRole(stakeWeight.DEFAULT_ADMIN_ROLE(), users.admin));

        // Check that the config is set correctly
        assertEq(address(stakeWeight.config()), address(walletConnectConfig));

        // Check that the initial point history is set correctly
        StakeWeight.Point memory point = stakeWeight.pointHistory(0);
        assertEq(point.bias, 0);
        assertEq(point.slope, 0);
        assertEq(point.timestamp, block.timestamp);
        assertEq(point.blockNumber, block.number);

        // Check that the epoch is initialized to 0
        assertEq(stakeWeight.epoch(), 0);

        // Verify initial supply is 0
        assertEq(stakeWeight.supply(), 0);

        // Verify constants
        assertEq(stakeWeight.maxLock(), 105 weeks - 1);
        assertEq(stakeWeight.MULTIPLIER(), 1e18);
    }

    function test_RevertsWhen_ZeroConfigAddress() public {
        StakeWeight implementation = new StakeWeight();

        vm.expectRevert(abi.encodeWithSelector(StakeWeight.InvalidAddress.selector, address(0)));
        new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                StakeWeight.initialize.selector, StakeWeight.Init({ admin: users.admin, config: address(0) })
            )
        );
    }

    function test_RevertsWhen_ZeroAdminAddress() public {
        StakeWeight implementation = new StakeWeight();

        vm.expectRevert(abi.encodeWithSelector(StakeWeight.InvalidAddress.selector, address(0)));
        new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                StakeWeight.initialize.selector,
                StakeWeight.Init({ admin: address(0), config: address(walletConnectConfig) })
            )
        );
    }

    function test_RevertsWhen_InitializedTwice() public {
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        stakeWeight.initialize(StakeWeight.Init({ admin: users.admin, config: address(walletConnectConfig) }));
    }
}
