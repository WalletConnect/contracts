// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { LockedTokenStaker } from "src/LockedTokenStaker.sol";
import { console2 } from "forge-std/console2.sol";
import { Integration_Test } from "../Integration.t.sol";
import { MerkleVester, IMerkleVester } from "src/interfaces/MerkleVester.sol";
import { CalendarUnlockSchedule, Allocation } from "src/interfaces/MerkleVester.sol";
import { Merkle } from "test/utils/Merkle.sol";

/// @notice Common logic needed by all LockedTokenStaker integration tests, both concrete and fuzz tests.
abstract contract LockedTokenStaker_Integration_Shared_Test is Integration_Test {
    Merkle public merkle;
    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        super.setUp();

        lockedTokenStaker =
            new LockedTokenStaker({ vesterContract_: IMerkleVester(address(vester)), config_: walletConnectConfig });

        disableTransferRestrictions();

        merkle = new Merkle();

        bytes32 role = stakeWeight.LOCKED_TOKEN_STAKER_ROLE();
        vm.prank(users.admin);
        stakeWeight.grantRole(role, address(lockedTokenStaker));
    }

    function _createAllocation(
        address beneficiary,
        uint256 amount
    )
        internal
        returns (bytes memory decodableArgs, bytes32[] memory proof)
    {
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
            originalBeneficiary: beneficiary,
            totalAllocation: amount,
            cancelable: true,
            revokable: true,
            transferableByAdmin: false,
            transferableByBeneficiary: false
        });

        // Create the leaf hash
        decodableArgs = abi.encode("calendar", allocation, unlockSchedule);
        bytes32 leaf = keccak256(decodableArgs);

        // Create a simple Merkle tree with just one leaf
        proof = new bytes32[](0);
        bytes32 root = leaf;

        // Add the root to the vester
        vm.prank(users.admin);
        vester.addAllocationRoot(root);

        // Fund the vester
        deal(address(l2wct), address(vester), amount);

        // Return the decodable args and proof for later use
        return (decodableArgs, proof);
    }

    function _createLockForUser(
        address user,
        uint256 amount,
        uint256 _lockTime,
        bytes memory decodableArgs,
        bytes32[] memory proof
    )
        internal
    {
        deal(address(l2wct), user, amount);
        vm.startPrank(user);
        l2wct.approve(address(lockedTokenStaker), amount);
        lockedTokenStaker.createLockFor(user, amount, _lockTime, 0, decodableArgs, proof);
        vm.stopPrank();
    }

    function _increaseLockAmountForUser(
        address user,
        uint256 amount,
        bytes memory decodableArgs,
        bytes32[] memory proof
    )
        internal
    {
        vm.startPrank(user);
        l2wct.approve(address(lockedTokenStaker), amount);
        lockedTokenStaker.increaseLockAmountFor(user, amount, 0, decodableArgs, proof);
        vm.stopPrank();
    }

    function _pause() internal {
        vm.prank(users.pauser);
        pauser.setIsLockedTokenStakerPaused(true);
    }
}
