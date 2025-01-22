// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Base_Test } from "test/Base.t.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { L2WCT } from "src/L2WCT.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { OptimismDeployments } from "script/Base.s.sol";
import { OptimismDeploy } from "script/deploy/OptimismDeploy.s.sol";

contract StakeUpgrades_ForkTest is Base_Test {
    uint256 public constant YEAR = 365 days;
    TimelockController public timelock;

    address public admin;

    function setUp() public override {
        vm.createSelectFork("optimism", 130_432_882);

        // Read deployments and params from deployment scripts
        OptimismDeployments memory deps = new OptimismDeploy().readOptimismDeployments(block.chainid);
        timelock = TimelockController(payable(deps.adminTimelock));
        admin = vm.envAddress("ADMIN_ADDRESS");

        stakingRewardDistributor = StakingRewardDistributor(address(deps.stakingRewardDistributor));
        stakeWeight = StakeWeight(address(deps.stakeWeight));
        l2wct = L2WCT(address(deps.l2wct));

        super.setUp();
    }

    function testTransferabilityRestrictions() public {
        // Warp to specific timestamp
        vm.warp(1_736_951_852);

        // Execute batch on timelock
        address[] memory targets = new address[](2);
        targets[0] = 0x28672bf553c6AB214985868f68A3a491E227aCcB;
        targets[1] = 0x9898b105fe3679f2d31c3A06B58757D913D88e5F;

        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = 0;

        bytes[] memory payloads = new bytes[](2);
        payloads[0] =
            hex"9623609d000000000000000000000000f368f535e329c6d08dff0d4b2da961c4e7f3fcaf000000000000000000000000f6d23184e44f282883c0d145c973442fc7a33ab800000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000";
        payloads[1] =
            hex"9623609d000000000000000000000000521b4c065bbdbe3e20b3727340730936912dfa46000000000000000000000000c746f9a45a06cbf2ad761442821c91a479151cc300000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000";

        bytes32 predecessor = bytes32(0);
        bytes32 salt = bytes32(0);

        vm.prank(admin);
        timelock.executeBatch(targets, values, payloads, predecessor, salt);

        // Test StakeWeight depositFor with transfer restrictions
        address testUser = makeAddr("testUser");
        deal(address(l2wct), testUser, 1000e18);

        vm.startPrank(testUser);
        l2wct.approve(address(stakeWeight), 1000e18);

        // Create initial lock
        stakeWeight.createLock(100e18, block.timestamp + YEAR);

        // Should revert due to transfer restrictions
        vm.expectRevert(StakeWeight.TransferRestrictionsEnabled.selector);
        stakeWeight.depositFor(testUser, 100e18);

        // Test StakingRewardDistributor setRecipient
        address recipient = makeAddr("recipient");
        vm.expectRevert(StakingRewardDistributor.TransferRestrictionsEnabled.selector);
        stakingRewardDistributor.setRecipient(recipient);

        // Test StakingRewardDistributor claimTo
        vm.expectRevert(StakingRewardDistributor.TransferRestrictionsEnabled.selector);
        stakingRewardDistributor.claimTo(recipient);
        vm.stopPrank();

        // Disable transfer restrictions
        vm.prank(address(timelock));
        l2wct.disableTransferRestrictions();

        // Try operations again after disabling restrictions
        vm.startPrank(testUser);

        // Should succeed now
        stakeWeight.depositFor(testUser, 100e18);
        stakingRewardDistributor.setRecipient(recipient);
        stakingRewardDistributor.claimTo(recipient);
        vm.stopPrank();
    }
}
