pragma solidity 0.8.25;

import {
    Allocation,
    CalendarAllocation,
    CalendarUnlockSchedule,
    IntervalAllocation,
    IntervalUnlockSchedule,
    DistributionState
} from "./AirlockTypes.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IPostClaimHandler } from "./IPostClaimHandler.sol";
import { IAirlockBase } from "./IAirlockBase.sol";

/// @notice Abstract contract to define common behavior for Merkle type vesters
interface IMerkleVester {
    /**
     * @notice Calculates the hash of a given Calendar allocation leaf
     *
     * @param allocationType 'calendar' or 'interval'
     * @param allocation allocation data
     * @param unlockSchedule calendar unlock schedule
     *
     * @return the hash of a given Calendar allocation leaf
     */
    function getCalendarLeafHash(
        string calldata allocationType,
        Allocation calldata allocation,
        CalendarUnlockSchedule calldata unlockSchedule
    )
        external
        pure
        returns (bytes32);

    /**
     * @notice Calculates the hash of a given Interval allocation leaf
     *
     * @param allocationType 'calendar' or 'interval'
     * @param allocation allocation data
     * @param unlockSchedule interval unlock schedule
     *
     * @return the hash of a given Interval allocation leaf
     */
    function getIntervalLeafHash(
        string calldata allocationType,
        Allocation calldata allocation,
        IntervalUnlockSchedule calldata unlockSchedule
    )
        external
        pure
        returns (bytes32);

    /**
     * @notice Decodes calendar allocation data from decodable arguments and state stored on chain
     *
     * @param rootIndex the index of the merkle root the allocation is in
     * @param decodableArgs the allocation data that constitutes the leaf to be decoded and verified
     * @param proof proof data of sibling leaves to verify the leaf is included in the root
     *
     * @return calendarAllocation decoded calendar allocation
     * @return calendarUnlockSchedule decoded calendar unlock schedule
     */
    function getCalendarLeafAllocationData(
        uint32 rootIndex,
        bytes calldata decodableArgs,
        bytes32[] calldata proof
    )
        external
        view
        returns (CalendarAllocation memory calendarAllocation, CalendarUnlockSchedule memory calendarUnlockSchedule);

    /**
     * @notice Decodes interval allocation data from decodable arguments and state stored on chain
     *
     * @param rootIndex the index of the merkle root the allocation is in
     * @param decodableArgs the allocation data that constitutes the leaf to be decoded and verified
     * @param proof proof data of sibling leaves to verify the leaf is included in the root
     *
     * @return intervalAllocation decoded interval allocation
     * @return intervalUnlockSchedule decoded interval unlock schedule
     */
    function getIntervalLeafAllocationData(
        uint32 rootIndex,
        bytes calldata decodableArgs,
        bytes32[] calldata proof
    )
        external
        view
        returns (IntervalAllocation memory intervalAllocation, IntervalUnlockSchedule memory intervalUnlockSchedule);

    /**
     * @notice Decodes allocation data from decodable arguments, works for both calendar and interval allocations
     *
     * @param rootIndex the index of the merkle root the allocation is in
     * @param decodableArgs the allocation data that constitutes the leaf to be decoded and verified
     * @param proof proof data of sibling leaves to verify the leaf is included in the root
     *
     * @return decoded allocation
     */
    function getLeafJustAllocationData(
        uint32 rootIndex,
        bytes memory decodableArgs,
        bytes32[] calldata proof
    )
        external
        view
        returns (Allocation memory);

    /**
     * @notice Adds additional allocations in an append only manner
     * @dev dapp is responsible for ensuring funding across all allocations otherwise withdrawals will be fulfilled
     * first come first served
     *
     * @param merkleRoot the additional merkle root to append representing additional allocations
     *
     * @return the new lenght of the number of merkle roots array minus 1
     */
    function addAllocationRoot(bytes32 merkleRoot) external returns (uint256);

    /**
     * @notice Funds the contract with the specified amount of tokens
     * @dev MerkleVester contracts are funded as a whole rather than funding individual allocations
     */
    function fund(uint256 amount) external;

    /**
     * @notice Defunds the contract the specified amount of tokens
     * @dev using defund can result in underfunding the total liabilies of the allocations, in which case allocations
     * will be served on a first come first serve basis
     */
    function defund(uint256 amount) external;

    /**
     * @notice Withdraws vested funds from the contract to the beneficiary
     * @dev if direct claim feature is disabled, then this method should not be called
     *
     * @param withdrawalAmount optional amount to withdraw, specify 0 to withdraw all vested funds. If amount specified
     * is greater than vested amount this call will fail since that implies a incorrect intention
     * @param rootIndex the index of the merkle root the allocation is in
     * @param decodableArgs the allocation data that constitutes the leaf to be decoded and verified
     * @param proof proof data of sibling leaves to verify the leaf is included in the root
     */
    function withdraw(
        uint256 withdrawalAmount,
        uint32 rootIndex,
        bytes memory decodableArgs,
        bytes32[] calldata proof
    )
        external
        payable;

    /**
     * @notice Withdraws vested funds from the contract to the beneficiary
     *
     * @param withdrawalAmount optional amount to withdraw, specify 0 to withdraw all vested funds. If amount specified
     * is greater than vested amount this call will fail since that implies a incorrect intention
     * @param rootIndex the index of the merkle root the allocation is in
     * @param decodableArgs the allocation data that constitutes the leaf to be decoded and verified
     * @param proof proof data of sibling leaves to verify the leaf is included in the root
     * @param postClaimHandler the tokens will be automatically transferred to postClaimHandler contract, after which
     * the handlePostClaim will be automatically called
     * @param extraData extra data that will be passed to the post claim handler
     */
    function withdraw(
        uint256 withdrawalAmount,
        uint32 rootIndex,
        bytes memory decodableArgs,
        bytes32[] calldata proof,
        IPostClaimHandler postClaimHandler,
        bytes calldata extraData
    )
        external
        payable;

    /**
     * @notice Transfers the beneficiary address of the allocation, only for allocations either transferable by the
     * beneficiary or benefactor
     *
     * @param newBeneficiaryAddress the new beneficiary address
     * @param rootIndex the index of the merkle root the allocation is in
     * @param decodableArgs the allocation data that constitutes the leaf to be decoded and verified
     * @param proof proof data of sibling leaves to verify the leaf is included in the root
     */
    function transferBeneficiaryAddress(
        address newBeneficiaryAddress,
        uint32 rootIndex,
        bytes memory decodableArgs,
        bytes32[] calldata proof
    )
        external;

    /**
     * @notice Cancels the allocation, already vested funds remain withdrawable to the beneficiary
     * @dev don't need to track the terminated amount since merkle vester doesn't have per allocation underfunding
     *
     * @param rootIndex the index of the merkle root the allocation is in
     * @param decodableArgs the allocation data that constitutes the leaf to be decoded and verified
     * @param proof proof data of sibling leaves to verify the leaf is included in the root
     */
    function cancel(uint32 rootIndex, bytes memory decodableArgs, bytes32[] calldata proof) external;

    /**
     * @notice Revokes the allocation, unwithdrawn funds are no longer withdrawable to the beneficiary
     * @dev don't need to track the terminated amount since merkle vester doesn't have per allocation underfunding
     *
     * @param rootIndex the index of the merkle root the allocation is in
     * @param decodableArgs the allocation data that constitutes the leaf to be decoded and verified
     * @param proof proof data of sibling leaves to verify the leaf is included in the root
     */
    function revoke(uint32 rootIndex, bytes memory decodableArgs, bytes32[] calldata proof) external;

    /**
     * @notice For exceptional circumstances, it would be prohibitively expensive to run cancellation logic per
     * allocation
     */
    function revokeAll() external;
}
