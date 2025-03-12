// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import {
    MerkleVester,
    CalendarUnlockSchedule,
    Allocation,
    CalendarAllocation,
    DistributionState
} from "src/utils/magna/MerkleVester.sol";
import { Merkle } from "test/utils/Merkle.sol";
import { Base_Test } from "test/Base.t.sol";
import { IPostClaimHandler } from "src/utils/magna/MerkleVester.sol";
import { console2 } from "forge-std/console2.sol";

contract MerkleVesterTest is Base_Test {
    Merkle public merkle;
    mapping(string => CalendarUnlockSchedule) public calendarSchedules;

    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
        disableTransferRestrictions();
        IPostClaimHandler postClaimHandler = IPostClaimHandler(address(0));
        vm.prank(users.admin);
        vester.addPostClaimHandlerToWhitelist(postClaimHandler);
        merkle = new Merkle();
    }

    function testSingleAllocation() public {
        // Set the allocation
        uint256 totalAllocation = 1000 * 10 ** 18; // 1000 tokens
        deal(address(l2wct), address(vester), totalAllocation);

        // Create a simple calendar unlock schedule
        uint32[] memory unlockTimestamps = new uint32[](2);
        unlockTimestamps[0] = uint32(block.timestamp + 30 days);
        unlockTimestamps[1] = uint32(block.timestamp + 60 days);

        uint256[] memory unlockPercents = new uint256[](2);
        unlockPercents[0] = 500_000; // 50%
        unlockPercents[1] = 500_000; // 50%

        CalendarUnlockSchedule memory unlockSchedule = CalendarUnlockSchedule({
            unlockScheduleId: "schedule1",
            unlockTimestamps: unlockTimestamps,
            unlockPercents: unlockPercents
        });

        // Create the allocation
        Allocation memory allocation = Allocation({
            id: "allocation1",
            originalBeneficiary: users.alice,
            totalAllocation: totalAllocation,
            cancelable: true,
            revokable: true,
            transferableByAdmin: false,
            transferableByBeneficiary: false
        });

        // Create the leaf hash
        bytes memory decodableArgs = abi.encode("calendar", allocation, unlockSchedule);
        bytes32 leaf = keccak256(decodableArgs);

        // Create a simple Merkle tree with just one leaf
        bytes32[] memory proof = new bytes32[](0);
        bytes32 root = leaf;

        bool isValid = verifyMerkleProof(root, proof, leaf);
        console2.log("Is Merkle proof valid:", isValid);

        // Add the root to the vester
        vm.prank(users.admin);
        vester.addAllocationRoot(root);

        // Test withdrawal
        vm.warp(block.timestamp + 45 days);
        vm.prank(users.alice);
        vester.withdraw(0, 0, decodableArgs, proof);

        assertEq(l2wct.balanceOf(users.alice), totalAllocation / 2);

        // Test getting the allocation data
        Allocation memory gotAllocation = vester.getLeafJustAllocationData(0, decodableArgs, proof);
        assertEq(gotAllocation.id, "allocation1");
        assertEq(gotAllocation.originalBeneficiary, users.alice);
        assertEq(gotAllocation.totalAllocation, totalAllocation);
        assertEq(gotAllocation.cancelable, true);
        assertEq(gotAllocation.revokable, true);
        assertEq(gotAllocation.transferableByAdmin, false);
        assertEq(gotAllocation.transferableByBeneficiary, false);
    }

    function test_MultiAllocationVester() public {
        uint256 amountToFund = 1e27; // 1 billion tokens
        vm.startPrank(users.admin);
        (CalendarAllocation[] memory allocations, bytes32[] memory hashes, bytes32 root) =
            createAllocationsAndMerkleTree("id1", true, true, false, false, amountToFund);
        vester.addAllocationRoot(root);
        deal(address(l2wct), address(vester), amountToFund);
        vm.stopPrank();

        vm.startPrank(users.alice);
        bytes memory decodableArgs = abi.encode("calendar", allocations[0].allocation, calendarSchedules["id1"]);
        bytes32[] memory proof = merkle.getProof(hashes, 0);

        skip(30 days);

        vester.withdraw(amountToFund / 8, 0, decodableArgs, proof);

        assertEq(l2wct.balanceOf(users.alice), amountToFund / 8);
        (CalendarAllocation memory leafAlloc,) = vester.getCalendarLeafAllocationData(0, decodableArgs, proof);
        assertEq(leafAlloc.distributionState.withdrawn, amountToFund / 8);
        vm.stopPrank();
    }

    function createAllocationsAndMerkleTree(
        string memory id,
        bool cancelable,
        bool revokable,
        bool transferableByAdmin,
        bool transferableByBeneficiary,
        uint256 fundedAmount
    )
        internal
        returns (CalendarAllocation[] memory allocations, bytes32[] memory hashes, bytes32 root)
    {
        allocations = new CalendarAllocation[](2);
        allocations[0] = createAllocation(
            "alloc1",
            users.alice,
            fundedAmount / 2,
            id,
            cancelable,
            revokable,
            transferableByAdmin,
            transferableByBeneficiary
        );
        allocations[1] = createAllocation(
            "alloc2",
            users.bob,
            fundedAmount / 2,
            id,
            cancelable,
            revokable,
            transferableByAdmin,
            transferableByBeneficiary
        );

        createUnlockSchedule(id);
        hashes = createHashes(allocations);
        root = merkle.getRoot(hashes);
    }

    function createAllocation(
        string memory allocId,
        address beneficiary,
        uint256 amount,
        string memory scheduleId,
        bool cancelable,
        bool revokable,
        bool transferableByAdmin,
        bool transferableByBeneficiary
    )
        internal
        pure
        returns (CalendarAllocation memory)
    {
        return CalendarAllocation(
            Allocation(
                allocId, beneficiary, amount, cancelable, revokable, transferableByAdmin, transferableByBeneficiary
            ),
            scheduleId,
            DistributionState(beneficiary, 0, 0, 0, 0, 0)
        );
    }

    function createUnlockSchedule(string memory id) internal {
        uint32[] memory unlockTimestamps = new uint32[](4);
        uint256[] memory unlockPercents = new uint256[](4);
        uint256 fraction = 250_000; // 25% each time
        for (uint256 i = 0; i < 4; i++) {
            unlockTimestamps[i] = uint32(block.timestamp + (i + 1) * 30 days);
            unlockPercents[i] = fraction;
        }
        calendarSchedules[id] = CalendarUnlockSchedule(id, unlockTimestamps, unlockPercents);
    }

    function createHashes(CalendarAllocation[] memory allocations) internal view returns (bytes32[] memory hashes) {
        hashes = new bytes32[](allocations.length);
        for (uint256 i = 0; i < allocations.length; i++) {
            hashes[i] = vester.getCalendarLeafHash(
                "calendar", allocations[i].allocation, calendarSchedules[allocations[i].calendarUnlockScheduleId]
            );
        }
    }

    function verifyMerkleProof(bytes32 root, bytes32[] memory proof, bytes32 leaf) public view returns (bool) {
        return merkle.verifyProof(root, proof, leaf);
    }
}
