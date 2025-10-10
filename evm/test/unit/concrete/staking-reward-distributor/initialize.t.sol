// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Base_Test } from "test/Base.t.sol";
import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Initialize_StakingRewardDistributor_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function test_WhenInitializedWithValidInputs() public {
        uint256 startTime = block.timestamp;
        StakingRewardDistributor implementation = new StakingRewardDistributor();
        StakingRewardDistributor.Init memory init = StakingRewardDistributor.Init({
            admin: users.admin,
            startTime: startTime,
            emergencyReturn: users.emergencyHolder,
            config: address(walletConnectConfig)
        });

        stakingRewardDistributor = StakingRewardDistributor(
            address(
                new ERC1967Proxy(
                    address(implementation), abi.encodeWithSelector(StakingRewardDistributor.initialize.selector, init)
                )
            )
        );

        // Check that the DEFAULT_ADMIN_ROLE is granted correctly
        bytes32 DEFAULT_ADMIN_ROLE = 0x00;
        assertTrue(stakingRewardDistributor.hasRole(DEFAULT_ADMIN_ROLE, users.admin));

        // Check that the start time is set correctly
        assertEq(stakingRewardDistributor.startWeekCursor(), (startTime / 1 weeks) * 1 weeks);

        // Check that the emergency return address is set correctly
        assertEq(stakingRewardDistributor.emergencyReturn(), users.emergencyHolder);

        // Check that the config is set correctly
        assertEq(address(stakingRewardDistributor.config()), address(walletConnectConfig));

        // Check that the lastTokenTimestamp is set correctly
        assertEq(stakingRewardDistributor.lastTokenTimestamp(), (startTime / 1 weeks) * 1 weeks);

        // Check that the weekCursor is set correctly
        assertEq(stakingRewardDistributor.weekCursor(), (startTime / 1 weeks) * 1 weeks);

        // Check that the contract is not killed
        assertEq(stakingRewardDistributor.isKilled(), false);

        // Check that the totalDistributed is 0
        assertEq(stakingRewardDistributor.totalDistributed(), 0);
    }

    function test_RevertsWhen_ZeroAdminAddress() public {
        uint256 startTime = block.timestamp;
        StakingRewardDistributor implementation = new StakingRewardDistributor();
        StakingRewardDistributor.Init memory init = StakingRewardDistributor.Init({
            admin: address(0),
            startTime: startTime,
            emergencyReturn: users.emergencyHolder,
            config: address(walletConnectConfig)
        });

        vm.expectRevert(StakingRewardDistributor.InvalidAdmin.selector);
        new ERC1967Proxy(
            address(implementation), abi.encodeWithSelector(StakingRewardDistributor.initialize.selector, init)
        );
    }

    function test_RevertsWhen_ZeroConfigAddress() public {
        uint256 startTime = block.timestamp;
        StakingRewardDistributor implementation = new StakingRewardDistributor();
        StakingRewardDistributor.Init memory init = StakingRewardDistributor.Init({
            admin: users.admin,
            startTime: startTime,
            emergencyReturn: users.emergencyHolder,
            config: address(0)
        });

        vm.expectRevert(StakingRewardDistributor.InvalidConfig.selector);
        new ERC1967Proxy(
            address(implementation), abi.encodeWithSelector(StakingRewardDistributor.initialize.selector, init)
        );
    }

    function test_RevertsWhen_ZeroEmergencyReturnAddress() public {
        uint256 startTime = block.timestamp;
        StakingRewardDistributor implementation = new StakingRewardDistributor();
        StakingRewardDistributor.Init memory init = StakingRewardDistributor.Init({
            admin: users.admin,
            startTime: startTime,
            emergencyReturn: address(0),
            config: address(walletConnectConfig)
        });

        vm.expectRevert(StakingRewardDistributor.InvalidEmergencyReturn.selector);
        new ERC1967Proxy(
            address(implementation), abi.encodeWithSelector(StakingRewardDistributor.initialize.selector, init)
        );
    }

    function test_RevertsWhen_InitializedTwice() public {
        uint256 startTime = block.timestamp;
        StakingRewardDistributor implementation = new StakingRewardDistributor();
        StakingRewardDistributor.Init memory init = StakingRewardDistributor.Init({
            admin: users.admin,
            startTime: startTime,
            emergencyReturn: users.emergencyHolder,
            config: address(walletConnectConfig)
        });

        stakingRewardDistributor = StakingRewardDistributor(
            address(
                new ERC1967Proxy(
                    address(implementation), abi.encodeWithSelector(StakingRewardDistributor.initialize.selector, init)
                )
            )
        );

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        stakingRewardDistributor.initialize(init);
    }
}
