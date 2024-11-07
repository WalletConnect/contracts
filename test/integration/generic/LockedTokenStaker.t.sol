// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Base_Test } from "test/Base.t.sol";
import { LockedTokenStaker } from "src/LockedTokenStaker.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";
import { MerkleVester, CalendarUnlockSchedule, Allocation, DistributionState } from "src/interfaces/MerkleVester.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Merkle } from "test/utils/Merkle.sol";
import { CalendarAllocation, IPostClaimHandler } from "src/interfaces/MerkleVester.sol";

contract LockedTokenStaker_Test is Base_Test {
    Merkle public merkle;
    mapping(string => CalendarUnlockSchedule) public calendarSchedules;
    IPostClaimHandler public postClaimHandler;

    uint256 constant YEAR = 52 weeks;

    uint256 constant FULL_FUND_AMOUNT = 100e18;

    uint256 constant USER_ALLOCATION_AMOUNT = FULL_FUND_AMOUNT / 2;

    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
        disableTransferRestrictions();

        merkle = new Merkle();

        postClaimHandler = IPostClaimHandler(address(lockedTokenStaker));

        // Set up rewards
        uint256 weeklyRewards = defaults.STAKING_REWARD_RATE() * 7 days;
        deal(address(l2wct), users.admin, weeklyRewards);
        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), type(uint256).max);
        stakingRewardDistributor.injectReward(block.timestamp + 1 weeks, weeklyRewards);
        stakeWeight.grantRole(stakeWeight.LOCKED_TOKEN_STAKER_ROLE(), address(lockedTokenStaker));
        vester.addPostClaimHandlerToWhitelist(postClaimHandler);
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

    // FULLY STAKED SCENARIOS

    function test_FullyStaked_FullyLocked_OngoingStake_StillContributing() public {
        // Setup vester with allocation
        vm.startPrank(users.admin);
        (CalendarAllocation[] memory allocations, bytes32[] memory hashes, bytes32 root) =
            createAllocationsAndMerkleTree("id1", true, true, false, false, FULL_FUND_AMOUNT);
        vester.addAllocationRoot(root);
        deal(address(l2wct), address(vester), FULL_FUND_AMOUNT);
        vm.stopPrank();

        // Get first allocation and create lock
        CalendarAllocation memory allocation = allocations[0];
        bytes32[] memory proof = merkle.getProof(hashes, 0);

        // Create a lock for the full allocation amount
        vm.startPrank(allocation.allocation.originalBeneficiary);
        bytes memory decodableArgs = abi.encode("calendar", allocation.allocation, calendarSchedules["id1"]);
        uint256 allocationAmount = allocation.allocation.totalAllocation;

        lockedTokenStaker.createLockFor(
            allocationAmount,
            block.timestamp + YEAR, // 1 year lock in weeks
            0, // rootIndex
            decodableArgs,
            proof
        );
        vm.stopPrank();

        // Verify state
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(allocation.allocation.originalBeneficiary);
        assertEq(uint256(uint128(lock.amount)), USER_ALLOCATION_AMOUNT, "Incorrect lock amount");
        assertEq(lock.end, _timestampToFloorWeek(block.timestamp + YEAR), "Incorrect lock end time");

        // Since we're fully locked and still contributing:
        // Can't withdraw - lock period not expired
        bool canWithdraw = false;
        _verifyCanWithdraw(
            allocation.allocation.originalBeneficiary, canWithdraw, allocationAmount / 4, decodableArgs, proof
        );
        // Can't transfer - tokens are locked
        bool canTransfer = false;
        _verifyCanTransfer(allocation.allocation.originalBeneficiary, canTransfer);
        // Can't unstake - lock period not expired
        bool canUnstake = false;
        _verifyCanUnstake(allocation.allocation.originalBeneficiary, canUnstake);
        // Can't stake - tokens are locked
        bool canStake = false;
        _verifyCanStake(
            allocation.allocation.originalBeneficiary, canStake, USER_ALLOCATION_AMOUNT, decodableArgs, proof
        );
        // Can claim rewards
        bool canClaimRewards = true;
        // Fast forward some time to accrue rewards
        skip(2 weeks);
        _verifyCanClaimRewards(allocation.allocation.originalBeneficiary, canClaimRewards);

        // Additional assertions to verify the state matches our expectations
        assertTrue(lock.end > block.timestamp, "Lock should be ongoing");
        assertGt(stakeWeight.balanceOf(allocation.allocation.originalBeneficiary), 0, "Incorrect stake balance");
        assertLe(
            stakeWeight.balanceOf(allocation.allocation.originalBeneficiary),
            USER_ALLOCATION_AMOUNT,
            "Incorrect stake balance"
        );
    }

    function test_FullyStaked_FullyLocked_OngoingStake_StoppedContributing() public {
        // Setup vester with allocation
        vm.startPrank(users.admin);
        (CalendarAllocation[] memory allocations, bytes32[] memory hashes, bytes32 root) =
            createAllocationsAndMerkleTree("id1", true, true, false, false, FULL_FUND_AMOUNT);
        vester.addAllocationRoot(root);
        deal(address(l2wct), address(vester), FULL_FUND_AMOUNT);
        vm.stopPrank();

        // Get first allocation and create lock
        CalendarAllocation memory allocation = allocations[0];
        bytes32[] memory proof = merkle.getProof(hashes, 0);

        // Create a lock for the full allocation amount
        vm.startPrank(allocation.allocation.originalBeneficiary);
        bytes memory decodableArgs = abi.encode("calendar", allocation.allocation, calendarSchedules["id1"]);
        uint256 allocationAmount = allocation.allocation.totalAllocation;

        lockedTokenStaker.createLockFor(allocationAmount, block.timestamp + YEAR, 0, decodableArgs, proof);
        vm.stopPrank();

        // Terminate the allocation to simulate "stopped contributing", but we still have the accrued rewards
        skip(2 weeks);
        bool isFullyUnlocked = false;
        _terminate(allocation.allocation.originalBeneficiary, isFullyUnlocked, decodableArgs, proof);

        // Verify state after termination
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(allocation.allocation.originalBeneficiary);
        assertEq(uint256(uint128(lock.amount)), 0, "Incorrect lock amount");
        assertEq(lock.end, 0, "Incorrect lock end time");

        // Since we're fully locked but stopped contributing:
        // Can't withdraw - terminated
        bool canWithdraw = false;
        _verifyCanWithdraw(
            allocation.allocation.originalBeneficiary, canWithdraw, allocationAmount / 4, decodableArgs, proof
        );
        // Can't transfer - tokens are terminated
        bool canTransfer = false;
        _verifyCanTransfer(allocation.allocation.originalBeneficiary, canTransfer);
        // Can't unstake - is terminated
        bool canUnstake = false;
        _verifyCanUnstake(allocation.allocation.originalBeneficiary, canUnstake);
        // Can't stake - is terminated
        bool canStake = false;
        _verifyCanStake(
            allocation.allocation.originalBeneficiary, canStake, USER_ALLOCATION_AMOUNT, decodableArgs, proof
        );
        // Can claim rewards - all the accrued rewards are withdrawn
        bool canClaimRewards = true;
        _verifyCanClaimRewards(allocation.allocation.originalBeneficiary, canClaimRewards);
    }

    function test_FullyStaked_PartiallyUnlocked_OngoingStake_StillContributing() public {
        // Setup vester with allocation
        vm.startPrank(users.admin);
        (CalendarAllocation[] memory allocations, bytes32[] memory hashes, bytes32 root) =
            createAllocationsAndMerkleTree("id1", true, true, false, false, FULL_FUND_AMOUNT);
        vester.addAllocationRoot(root);
        deal(address(l2wct), address(vester), FULL_FUND_AMOUNT);
        vm.stopPrank();

        // Get first allocation and create lock
        CalendarAllocation memory allocation = allocations[0];
        bytes32[] memory proof = merkle.getProof(hashes, 0);

        // Create a lock for the full allocation amount
        vm.startPrank(allocation.allocation.originalBeneficiary);
        bytes memory decodableArgs = abi.encode("calendar", allocation.allocation, calendarSchedules["id1"]);
        uint256 allocationAmount = allocation.allocation.totalAllocation;

        lockedTokenStaker.createLockFor(allocationAmount, block.timestamp + YEAR, 0, decodableArgs, proof);
        vm.stopPrank();

        // Skip time to simulate first unlock
        skip(31 days);

        // Verify state
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(allocation.allocation.originalBeneficiary);
        assertGt(uint256(uint128(lock.amount)), 0, "Lock amount should be positive");
        assertGt(lock.end, block.timestamp, "Lock should not be expired");

        // Since we're partially unlocked but still contributing:
        // Can't withdraw - all tokens are locked
        bool canWithdraw = false;
        _verifyCanWithdraw(
            allocation.allocation.originalBeneficiary, canWithdraw, allocationAmount / 4, decodableArgs, proof
        );
        // Can't transfer - all tokens are staked
        bool canTransfer = false;
        _verifyCanTransfer(allocation.allocation.originalBeneficiary, canTransfer);
        // Can't unstake - lock not expired
        bool canUnstake = false;
        _verifyCanUnstake(allocation.allocation.originalBeneficiary, canUnstake);
        // Can't stake - all tokens are staked
        bool canStake = false;
        _verifyCanStake(
            allocation.allocation.originalBeneficiary, canStake, USER_ALLOCATION_AMOUNT, decodableArgs, proof
        );
        // Can claim rewards - still contributing
        bool canClaimRewards = true;
        // Fast forward some time to accrue rewards
        skip(2 weeks);
        _verifyCanClaimRewards(allocation.allocation.originalBeneficiary, canClaimRewards);
    }

    function test_FullyStaked_PartiallyUnlocked_OngoingStake_StoppedContributing() public {
        // Setup vester with allocation
        vm.startPrank(users.admin);
        (CalendarAllocation[] memory allocations, bytes32[] memory hashes, bytes32 root) =
            createAllocationsAndMerkleTree("id1", true, true, false, false, FULL_FUND_AMOUNT);
        vester.addAllocationRoot(root);
        deal(address(l2wct), address(vester), FULL_FUND_AMOUNT);
        vm.stopPrank();

        // Get first allocation and create lock
        CalendarAllocation memory allocation = allocations[0];
        bytes32[] memory proof = merkle.getProof(hashes, 0);

        // Create a lock for the full allocation amount
        vm.startPrank(allocation.allocation.originalBeneficiary);
        bytes memory decodableArgs = abi.encode("calendar", allocation.allocation, calendarSchedules["id1"]);
        uint256 allocationAmount = allocation.allocation.totalAllocation;

        lockedTokenStaker.createLockFor(allocationAmount, block.timestamp + YEAR, 0, decodableArgs, proof);
        vm.stopPrank();

        // Skip time to simulate first unlock
        skip(31 days);

        // Terminate the allocation to simulate "stopped contributing"
        bool isFullyUnlocked = false;
        _terminate(allocation.allocation.originalBeneficiary, isFullyUnlocked, decodableArgs, proof);

        // Verify state
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(allocation.allocation.originalBeneficiary);
        assertEq(uint256(uint128(lock.amount)), 0, "Incorrect lock amount");
        assertEq(lock.end, 0, "Incorrect lock end time");

        // User can withdraw first 25% of the allocation
        bool canWithdraw = true;
        _verifyCanWithdraw(
            allocation.allocation.originalBeneficiary, canWithdraw, allocationAmount / 4, decodableArgs, proof
        );

        // Since we're partially unlocked but stopped contributing:
        // Can transfer - 25% of the allocation is unlocked
        bool canTransfer = true;
        _verifyCanTransfer(allocation.allocation.originalBeneficiary, canTransfer);
        // Can't unstake - lock not expired
        bool canUnstake = false;
        _verifyCanUnstake(allocation.allocation.originalBeneficiary, canUnstake);
        // Can't stake - termination doesn't allow staking
        bool canStake = false;
        _verifyCanStake(
            allocation.allocation.originalBeneficiary, canStake, USER_ALLOCATION_AMOUNT, decodableArgs, proof
        );
        // Can claim rewards
        bool canClaimRewards = true;
        // Fast forward some time to accrue rewards
        skip(2 weeks);
        _verifyCanClaimRewards(allocation.allocation.originalBeneficiary, canClaimRewards);
    }

    function test_FullyStaked_FullyUnlocked_OngoingStake_StillContributing() public {
        // Setup vester with allocation
        vm.startPrank(users.admin);
        (CalendarAllocation[] memory allocations, bytes32[] memory hashes, bytes32 root) =
            createAllocationsAndMerkleTree("id1", true, true, false, false, FULL_FUND_AMOUNT);
        vester.addAllocationRoot(root);
        deal(address(l2wct), address(vester), FULL_FUND_AMOUNT);
        vm.stopPrank();

        // Get first allocation and create lock
        CalendarAllocation memory allocation = allocations[0];
        bytes32[] memory proof = merkle.getProof(hashes, 0);

        // Create a lock for the full allocation amount
        vm.startPrank(allocation.allocation.originalBeneficiary);
        bytes memory decodableArgs = abi.encode("calendar", allocation.allocation, calendarSchedules["id1"]);
        uint256 allocationAmount = allocation.allocation.totalAllocation;

        lockedTokenStaker.createLockFor(allocationAmount, block.timestamp + YEAR, 0, decodableArgs, proof);
        vm.stopPrank();

        // Skip time to simulate full unlock
        skip(31 days * 4);

        // Verify state
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(allocation.allocation.originalBeneficiary);
        assertEq(uint256(uint128(lock.amount)), USER_ALLOCATION_AMOUNT, "Incorrect lock amount");
        assertGt(lock.end, _timestampToFloorWeek(block.timestamp), "Lock should not be expired");

        // Since we're fully unlocked but still contributing:
        // Can't withdraw - all tokens are staked
        bool canWithdraw = false;
        _verifyCanWithdraw(
            allocation.allocation.originalBeneficiary, canWithdraw, allocationAmount / 4, decodableArgs, proof
        );
        // Can't transfer - all tokens are staked
        bool canTransfer = false;
        _verifyCanTransfer(allocation.allocation.originalBeneficiary, canTransfer);
        // Can't unstake - lock period not expired
        bool canUnstake = false;
        _verifyCanUnstake(allocation.allocation.originalBeneficiary, canUnstake);
        // Can't stake - all tokens are staked
        bool canStake = false;
        _verifyCanStake(
            allocation.allocation.originalBeneficiary, canStake, USER_ALLOCATION_AMOUNT, decodableArgs, proof
        );
        // Can claim rewards
        bool canClaimRewards = true;
        // Fast forward some time to accrue rewards
        skip(2 weeks);
        _verifyCanClaimRewards(allocation.allocation.originalBeneficiary, canClaimRewards);
    }

    function test_FullyStaked_FullyUnlocked_OngoingStake_StoppedContributing() public {
        // Setup vester with allocation
        vm.startPrank(users.admin);
        (CalendarAllocation[] memory allocations, bytes32[] memory hashes, bytes32 root) =
            createAllocationsAndMerkleTree("id1", true, true, false, false, FULL_FUND_AMOUNT);
        vester.addAllocationRoot(root);
        deal(address(l2wct), address(vester), FULL_FUND_AMOUNT);
        vm.stopPrank();

        // Get first allocation and create lock
        CalendarAllocation memory allocation = allocations[0];
        bytes32[] memory proof = merkle.getProof(hashes, 0);

        // Create a lock for the full allocation amount
        vm.startPrank(allocation.allocation.originalBeneficiary);
        bytes memory decodableArgs = abi.encode("calendar", allocation.allocation, calendarSchedules["id1"]);
        uint256 allocationAmount = allocation.allocation.totalAllocation;

        lockedTokenStaker.createLockFor(allocationAmount, block.timestamp + YEAR, 0, decodableArgs, proof);
        vm.stopPrank();

        // Skip time to simulate full unlock
        skip(31 days * 4);

        // Terminate the allocation to simulate "stopped contributing"
        bool isFullyUnlocked = true;
        _terminate(allocation.allocation.originalBeneficiary, isFullyUnlocked, decodableArgs, proof);

        // Verify state
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(allocation.allocation.originalBeneficiary);
        assertEq(uint256(uint128(lock.amount)), 0, "Incorrect lock amount");
        assertEq(lock.end, 0, "Incorrect lock end time");

        // Since we're fully unlocked and stopped contributing:

        // We withdraw all the tokens
        bool canWithdraw = true;
        _verifyCanWithdraw(
            allocation.allocation.originalBeneficiary, canWithdraw, allocationAmount, decodableArgs, proof
        );
        // Can transfer - tokens are unlocked
        bool canTransfer = true;
        _verifyCanTransfer(allocation.allocation.originalBeneficiary, canTransfer);
        // Can't unstake - already terminated
        bool canUnstake = false;
        _verifyCanUnstake(allocation.allocation.originalBeneficiary, canUnstake);
        // Can't stake - termination doesn't allow staking
        bool canStake = false;
        _verifyCanStake(
            allocation.allocation.originalBeneficiary, canStake, USER_ALLOCATION_AMOUNT, decodableArgs, proof
        );
        // Can claim rewards
        bool canClaimRewards = true;
        // Fast forward some time to accrue rewards
        skip(2 weeks);
        _verifyCanClaimRewards(allocation.allocation.originalBeneficiary, canClaimRewards);
    }

    function test_FullyStaked_FullyUnlocked_FinishedStake_StillContributing() public {
        // Setup vester with allocation
        vm.startPrank(users.admin);
        (CalendarAllocation[] memory allocations, bytes32[] memory hashes, bytes32 root) =
            createAllocationsAndMerkleTree("id1", true, true, false, false, FULL_FUND_AMOUNT);
        vester.addAllocationRoot(root);
        deal(address(l2wct), address(vester), FULL_FUND_AMOUNT);
        vm.stopPrank();

        // Get first allocation and create lock
        CalendarAllocation memory allocation = allocations[0];
        bytes32[] memory proof = merkle.getProof(hashes, 0);

        // Create a lock for the full allocation amount
        vm.startPrank(allocation.allocation.originalBeneficiary);
        bytes memory decodableArgs = abi.encode("calendar", allocation.allocation, calendarSchedules["id1"]);
        uint256 allocationAmount = allocation.allocation.totalAllocation;

        lockedTokenStaker.createLockFor(allocationAmount, block.timestamp + YEAR, 0, decodableArgs, proof);
        vm.stopPrank();

        // Skip time to simulate full unlock
        skip(YEAR + 1 weeks);

        // Verify state
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(allocation.allocation.originalBeneficiary);
        assertEq(uint256(uint128(lock.amount)), USER_ALLOCATION_AMOUNT, "Incorrect lock amount");
        assertEq(lock.end, _timestampToFloorWeek(block.timestamp - 1 weeks), "Incorrect lock end time");

        // Since we're fully unlocked but still contributing:

        // We withdraw all the tokens, which sould also trigger an unstake
        bool canWithdraw = true;
        _verifyCanWithdraw(
            allocation.allocation.originalBeneficiary, canWithdraw, allocationAmount, decodableArgs, proof
        );

        // Can transfer - tokens are unlocked
        bool canTransfer = true;
        _verifyCanTransfer(allocation.allocation.originalBeneficiary, canTransfer);
        // Can unstake - already unstaked
        bool canUnstake = false;
        _verifyCanUnstake(allocation.allocation.originalBeneficiary, canUnstake);
        // Can stake - withdrawnAmount == allocationAmount
        bool canStake = false;
        _verifyCanStake(
            allocation.allocation.originalBeneficiary, canStake, USER_ALLOCATION_AMOUNT, decodableArgs, proof
        );
        // Can claim rewards
        bool canClaimRewards = true;
        // Fast forward some time to accrue rewards
        skip(2 weeks);
        _verifyCanClaimRewards(allocation.allocation.originalBeneficiary, canClaimRewards);

        // Additional assertions to verify the state matches our expectations
        assertTrue(lock.end < block.timestamp, "Lock should be finished");
        assertEq(stakeWeight.balanceOf(allocation.allocation.originalBeneficiary), 0, "Incorrect stake balance");
    }

    function test_FullyStaked_FullyUnlocked_FinishedStake_StoppedContributing() public {
        // Setup vester with allocation
        vm.startPrank(users.admin);
        (CalendarAllocation[] memory allocations, bytes32[] memory hashes, bytes32 root) =
            createAllocationsAndMerkleTree("id1", true, true, false, false, FULL_FUND_AMOUNT);
        vester.addAllocationRoot(root);
        deal(address(l2wct), address(vester), FULL_FUND_AMOUNT);
        vm.stopPrank();

        // Get first allocation and create lock
        CalendarAllocation memory allocation = allocations[0];
        bytes32[] memory proof = merkle.getProof(hashes, 0);

        // Create a lock for the full allocation amount
        vm.startPrank(allocation.allocation.originalBeneficiary);
        bytes memory decodableArgs = abi.encode("calendar", allocation.allocation, calendarSchedules["id1"]);
        uint256 allocationAmount = allocation.allocation.totalAllocation;

        lockedTokenStaker.createLockFor(allocationAmount, block.timestamp + YEAR, 0, decodableArgs, proof);
        vm.stopPrank();

        // Skip time to simulate full unlock
        skip(YEAR + 1 weeks);

        // Terminate the allocation to simulate "stopped contributing"
        bool isFullyUnlocked = true;
        _terminate(allocation.allocation.originalBeneficiary, isFullyUnlocked, decodableArgs, proof);

        // Verify state
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(allocation.allocation.originalBeneficiary);
        assertEq(uint256(uint128(lock.amount)), 0, "Incorrect lock amount");
        assertEq(lock.end, 0, "Incorrect lock end time");

        // We withdraw all the tokens
        bool canWithdraw = true;
        _verifyCanWithdraw(
            allocation.allocation.originalBeneficiary, canWithdraw, allocationAmount, decodableArgs, proof
        );

        // Since we're fully unlocked and stopped contributing:
        // Can transfer - tokens are unlocked
        bool canTransfer = true;
        _verifyCanTransfer(allocation.allocation.originalBeneficiary, canTransfer);
        // Can't unstake - already unstaked
        bool canUnstake = false;
        _verifyCanUnstake(allocation.allocation.originalBeneficiary, canUnstake);
        // Can't stake - termination doesn't allow staking
        bool canStake = false;
        _verifyCanStake(
            allocation.allocation.originalBeneficiary, canStake, USER_ALLOCATION_AMOUNT, decodableArgs, proof
        );
        // Can claim rewards
        bool canClaimRewards = true;
        // Fast forward some time to accrue rewards
        skip(2 weeks);
        _verifyCanClaimRewards(allocation.allocation.originalBeneficiary, canClaimRewards);

        // Additional assertions to verify the state matches our expectations
        assertTrue(lock.end == 0, "Lock should be finished");
        assertEq(stakeWeight.balanceOf(allocation.allocation.originalBeneficiary), 0, "Incorrect stake balance");
    }

    // PARTIALLY STAKED SCENARIOS
    function test_PartiallyStaked_FullyLocked_OngoingStake_StillContributing() public {
        // Setup vester with allocation
        vm.startPrank(users.admin);
        (CalendarAllocation[] memory allocations, bytes32[] memory hashes, bytes32 root) =
            createAllocationsAndMerkleTree("id1", true, true, false, false, FULL_FUND_AMOUNT);
        vester.addAllocationRoot(root);
        deal(address(l2wct), address(vester), FULL_FUND_AMOUNT);
        vm.stopPrank();

        // Get first allocation and create lock
        CalendarAllocation memory allocation = allocations[0];
        bytes32[] memory proof = merkle.getProof(hashes, 0);

        // Create a lock for half the allocation amount
        vm.startPrank(allocation.allocation.originalBeneficiary);
        bytes memory decodableArgs = abi.encode("calendar", allocation.allocation, calendarSchedules["id1"]);
        uint256 allocationAmount = allocation.allocation.totalAllocation / 2;

        lockedTokenStaker.createLockFor(allocationAmount, block.timestamp + YEAR, 0, decodableArgs, proof);
        vm.stopPrank();

        // Verify state
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(allocation.allocation.originalBeneficiary);
        assertEq(uint256(uint128(lock.amount)), allocationAmount, "Incorrect lock amount");
        assertEq(lock.end, _timestampToFloorWeek(block.timestamp + YEAR), "Incorrect lock end time");

        // Since we're partially staked, fully locked and still contributing:
        // Can't withdraw - fully locked
        bool canWithdraw = false;
        _verifyCanWithdraw(
            allocation.allocation.originalBeneficiary, canWithdraw, allocationAmount / 4, decodableArgs, proof
        );
        // Can't transfer - tokens are locked
        bool canTransfer = false;
        _verifyCanTransfer(allocation.allocation.originalBeneficiary, canTransfer);
        // Can't unstake - lock period not expired
        bool canUnstake = false;
        _verifyCanUnstake(allocation.allocation.originalBeneficiary, canUnstake);
        // Can stake - half allocation still available
        bool canStake = true;
        _verifyCanStake(allocation.allocation.originalBeneficiary, canStake, allocationAmount, decodableArgs, proof);
        // Can claim rewards
        bool canClaimRewards = true;
        // Fast forward some time to accrue rewards
        skip(2 weeks);
        _verifyCanClaimRewards(allocation.allocation.originalBeneficiary, canClaimRewards);

        // Additional assertions to verify the state matches our expectations
        assertTrue(lock.end > block.timestamp, "Lock should be ongoing");
        assertGt(stakeWeight.balanceOf(allocation.allocation.originalBeneficiary), 0, "Incorrect stake balance");
        assertLt(
            stakeWeight.balanceOf(allocation.allocation.originalBeneficiary),
            USER_ALLOCATION_AMOUNT,
            "Incorrect stake balance"
        );
    }

    function test_PartiallyStaked_FullyLocked_OngoingStake_StoppedContributing() public {
        // Setup vester with allocation
        vm.startPrank(users.admin);
        (CalendarAllocation[] memory allocations, bytes32[] memory hashes, bytes32 root) =
            createAllocationsAndMerkleTree("id1", true, true, false, false, FULL_FUND_AMOUNT);
        vester.addAllocationRoot(root);
        deal(address(l2wct), address(vester), FULL_FUND_AMOUNT);
        vm.stopPrank();

        // Get first allocation and create lock
        CalendarAllocation memory allocation = allocations[0];
        bytes32[] memory proof = merkle.getProof(hashes, 0);

        // Create a lock for half the allocation amount
        vm.startPrank(allocation.allocation.originalBeneficiary);
        bytes memory decodableArgs = abi.encode("calendar", allocation.allocation, calendarSchedules["id1"]);
        uint256 allocationAmount = allocation.allocation.totalAllocation / 2;

        lockedTokenStaker.createLockFor(allocationAmount, block.timestamp + YEAR, 0, decodableArgs, proof);
        vm.stopPrank();

        // Terminate the allocation to simulate "stopped contributing"
        skip(2 weeks);
        bool isFullyUnlocked = false;
        _terminate(allocation.allocation.originalBeneficiary, isFullyUnlocked, decodableArgs, proof);

        // Verify state after termination
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(allocation.allocation.originalBeneficiary);
        assertEq(uint256(uint128(lock.amount)), 0, "Incorrect lock amount");
        assertEq(lock.end, 0, "Incorrect lock end time");

        // Since we're partially staked, fully locked but stopped contributing:
        // Can't withdraw - fully locked
        bool canWithdraw = false;
        _verifyCanWithdraw(
            allocation.allocation.originalBeneficiary, canWithdraw, allocationAmount / 4, decodableArgs, proof
        );
        // Can't transfer - tokens are terminated and locked
        bool canTransfer = false;
        _verifyCanTransfer(allocation.allocation.originalBeneficiary, canTransfer);
        // Can't unstake - is terminated
        bool canUnstake = false;
        _verifyCanUnstake(allocation.allocation.originalBeneficiary, canUnstake);
        // Can't stake - is terminated
        bool canStake = false;
        _verifyCanStake(
            allocation.allocation.originalBeneficiary, canStake, USER_ALLOCATION_AMOUNT, decodableArgs, proof
        );
        // Can claim rewards - all the accrued rewards are withdrawn
        bool canClaimRewards = true;
        _verifyCanClaimRewards(allocation.allocation.originalBeneficiary, canClaimRewards);
    }

    function test_PartiallyStaked_PartiallyUnlocked_OngoingStake_StillContributing() public {
        // Setup vester with allocation
        vm.startPrank(users.admin);
        (CalendarAllocation[] memory allocations, bytes32[] memory hashes, bytes32 root) =
            createAllocationsAndMerkleTree("id1", true, true, false, false, FULL_FUND_AMOUNT);
        vester.addAllocationRoot(root);
        deal(address(l2wct), address(vester), FULL_FUND_AMOUNT);
        vm.stopPrank();

        // Get first allocation and create lock
        CalendarAllocation memory allocation = allocations[0];
        bytes32[] memory proof = merkle.getProof(hashes, 0);

        // Create a lock for half the allocation amount
        vm.startPrank(allocation.allocation.originalBeneficiary);
        bytes memory decodableArgs = abi.encode("calendar", allocation.allocation, calendarSchedules["id1"]);
        uint256 allocationAmount = allocation.allocation.totalAllocation / 2;

        lockedTokenStaker.createLockFor(allocationAmount, block.timestamp + YEAR, 0, decodableArgs, proof);
        vm.stopPrank();

        // Skip time to simulate partial unlock
        skip(31 days * 2);

        // Verify state
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(allocation.allocation.originalBeneficiary);
        assertEq(uint256(uint128(lock.amount)), allocationAmount, "Incorrect lock amount");
        assertGt(lock.end, _timestampToFloorWeek(block.timestamp), "Lock should not be expired");

        // Since we're partially staked, partially unlocked and still contributing:
        // Can withdraw
        bool canWithdraw = true;
        _verifyCanWithdraw(
            allocation.allocation.originalBeneficiary, canWithdraw, allocationAmount / 2, decodableArgs, proof
        );

        // Can transfer - some tokens are unlocked
        bool canTransfer = true;
        _verifyCanTransfer(allocation.allocation.originalBeneficiary, canTransfer);
        // Can't unstake - lock period not expired
        bool canUnstake = false;
        _verifyCanUnstake(allocation.allocation.originalBeneficiary, canUnstake);
        // Can stake - not all tokens are locked
        bool canStake = true;
        _verifyCanStake(allocation.allocation.originalBeneficiary, canStake, allocationAmount / 2, decodableArgs, proof);
        // Can claim rewards
        bool canClaimRewards = true;
        // Fast forward some time to accrue rewards
        skip(2 weeks);
        _verifyCanClaimRewards(allocation.allocation.originalBeneficiary, canClaimRewards);
    }

    function test_PartiallyStaked_PartiallyUnlocked_OngoingStake_StoppedContributing() public {
        // Setup vester with allocation
        vm.startPrank(users.admin);
        (CalendarAllocation[] memory allocations, bytes32[] memory hashes, bytes32 root) =
            createAllocationsAndMerkleTree("id1", true, true, false, false, FULL_FUND_AMOUNT);
        vester.addAllocationRoot(root);
        deal(address(l2wct), address(vester), FULL_FUND_AMOUNT);
        vm.stopPrank();

        // Get first allocation and create lock
        CalendarAllocation memory allocation = allocations[0];
        bytes32[] memory proof = merkle.getProof(hashes, 0);

        // Create a lock for half the allocation amount
        vm.startPrank(allocation.allocation.originalBeneficiary);
        bytes memory decodableArgs = abi.encode("calendar", allocation.allocation, calendarSchedules["id1"]);
        uint256 allocationAmount = allocation.allocation.totalAllocation / 2;

        lockedTokenStaker.createLockFor(allocationAmount, block.timestamp + YEAR, 0, decodableArgs, proof);
        vm.stopPrank();

        // Skip time to simulate partial unlock
        skip(31 days * 2);

        // Terminate the allocation to simulate "stopped contributing"
        bool isFullyUnlocked = false;
        _terminate(allocation.allocation.originalBeneficiary, isFullyUnlocked, decodableArgs, proof);

        // Verify state
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(allocation.allocation.originalBeneficiary);
        assertEq(uint256(uint128(lock.amount)), 0, "Incorrect lock amount");
        assertEq(lock.end, 0, "Incorrect lock end time");

        // Since we're partially staked, partially unlocked and stopped contributing:
        // Can withdraw - terminated allocation allows withdrawal
        bool canWithdraw = true;
        _verifyCanWithdraw(
            allocation.allocation.originalBeneficiary, canWithdraw, allocationAmount, decodableArgs, proof
        );
        // Can transfer - tokens are unlocked after termination
        bool canTransfer = true;
        _verifyCanTransfer(allocation.allocation.originalBeneficiary, canTransfer);
        // Can't unstake - already terminated
        bool canUnstake = false;
        _verifyCanUnstake(allocation.allocation.originalBeneficiary, canUnstake);
        // Can't stake - termination doesn't allow staking
        bool canStake = false;
        _verifyCanStake(allocation.allocation.originalBeneficiary, canStake, allocationAmount, decodableArgs, proof);
        // Can claim rewards - accrued rewards can be claimed
        bool canClaimRewards = true;
        _verifyCanClaimRewards(allocation.allocation.originalBeneficiary, canClaimRewards);
    }

    function test_PartiallyStaked_FullyUnlocked_FinishedStake_StillContributing() public {
        // Setup vester with allocation
        vm.startPrank(users.admin);
        (CalendarAllocation[] memory allocations, bytes32[] memory hashes, bytes32 root) =
            createAllocationsAndMerkleTree("id1", true, true, false, false, FULL_FUND_AMOUNT);
        vester.addAllocationRoot(root);
        deal(address(l2wct), address(vester), FULL_FUND_AMOUNT);
        vm.stopPrank();

        // Get first allocation and create lock
        CalendarAllocation memory allocation = allocations[0];
        bytes32[] memory proof = merkle.getProof(hashes, 0);

        // Create a lock for half the allocation amount
        vm.startPrank(allocation.allocation.originalBeneficiary);
        bytes memory decodableArgs = abi.encode("calendar", allocation.allocation, calendarSchedules["id1"]);
        uint256 allocationAmount = allocation.allocation.totalAllocation / 2;

        lockedTokenStaker.createLockFor(allocationAmount, block.timestamp + YEAR, 0, decodableArgs, proof);
        vm.stopPrank();

        // Skip time to simulate full unlock
        skip(YEAR + 1 weeks);

        // Verify state
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(allocation.allocation.originalBeneficiary);
        assertEq(uint256(uint128(lock.amount)), USER_ALLOCATION_AMOUNT / 2, "Incorrect lock amount");
        assertLt(lock.end, block.timestamp, "Lock should be expired");

        // Since we're partially staked, fully unlocked and still contributing:
        // Can withdraw - lock period expired
        bool canWithdraw = true;
        _verifyCanWithdraw(
            allocation.allocation.originalBeneficiary,
            canWithdraw,
            allocation.allocation.totalAllocation,
            decodableArgs,
            proof
        );
        // Can transfer - tokens are unlocked
        bool canTransfer = true;
        _verifyCanTransfer(allocation.allocation.originalBeneficiary, canTransfer);
        // Can't unstake - withdrawal already unstakes
        bool canUnstake = false;
        _verifyCanUnstake(allocation.allocation.originalBeneficiary, canUnstake);
        // Can't stake - withdrawn amount == total allocation
        bool canStake = false;
        _verifyCanStake(allocation.allocation.originalBeneficiary, canStake, allocationAmount, decodableArgs, proof);
        // Can claim rewards
        bool canClaimRewards = true;
        // Fast forward some time to accrue rewards
        skip(2 weeks);
        _verifyCanClaimRewards(allocation.allocation.originalBeneficiary, canClaimRewards);
    }

    function test_PartiallyStaked_FullyUnlocked_FinishedStake_StoppedContributing() public {
        // Setup vester with allocation
        vm.startPrank(users.admin);
        (CalendarAllocation[] memory allocations, bytes32[] memory hashes, bytes32 root) =
            createAllocationsAndMerkleTree("id1", true, true, false, false, FULL_FUND_AMOUNT);
        vester.addAllocationRoot(root);
        deal(address(l2wct), address(vester), FULL_FUND_AMOUNT);
        vm.stopPrank();

        // Get first allocation and create lock
        CalendarAllocation memory allocation = allocations[0];
        bytes32[] memory proof = merkle.getProof(hashes, 0);

        // Create a lock for half the allocation amount
        vm.startPrank(allocation.allocation.originalBeneficiary);
        bytes memory decodableArgs = abi.encode("calendar", allocation.allocation, calendarSchedules["id1"]);
        uint256 allocationAmount = allocation.allocation.totalAllocation / 2;

        lockedTokenStaker.createLockFor(allocationAmount, block.timestamp + YEAR, 0, decodableArgs, proof);
        vm.stopPrank();

        // Skip time to simulate full unlock
        skip(YEAR + 1 weeks);

        // Terminate the allocation to simulate "stopped contributing"
        bool isFullyUnlocked = true;
        _terminate(allocation.allocation.originalBeneficiary, isFullyUnlocked, decodableArgs, proof);

        // Verify state
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(allocation.allocation.originalBeneficiary);
        assertEq(uint256(uint128(lock.amount)), 0, "Incorrect lock amount");
        assertEq(lock.end, 0, "Incorrect lock end time");

        // Since we're partially staked, fully unlocked and stopped contributing:
        // Can withdraw - lock period expired and terminated
        bool canWithdraw = true;
        _verifyCanWithdraw(
            allocation.allocation.originalBeneficiary,
            canWithdraw,
            allocation.allocation.totalAllocation,
            decodableArgs,
            proof
        );
        // Can transfer - tokens are unlocked
        bool canTransfer = true;
        _verifyCanTransfer(allocation.allocation.originalBeneficiary, canTransfer);
        // Can't unstake - already terminated
        bool canUnstake = false;
        _verifyCanUnstake(allocation.allocation.originalBeneficiary, canUnstake);
        // Can't stake - termination doesn't allow staking
        bool canStake = false;
        _verifyCanStake(allocation.allocation.originalBeneficiary, canStake, allocationAmount, decodableArgs, proof);
        // Can claim rewards - all the accrued rewards are withdrawn
        bool canClaimRewards = true;
        _verifyCanClaimRewards(allocation.allocation.originalBeneficiary, canClaimRewards);
    }

    // NOT STAKED SCENARIOS
    function test_NotStaked_FullyLocked_StillContributing() public {
        // Setup vester with allocation
        vm.startPrank(users.admin);
        (CalendarAllocation[] memory allocations, bytes32[] memory hashes, bytes32 root) =
            createAllocationsAndMerkleTree("id1", true, true, false, false, FULL_FUND_AMOUNT);
        vester.addAllocationRoot(root);
        deal(address(l2wct), address(vester), FULL_FUND_AMOUNT);
        vm.stopPrank();

        // Get first allocation
        CalendarAllocation memory allocation = allocations[0];
        bytes32[] memory proof = merkle.getProof(hashes, 0);
        bytes memory decodableArgs = abi.encode("calendar", allocation.allocation, calendarSchedules["id1"]);

        // Verify state - no stake
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(allocation.allocation.originalBeneficiary);
        assertEq(uint256(uint128(lock.amount)), 0, "Incorrect lock amount");
        assertEq(lock.end, 0, "Incorrect lock end time");

        // Since we're not staked and still contributing:
        // Can't withdraw - tokens are still locked
        bool canWithdraw = false;
        _verifyCanWithdraw(
            allocation.allocation.originalBeneficiary,
            canWithdraw,
            allocation.allocation.totalAllocation / 4,
            decodableArgs,
            proof
        );
        // Can't transfer - tokens are locked
        bool canTransfer = false;
        _verifyCanTransfer(allocation.allocation.originalBeneficiary, canTransfer);
        // Can't unstake - no stake
        bool canUnstake = false;
        _verifyCanUnstake(allocation.allocation.originalBeneficiary, canUnstake);
        // Can't claim rewards - no stake
        bool canClaimRewards = false;
        _verifyCanClaimRewards(allocation.allocation.originalBeneficiary, canClaimRewards);
        // Can stake - nothing preventing it
        bool canStake = true;
        _verifyCanStake(
            allocation.allocation.originalBeneficiary,
            canStake,
            allocation.allocation.totalAllocation,
            decodableArgs,
            proof
        );
    }

    function test_NotStaked_FullyLocked_StoppedContributing() public {
        // Setup vester with allocation
        vm.startPrank(users.admin);
        (CalendarAllocation[] memory allocations, bytes32[] memory hashes, bytes32 root) =
            createAllocationsAndMerkleTree("id1", true, true, false, false, FULL_FUND_AMOUNT);
        vester.addAllocationRoot(root);
        deal(address(l2wct), address(vester), FULL_FUND_AMOUNT);
        vm.stopPrank();

        // Get first allocation
        CalendarAllocation memory allocation = allocations[0];
        bytes32[] memory proof = merkle.getProof(hashes, 0);
        bytes memory decodableArgs = abi.encode("calendar", allocation.allocation, calendarSchedules["id1"]);

        // Terminate the allocation to simulate "stopped contributing"
        bool isFullyUnlocked = false;
        _terminate(allocation.allocation.originalBeneficiary, isFullyUnlocked, decodableArgs, proof);

        // Verify state - no stake
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(allocation.allocation.originalBeneficiary);
        assertEq(uint256(uint128(lock.amount)), 0, "Incorrect lock amount");
        assertEq(lock.end, 0, "Incorrect lock end time");

        // Since we're not staked, fully locked and stopped contributing:
        // Can't withdraw - tokens didn't unlock
        bool canWithdraw = false;
        _verifyCanWithdraw(
            allocation.allocation.originalBeneficiary,
            canWithdraw,
            allocation.allocation.totalAllocation / 4,
            decodableArgs,
            proof
        );
        // Can't transfer - tokens are locked
        bool canTransfer = false;
        _verifyCanTransfer(allocation.allocation.originalBeneficiary, canTransfer);
        // Can't unstake - no stake
        bool canUnstake = false;
        _verifyCanUnstake(allocation.allocation.originalBeneficiary, canUnstake);
        // Can't claim rewards - no stake
        bool canClaimRewards = false;
        _verifyCanClaimRewards(allocation.allocation.originalBeneficiary, canClaimRewards);
        // Can't stake - allocation is terminated
        bool canStake = false;
        _verifyCanStake(
            allocation.allocation.originalBeneficiary,
            canStake,
            allocation.allocation.totalAllocation,
            decodableArgs,
            proof
        );
    }

    function test_NotStaked_PartiallyUnlocked_StillContributing() public {
        // Setup vester with allocation
        vm.startPrank(users.admin);
        (CalendarAllocation[] memory allocations, bytes32[] memory hashes, bytes32 root) =
            createAllocationsAndMerkleTree("id1", true, true, false, false, FULL_FUND_AMOUNT);
        vester.addAllocationRoot(root);
        deal(address(l2wct), address(vester), FULL_FUND_AMOUNT);
        vm.stopPrank();

        // Get first allocation
        CalendarAllocation memory allocation = allocations[0];
        bytes32[] memory proof = merkle.getProof(hashes, 0);
        bytes memory decodableArgs = abi.encode("calendar", allocation.allocation, calendarSchedules["id1"]);

        // Skip time to simulate partial unlock
        skip(31 days * 2);

        // Verify state - no stake
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(allocation.allocation.originalBeneficiary);
        assertEq(uint256(uint128(lock.amount)), 0, "Incorrect lock amount");
        assertEq(lock.end, 0, "Incorrect lock end time");

        // Since we're not staked, partially unlocked and still contributing:
        // Can withdraw - tokens are partially unlocked
        bool canWithdraw = true;
        _verifyCanWithdraw(
            allocation.allocation.originalBeneficiary,
            canWithdraw,
            allocation.allocation.totalAllocation / 4,
            decodableArgs,
            proof
        );
        // Can transfer - tokens are partially unlocked
        bool canTransfer = true;
        _verifyCanTransfer(allocation.allocation.originalBeneficiary, canTransfer);
        // Can't unstake - no stake
        bool canUnstake = false;
        _verifyCanUnstake(allocation.allocation.originalBeneficiary, canUnstake);
        // Can't claim rewards - no stake
        bool canClaimRewards = false;
        _verifyCanClaimRewards(allocation.allocation.originalBeneficiary, canClaimRewards);
        // Can stake - allocation is active
        bool canStake = true;
        _verifyCanStake(
            allocation.allocation.originalBeneficiary,
            canStake,
            allocation.allocation.totalAllocation * 3 / 4,
            decodableArgs,
            proof
        );
    }

    function test_NotStaked_PartiallyUnlocked_StoppedContributing() public {
        // Setup vester with allocation
        vm.startPrank(users.admin);
        (CalendarAllocation[] memory allocations, bytes32[] memory hashes, bytes32 root) =
            createAllocationsAndMerkleTree("id1", true, true, false, false, FULL_FUND_AMOUNT);
        vester.addAllocationRoot(root);
        deal(address(l2wct), address(vester), FULL_FUND_AMOUNT);
        vm.stopPrank();

        // Get first allocation
        CalendarAllocation memory allocation = allocations[0];
        bytes32[] memory proof = merkle.getProof(hashes, 0);
        bytes memory decodableArgs = abi.encode("calendar", allocation.allocation, calendarSchedules["id1"]);

        // Skip time to simulate partial unlock
        skip(31 days * 2);

        // Terminate the allocation to simulate "stopped contributing"
        bool isFullyUnlocked = false;
        _terminate(allocation.allocation.originalBeneficiary, isFullyUnlocked, decodableArgs, proof);

        // Verify state - no stake
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(allocation.allocation.originalBeneficiary);
        assertEq(uint256(uint128(lock.amount)), 0, "Incorrect lock amount");
        assertEq(lock.end, 0, "Incorrect lock end time");

        // Since we're not staked, partially unlocked and stopped contributing:
        // Can withdraw - terminated allocation allows withdrawal
        bool canWithdraw = true;
        _verifyCanWithdraw(
            allocation.allocation.originalBeneficiary,
            canWithdraw,
            allocation.allocation.totalAllocation / 4,
            decodableArgs,
            proof
        );
        // Can transfer - tokens are unlocked after termination
        bool canTransfer = true;
        _verifyCanTransfer(allocation.allocation.originalBeneficiary, canTransfer);
        // Can't unstake - no stake
        bool canUnstake = false;
        _verifyCanUnstake(allocation.allocation.originalBeneficiary, canUnstake);
        // Can't stake - termination doesn't allow staking
        bool canStake = false;
        _verifyCanStake(
            allocation.allocation.originalBeneficiary,
            canStake,
            allocation.allocation.totalAllocation,
            decodableArgs,
            proof
        );
        // Can't claim rewards - no stake
        bool canClaimRewards = false;
        _verifyCanClaimRewards(allocation.allocation.originalBeneficiary, canClaimRewards);
    }

    function test_NotStaked_FullyUnlocked_StillContributing() public {
        // Setup vester with allocation
        vm.startPrank(users.admin);
        (CalendarAllocation[] memory allocations, bytes32[] memory hashes, bytes32 root) =
            createAllocationsAndMerkleTree("id1", true, true, false, false, FULL_FUND_AMOUNT);
        vester.addAllocationRoot(root);
        deal(address(l2wct), address(vester), FULL_FUND_AMOUNT);
        vm.stopPrank();

        // Get first allocation
        CalendarAllocation memory allocation = allocations[0];
        bytes32[] memory proof = merkle.getProof(hashes, 0);
        bytes memory decodableArgs = abi.encode("calendar", allocation.allocation, calendarSchedules["id1"]);

        // Skip time to simulate full unlock
        skip(31 days * 4);

        // Verify state - no stake
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(allocation.allocation.originalBeneficiary);
        assertEq(uint256(uint128(lock.amount)), 0, "Incorrect lock amount");
        assertEq(lock.end, 0, "Incorrect lock end time");

        // Since we're not staked, fully unlocked and still contributing:
        // Can withdraw - tokens are unlocked
        bool canWithdraw = true;
        _verifyCanWithdraw(
            allocation.allocation.originalBeneficiary,
            canWithdraw,
            allocation.allocation.totalAllocation * 3 / 4,
            decodableArgs,
            proof
        );
        // Can transfer - tokens are unlocked
        bool canTransfer = true;
        _verifyCanTransfer(allocation.allocation.originalBeneficiary, canTransfer);
        // Can't unstake - no stake
        bool canUnstake = false;
        _verifyCanUnstake(allocation.allocation.originalBeneficiary, canUnstake);
        // Can stake - nothing preventing it
        bool canStake = true;
        _verifyCanStake(
            allocation.allocation.originalBeneficiary,
            canStake,
            allocation.allocation.totalAllocation / 4,
            decodableArgs,
            proof
        );
        // Can't claim rewards - no stake
        bool canClaimRewards = false;
        _verifyCanClaimRewards(allocation.allocation.originalBeneficiary, canClaimRewards);
    }

    function test_NotStaked_FullyUnlocked_StoppedContributing() public {
        // Setup vester with allocation
        vm.startPrank(users.admin);
        (CalendarAllocation[] memory allocations, bytes32[] memory hashes, bytes32 root) =
            createAllocationsAndMerkleTree("id1", true, true, false, false, FULL_FUND_AMOUNT);
        vester.addAllocationRoot(root);
        deal(address(l2wct), address(vester), FULL_FUND_AMOUNT);
        vm.stopPrank();

        // Get first allocation
        CalendarAllocation memory allocation = allocations[0];
        bytes32[] memory proof = merkle.getProof(hashes, 0);
        bytes memory decodableArgs = abi.encode("calendar", allocation.allocation, calendarSchedules["id1"]);

        // Skip time to simulate full unlock
        skip(31 days * 4);

        // Terminate the allocation to simulate "stopped contributing"
        bool isFullyUnlocked = true;
        _terminate(allocation.allocation.originalBeneficiary, isFullyUnlocked, decodableArgs, proof);

        // Verify state - no stake
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(allocation.allocation.originalBeneficiary);
        assertEq(uint256(uint128(lock.amount)), 0, "Incorrect lock amount");
        assertEq(lock.end, 0, "Incorrect lock end time");

        // Since we're not staked, fully unlocked and stopped contributing:
        // Can withdraw - tokens are unlocked
        bool canWithdraw = true;
        _verifyCanWithdraw(
            allocation.allocation.originalBeneficiary,
            canWithdraw,
            allocation.allocation.totalAllocation,
            decodableArgs,
            proof
        );
        // Can transfer - tokens are unlocked
        bool canTransfer = true;
        _verifyCanTransfer(allocation.allocation.originalBeneficiary, canTransfer);
        // Can't unstake - no stake
        bool canUnstake = false;
        _verifyCanUnstake(allocation.allocation.originalBeneficiary, canUnstake);
        // Can't stake - termination doesn't allow staking
        bool canStake = false;
        _verifyCanStake(
            allocation.allocation.originalBeneficiary,
            canStake,
            allocation.allocation.totalAllocation,
            decodableArgs,
            proof
        );
        // Can't claim rewards - no stake
        bool canClaimRewards = false;
        _verifyCanClaimRewards(allocation.allocation.originalBeneficiary, canClaimRewards);
    }

    function _verifyCanTransfer(address user, bool expectedCanTransfer) internal {
        // Try to transfer a small amount
        uint256 testAmount = 1e18;

        if (expectedCanTransfer) {
            // Should succeed if transfer is expected to be allowed
            vm.expectEmit(true, true, true, true);
            emit Transfer(user, users.bob, testAmount);
            vm.prank(user);
            l2wct.transfer(users.bob, testAmount);
        } else {
            // Should revert if transfer is not allowed
            vm.expectRevert();
            l2wct.transfer(users.bob, testAmount);
        }
        vm.stopPrank();
    }

    function _verifyCanUnstake(address user, bool expectedCanUnstake) internal {
        vm.startPrank(user);

        if (expectedCanUnstake) {
            // Should be able to withdraw if unstaking is allowed
            uint256 beforeBalance = l2wct.balanceOf(user);
            stakeWeight.withdrawAll();
            uint256 afterBalance = l2wct.balanceOf(user);
            assertGt(afterBalance, beforeBalance, "Unstaking should increase token balance");
        } else {
            // Should revert if trying to withdraw before lock expiration
            vm.expectRevert();
            stakeWeight.withdrawAll();
        }
        vm.stopPrank();
    }

    function _verifyCanStake(
        address user,
        bool expectedCanStake,
        uint256 availableBalance,
        bytes memory decodableArgs,
        bytes32[] memory proof
    )
        internal
    {
        uint32 rootIndex = 0;
        vm.startPrank(user);

        if (expectedCanStake) {
            // Should succeed if staking is expected to be allowed
            uint256 beforeLockAmount = SafeCast.toUint256(stakeWeight.locks(user).amount);
            if (beforeLockAmount > 0) {
                lockedTokenStaker.increaseLockAmountFor(availableBalance, rootIndex, decodableArgs, proof);
            } else {
                lockedTokenStaker.createLockFor(
                    availableBalance, block.timestamp + YEAR, rootIndex, decodableArgs, proof
                );
            }
            uint256 afterLockAmount = SafeCast.toUint256(stakeWeight.locks(user).amount);
            assertGt(afterLockAmount, beforeLockAmount, "Lock amount should increase");
        } else {
            // Should revert if staking is not allowed
            vm.expectRevert();
            lockedTokenStaker.createLockFor(availableBalance, block.timestamp + YEAR, rootIndex, decodableArgs, proof);
        }
        vm.stopPrank();
    }

    function _verifyCanClaimRewards(address user, bool expectedCanClaimRewards) internal {
        vm.startPrank(user);

        // Should be able to claim rewards if allowed
        uint256 beforeBalance = l2wct.balanceOf(user);
        stakingRewardDistributor.claim(user);
        uint256 afterBalance = l2wct.balanceOf(user);
        if (expectedCanClaimRewards) {
            assertGe(afterBalance, beforeBalance, "Should receive rewards");
        } else {
            assertEq(afterBalance, beforeBalance, "Should not receive rewards");
        }
        vm.stopPrank();
    }

    function _verifyCanWithdraw(
        address user,
        bool expectedCanWithdraw,
        uint256 expectedWithdrawAmount,
        bytes memory decodableArgs,
        bytes32[] memory proof
    )
        internal
    {
        vm.startPrank(user);
        if (!expectedCanWithdraw) {
            vm.expectRevert();
        }
        // Create the extraData by encoding all three required parameters
        bytes memory extraData = abi.encode(
            uint32(0), // rootIndex
            decodableArgs,
            proof
        );
        vester.withdraw(expectedWithdrawAmount, 0, decodableArgs, proof, postClaimHandler, extraData);
        vm.stopPrank();
    }

    function _terminate(
        address user,
        bool isFullyUnlocked,
        bytes memory decodableArgs,
        bytes32[] memory proof
    )
        internal
    {
        vm.startPrank(users.admin);
        if (isFullyUnlocked) {
            vm.expectRevert(abi.encodeWithSignature("AlreadyFullyUnlocked()"));
        }
        vester.cancel(0, decodableArgs, proof);
        StakeWeight.LockedBalance memory lock = stakeWeight.locks(user);
        if (lock.amount > 0) {
            stakeWeight.forceWithdrawAll(user);
        }
        vm.stopPrank();
    }
}
