pragma solidity 0.8.25;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/// @dev error thrown when token address is 0
error ZeroToken();
/// @dev error thrown when beneficiary address is 0
error ZeroBeneficiary();
/// @dev error thrown when amount is 0
error AmountZero();
/// @dev error thrown when amount is greater than max allocation
error AmountGreaterThanMaxAllocation();
/// @dev error thrown when the number of periods is 0
error ZeroPeriods();
/// @dev error thrown when the total percentage doesn't add up to 100
error Not100Percent();
/// @dev error thrown when the address is not the beneficiary
error NotBeneficiary();
/// @dev error thrown when the allocation is not cancellable
error NotCancellable();
/// @dev error thrown when the allocation is not revokable
error NotRevokable();
/// @dev error thrown when the allocation is not transferable
error NotTransferable();

/// @dev error thrown when the allocation is not funded
error NotFunded();
/// @dev error thrown when the timestamp provided is invalid
error InvalidTimestamp();
/// @dev error thrown when to many timestamps are provided
error TooManyTimestamps();
/// @dev error thrown when the supplied beneficiary address is the same as an others
error SameBeneficiaryAddress();

/// @dev error thrown when a calendar with the same id already exists
error CalendarExists();
/// @dev error thrown when a calendar doesn't exist or invalid
error InvalidCalendar();
/// @dev error thrown when array length of two or more arrays mismatch
error ArrayLengthMismatch();
/// @dev error thrown when array content of two or more arrays mismatch
error ArrayMismatch(uint16 errCode, uint16 index);
/// @dev error thrown when array length is zero
error ZeroArrayLength();
/// @dev error thrown when timestamps are not ordered
error UnorderedTimestamp();

/// @dev error thrown when an interval with the same id already exists
error IntervalExists();
/// @dev error thrown when an interval doesn't exist or invalid
error InvalidInterval();
/// @dev error thrown when an an amount in an interval is invalid
error InvalidAmount();
/// @dev error thrown when the cliff in an interval is invalid
error InvalidCliff();
/// @dev error thrown when a period in an interval is invalid
error InvalidPeriod();

/// @dev error thrown when the withdrawal amount is invalid
error InvalidWithdrawal();

/// @dev error thrown when the allocation is already terminated
error AlreadyTerminated();
/// @dev error thrown when the allocation is already fully unlocked
error AlreadyFullyUnlocked();

/// @dev error thrown when the token is invalid
error InvalidToken();
/// @dev error thrown when the allocation type is invalid
error InvalidAllocationType();
/// @dev error thrown when the token is deflationary
error DeflationaryTokensNotSupported();
/// @dev error thrown when the allocation is invalid
error InvalidAllocation();
/// @dev error thrown when the funds are not sufficient
error InsufficientFunds();
/// @dev error thrown when Merkle proof is invalid
error InvalidMerkleProof();

/// @dev error thrown when the fee collector is invalid
error InvalidFeeCollector();
/// @dev error thrown when the fee setter is invalid
error InvalidFeeSetter();
/// @dev error thrown when the fees sent with the claim request doesn't match the claim fee
error InvalidFeeFundsSent();
/// @dev error thrown when the claim fee is being set to a higher value than the maximum claim fee
error ClaimFeeExceedsMaximum();

/// @dev error thrown when the claim fee handler is already whitelisted
error ClaimHandlerAlreadyWhitelisted();
/// @dev error thrown when the the claim fee handler is not yet whitelisted
error ClaimHandlerNotYetWhitelisted();
/// @dev error thrown when post claim handler is not whitelisted
error PostClaimHandlerNotWhitelisted();

/**
 * @notice The mutable state of an allocation
 *
 * @param withdrawalAddress can be overriden when the schedule is transferable
 * @param terminatedTimestamp Sentinel values: 0 is active, 1 is revoked, any other value is the time the calendar was
 * cancelled
 * @param withdrawn represents the amount withdrawn by the beneficiary
 * @param terminatedWithdrawn represents the amount withdrawn from terminated funds, merkle vester does not support
 * funding indivual allocations
 * @param fundedAmount amount of tokens funded for this distribution, merkle vester does not support funding indivual
 * allocations
 * @param terminatedAmount amount of tokens terminated for this distribution, merkle vester does not support funding
 * indivual allocations
 */
struct DistributionState {
    address withdrawalAddress;
    uint32 terminatedTimestamp;
    uint256 withdrawn;
    uint256 terminatedWithdrawn;
    uint256 fundedAmount;
    uint256 terminatedAmount;
}

/**
 * @notice The immutable data for an allocation,
 * @dev solidity does not support immutablability outside of compile time, contracts must not implement mutability
 *
 * @param id id of the allocation
 * @param originalBeneficiary original beneficiary address, withdrawalAddress in DistributionState should be used for
 * transfers
 * @param totalAllocation total amount of tokens to vest in the allocaiton
 * @param cancelable flag to allow for the allocation to be cancelled, unvested funds are returned to the benefactor
 * vested funds remain withdrawable by the beneficiary
 * @param revokable flag to allow for the allocation to be revoked, all funds not already withdrawn are returned to the
 * benefactor
 * @param transferableByAdmin flag to allow for the allocation to be transferred by the admin
 * @param transferableByBeneficiary flag to allow for the allocation to be transferred by the beneficiary
 */
struct Allocation {
    string id;
    address originalBeneficiary;
    uint256 totalAllocation;
    bool cancelable;
    bool revokable;
    bool transferableByAdmin;
    bool transferableByBeneficiary;
}

/**
 * @notice Immutable unlock schedule for calendar allocations
 * @dev solidity does not support immutablability outside of compile time, contracts must not implement mutability
 *
 * @param unlockScheduleId id of the allocation
 * @param unlockTimestamps sequence of timestamps when funds will unlock
 * @param unlockPercents sequence of percents that unlock at each timestamp, in 10,000ths
 */
struct CalendarUnlockSchedule {
    string unlockScheduleId; // Workaround for Internal or recursive type is not allowed for public state variables
    uint32[] unlockTimestamps;
    uint256[] unlockPercents;
}

/**
 * @notice Immutable unlock schedule for interval allocations
 * @dev solidity does not support immutablability outside of compile time, contracts must not implement mutability
 *
 * @param unlockScheduleId id of the allocation
 * @param pieces sequence of pieces representing phases of the unlock schedule, percents of pieces must sum to 100%
 */
struct IntervalUnlockSchedule {
    string unlockScheduleId; // Workaround for Internal or recursive type is not allowed for public state variables
    Piece[] pieces;
}

/**
 * @notice Represents a phase of an interval unlock schedule
 * @dev solidity does not support immutablability outside of compile time, contracts must not implement mutability
 *
 * @param startDate start timestamp of the piece
 * @param periodLength time length of the piece
 * @param numberOfPeriods how many periods for this piece
 * @param percent the total percent, in 10,000ths that will unlock over the piece
 */
struct Piece {
    uint32 startDate;
    uint32 periodLength;
    uint32 numberOfPeriods;
    uint32 percent;
}

/// @notice Holding allocation data for Calendar style vesting, including both immutable and mutable data and a
/// reference to the calendar schedule
struct CalendarAllocation {
    Allocation allocation;
    // Many allocations share the same unlock schedule so we can save gas by referencing the same schedule
    // the mapping key could be smaller than string but this will help sync with the web application
    string calendarUnlockScheduleId;
    DistributionState distributionState;
}

/// @notice Holding allocation data for Interval style vesting, including both immutable and mutable data and a
/// reference to the interval schedule
struct IntervalAllocation {
    Allocation allocation;
    string intervalUnlockScheduleId;
    DistributionState distributionState;
}
