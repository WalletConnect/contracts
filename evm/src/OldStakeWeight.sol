// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { Pauser } from "./Pauser.sol";
import { WalletConnectConfig } from "./WalletConnectConfig.sol";
import { L2WCT } from "./L2WCT.sol";
/**
 * @title OldStakeWeight
 * @notice This contract implements a vote-escrowed token model for WCT (WalletConnect Token)
 * to create a staking mechanism with time-weighted power.
 * @dev This contract was inspired by Curve's veCRV and PancakeSwap's veCake implementations.
 * @author WalletConnect
 */

contract OldStakeWeight is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////////////////
                                    STRUCTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice A point in the linear decay graph
    struct Point {
        /// @notice The bias of the point
        int128 bias;
        /// @notice The slope of the point
        int128 slope;
        /// @notice The timestamp of the point
        uint256 timestamp;
        /// @notice The block number of the point
        uint256 blockNumber;
    }

    /// @notice A struct representing a locked balance
    struct LockedBalance {
        /// @notice The amount of locked tokens
        int128 amount;
        /// @notice The end time of the lock
        uint256 end;
        /// @notice The transferred tokens (if any)
        uint256 transferredAmount;
    }

    /// @notice Initialization parameters for the StakeWeight contract
    struct Init {
        /// @notice The address of the admin
        address admin;
        /// @notice The address of the WalletConnectConfig contract
        address config;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    // Define the storage namespace
    bytes32 constant STAKE_WEIGHT_STORAGE_POSITION = keccak256("com.walletconnect.stakeweight.storage");
    // Max lock duration
    uint256 public constant MAX_LOCK_CAP = (209 weeks) - 1;
    // Multiplier for the slope calculation
    uint256 public constant MULTIPLIER = 1e18;
    // Action Types
    uint256 public constant ACTION_DEPOSIT_FOR = 0;
    uint256 public constant ACTION_CREATE_LOCK = 1;
    uint256 public constant ACTION_INCREASE_LOCK_AMOUNT = 2;
    uint256 public constant ACTION_INCREASE_UNLOCK_TIME = 3;
    uint256 public constant ACTION_UPDATE_LOCK = 4;

    // Roles
    // @dev Role for the locked token staker, needs to happen after deployment for circular dependency
    bytes32 public constant LOCKED_TOKEN_STAKER_ROLE = keccak256("LOCKED_TOKEN_STAKER_ROLE");

    /*//////////////////////////////////////////////////////////////////////////
                                    STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Storage structure for StakeWeight
    /// @custom:storage-location erc7201:com.walletconnect.stakeweight.storage
    struct StakeWeightStorage {
        /// @notice Configuration for WalletConnect
        WalletConnectConfig config;
        /// @notice Total supply of WCT locked
        uint256 supply;
        /// @notice Maximum lock duration
        uint256 maxLock;
        /// @notice Mapping (user => LockedBalance) to keep locking information for each user
        mapping(address user => LockedBalance lock) locks;
        /// @notice A global point of time
        uint256 epoch;
        /// @notice An array of points (global)
        Point[] pointHistory;
        /// @notice Mapping (user => Point[]) to keep track of user point of a given epoch (index of Point is epoch)
        mapping(address user => Point[] points) userPointHistory;
        /// @notice Mapping (user => epoch) to keep track which epoch user is at
        mapping(address user => uint256 epoch) userPointEpoch;
        /// @notice Mapping (round off timestamp to week => slopeDelta) to keep track of slope changes over epoch
        mapping(uint256 timestamp => int128 slopeDelta) slopeChanges;
    }

    function _getStakeWeightStorage() internal pure returns (StakeWeightStorage storage s) {
        bytes32 position = STAKE_WEIGHT_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    event Deposit(
        address indexed provider,
        uint256 amount,
        uint256 locktime,
        uint256 type_,
        uint256 transferredAmount,
        uint256 timestamp
    );

    event Withdraw(address indexed provider, uint256 totalAmount, uint256 transferredAmount, uint256 timestamp);
    event ForcedWithdraw(
        address indexed provider,
        uint256 totalAmount,
        uint256 transferredAmount,
        uint256 timestamp,
        uint256 endTimestamp
    );
    event Supply(uint256 previousSupply, uint256 newSupply);
    event MaxLockUpdated(uint256 previousMaxLock, uint256 newMaxLock);

    /*//////////////////////////////////////////////////////////////////////////
                                    ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when an invalid amount is provided
    /// @param amount The invalid amount
    error InvalidAmount(uint256 amount);

    /// @notice Thrown when an invalid address is provided
    /// @param addr The invalid address
    error InvalidAddress(address addr);

    /// @notice Thrown when attempting to create a lock that already exists
    error AlreadyCreatedLock();

    /// @notice Thrown when attempting to operate on a non-existent lock
    error NonExistentLock();

    /// @notice Thrown when attempting to withdraw from an active lock
    /// @param lockEndTime The time when the lock ends
    error LockStillActive(uint256 lockEndTime);

    /// @notice Thrown when an invalid unlock time is provided
    /// @param unlockTime The invalid unlock time
    error InvalidUnlockTime(uint256 unlockTime);

    /// @notice Thrown when an invalid max lock duration is provided
    /// @param maxLock The invalid max lock duration
    error InvalidMaxLock(uint256 maxLock);

    /// @notice Thrown when attempting to operate on an expired lock
    /// @param currentTime The current time
    /// @param lockEndTime The time when the lock ended
    error ExpiredLock(uint256 currentTime, uint256 lockEndTime);

    /// @notice Thrown when attempting to create a lock exceeding the maximum duration
    /// @param attemptedDuration The attempted lock duration
    /// @param maxDuration The maximum allowed lock duration
    error LockMaxDurationExceeded(uint256 attemptedDuration, uint256 maxDuration);

    /// @notice Thrown when attempting to increase lock time but new duration is not greater
    /// @param currentDuration The current lock duration
    /// @param attemptedDuration The attempted new lock duration
    error LockTimeNotIncreased(uint256 currentDuration, uint256 attemptedDuration);

    /// @notice Thrown when attempting to query a future block number
    /// @param currentBlock The current block number
    /// @param requestedBlock The requested future block number
    error FutureBlockNumber(uint256 currentBlock, uint256 requestedBlock);

    /// @notice Thrown when the locked amount is insufficient for an operation
    /// @param actualLockedAmount The actual locked amount
    /// @param requiredLockedAmount The required locked amount
    error InsufficientLockedAmount(uint256 actualLockedAmount, uint256 requiredLockedAmount);

    /// @notice Thrown when attempting to perform an action while the contract is paused
    error Paused();

    /// @notice Thrown when attempting to perform an action while transfer restrictions are enabled
    error TransferRestrictionsEnabled();

    /*//////////////////////////////////////////////////////////////////////////
                                INITIALIZER
    //////////////////////////////////////////////////////////////////////////*/

    function initialize(Init memory init) external initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        if (init.config == address(0)) revert InvalidAddress(init.config);
        if (init.admin == address(0)) revert InvalidAddress(init.admin);

        _grantRole(DEFAULT_ADMIN_ROLE, init.admin);

        StakeWeightStorage storage s = _getStakeWeightStorage();
        s.config = WalletConnectConfig(init.config);
        // Around 2 years in seconds (based on weeks)
        s.maxLock = 105 weeks - 1;
        s.pointHistory.push(Point({ bias: 0, slope: 0, timestamp: block.timestamp, blockNumber: block.number }));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Return the balance of Stake Weight at a given "blockNumber"
    /// @param user The address to get a balance of Stake Weight
    /// @param blockNumber The specific block number that you want to check the balance of Stake Weight
    function balanceOfAt(address user, uint256 blockNumber) external view returns (uint256) {
        return _balanceOfAt(user, blockNumber);
    }

    function _balanceOfAt(address user, uint256 blockNumber) internal view returns (uint256) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        // Get most recent user Point to block
        uint256 userEpoch = _findUserBlockEpoch(user, blockNumber);
        if (userEpoch == 0) {
            return 0;
        }
        Point memory userPoint = s.userPointHistory[user][userEpoch];

        // Get most recent global point to block
        uint256 maxEpoch = s.epoch;
        uint256 epoch_ = _findBlockEpoch(blockNumber, maxEpoch);
        Point memory point0 = s.pointHistory[epoch_];

        uint256 blockDelta = 0;
        uint256 timeDelta = 0;
        if (epoch_ < maxEpoch) {
            Point memory point1 = s.pointHistory[epoch_ + 1];
            blockDelta = point1.blockNumber - point0.blockNumber;
            timeDelta = point1.timestamp - point0.timestamp;
        } else {
            blockDelta = block.number - point0.blockNumber;
            timeDelta = block.timestamp - point0.timestamp;
        }
        uint256 blockTime = point0.timestamp;
        if (blockDelta != 0) {
            blockTime += (timeDelta * (blockNumber - point0.blockNumber)) / blockDelta;
        }

        userPoint.bias -= (userPoint.slope * SafeCast.toInt128(int256(blockTime - userPoint.timestamp)));

        if (userPoint.bias < 0) {
            return 0;
        }

        return SafeCast.toUint256(userPoint.bias);
    }

    /// @notice Return the voting weight of a givne user
    /// @param user The address of a user
    function balanceOf(address user) external view returns (uint256) {
        return _balanceOf(user, block.timestamp);
    }
    /// @notice Calculate the stake weight of a user at a specific timestamp
    /// @dev This function is primarily designed for calculating future balances.
    ///      CAUTION: It will revert due to underflow for timestamps before the user's last checkpoint.
    ///      This behavior is intentional and should be carefully considered when calling this function.
    ///      - For timestamps > last checkpoint: Projects future balance based on current slope
    ///      - For timestamps == last checkpoint: Returns current balance
    ///      - For timestamps < last checkpoint: Reverts due to underflow
    ///      Use with care in contract interactions and consider implementing try/catch for calls to this function.
    /// @param user The address of the user to check
    /// @param timestamp The timestamp to check the stake weight at
    /// @return The user's projected stake weight at the specified timestamp

    function balanceOfAtTime(address user, uint256 timestamp) external view returns (uint256) {
        return _balanceOf(user, timestamp);
    }

    function _balanceOf(address user, uint256 timestamp) internal view returns (uint256) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        uint256 epoch_ = s.userPointEpoch[user];
        if (epoch_ == 0) {
            return 0;
        }
        Point memory lastPoint = s.userPointHistory[user][epoch_];
        lastPoint.bias = lastPoint.bias - (lastPoint.slope * SafeCast.toInt128(int256(timestamp - lastPoint.timestamp)));
        if (lastPoint.bias < 0) {
            lastPoint.bias = 0;
        }
        return SafeCast.toUint256(lastPoint.bias);
    }

    /// @notice Record global and per-user slope to checkpoint
    /// @param address_ User's wallet address. Only global if 0x0
    /// @param prevLocked User's previous locked balance and end lock time
    /// @param newLocked User's new locked balance and end lock time
    function _checkpoint(address address_, LockedBalance memory prevLocked, LockedBalance memory newLocked) internal {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        Point memory userPrevPoint = Point({ slope: 0, bias: 0, timestamp: 0, blockNumber: 0 });
        Point memory userNewPoint = Point({ slope: 0, bias: 0, timestamp: 0, blockNumber: 0 });

        int128 prevSlopeDelta = 0;
        int128 newSlopeDelta = 0;
        uint256 epoch_ = s.epoch;

        // if not 0x0, then update user's point
        if (address_ != address(0)) {
            // Calculate slopes and biases according to linear decay graph
            // slope = lockedAmount / MAX_LOCK_CAP => Get the slope of a linear decay graph
            // bias = slope * (lockedEnd - currentTimestamp) => Get the voting weight at a given time
            // Kept at zero when they have to
            if (prevLocked.end > block.timestamp && prevLocked.amount > 0) {
                // Calculate slope and bias for the prev point
                userPrevPoint.slope = prevLocked.amount / SafeCast.toInt128(int256(MAX_LOCK_CAP));
                userPrevPoint.bias = userPrevPoint.slope * SafeCast.toInt128(int256(prevLocked.end - block.timestamp));
            }
            if (newLocked.end > block.timestamp && newLocked.amount > 0) {
                // Calculate slope and bias for the new point
                userNewPoint.slope = newLocked.amount / SafeCast.toInt128(int256(MAX_LOCK_CAP));
                userNewPoint.bias = userNewPoint.slope * SafeCast.toInt128(int256(newLocked.end - block.timestamp));
            }

            // Handle user history here
            // Do it here to prevent stack overflow
            uint256 userEpoch = s.userPointEpoch[address_];
            // If user never ever has any point history, push it here for him.
            if (userEpoch == 0) {
                s.userPointHistory[address_].push(userPrevPoint);
            }

            // Shift user's epoch by 1 as we are writing a new point for a user
            s.userPointEpoch[address_] = userEpoch + 1;

            // Update timestamp & block number then push new point to user's history
            userNewPoint.timestamp = block.timestamp;
            userNewPoint.blockNumber = block.number;
            s.userPointHistory[address_].push(userNewPoint);

            // Read values of scheduled changes in the slope
            // prevLocked.end can be in the past and in the future
            // newLocked.end can ONLY be in the FUTURE unless everything expired (anything more than zeros)
            prevSlopeDelta = s.slopeChanges[prevLocked.end];
            if (newLocked.end != 0) {
                // Handle when newLocked.end != 0
                if (newLocked.end == prevLocked.end) {
                    // This will happen when user adjust lock but end remains the same
                    // Possibly when user deposited more WCT to his locker
                    newSlopeDelta = prevSlopeDelta;
                } else {
                    // This will happen when user increase lock
                    newSlopeDelta = s.slopeChanges[newLocked.end];
                }
            }
        }

        // Handle global states here
        Point memory lastPoint = Point({ bias: 0, slope: 0, timestamp: block.timestamp, blockNumber: block.number });
        if (epoch_ > 0) {
            // If epoch_ > 0, then there is some history written
            // Hence, lastPoint should be pointHistory[epoch_]
            // else lastPoint should an empty point
            lastPoint = s.pointHistory[epoch_];
        }
        // lastCheckpoint => timestamp of the latest point
        // if no history, lastCheckpoint should be block.timestamp
        // else lastCheckpoint should be the timestamp of latest pointHistory
        uint256 lastCheckpoint = lastPoint.timestamp;

        // initialLastPoint is used for extrapolation to calculate block number
        // (approximately, for xxxAt methods) and save them
        // as we cannot figure that out exactly from inside contract
        Point memory initialLastPoint =
            Point({ bias: 0, slope: 0, timestamp: lastPoint.timestamp, blockNumber: lastPoint.blockNumber });

        // If last point is already recorded in this block, blockSlope=0
        // That is ok because we know the block in such case
        uint256 blockSlope = 0;
        if (block.timestamp > lastPoint.timestamp) {
            // Recalculate blockSlope if lastPoint.timestamp < block.timestamp
            // Possiblity when epoch = 0 or blockSlope hasn't get updated in this block
            blockSlope = (MULTIPLIER * (block.number - lastPoint.blockNumber)) / (block.timestamp - lastPoint.timestamp);
        }

        // Go over weeks to fill history and calculate what the current point is
        uint256 weekCursor = _timestampToFloorWeek(lastCheckpoint);
        for (uint256 i = 0; i < 255; i++) {
            // This logic will works for 5 years, if more than that vote power will be broken 😟
            // Bump weekCursor a week
            weekCursor = weekCursor + 1 weeks;
            int128 slopeDelta = 0;
            if (weekCursor > block.timestamp) {
                // If the given weekCursor go beyond block.timestamp,
                // We take block.timestamp as the cursor
                weekCursor = block.timestamp;
            } else {
                // If the given weekCursor is behind block.timestamp
                // We take slopeDelta from the recorded slopeChanges
                // We can use weekCursor directly because key of slopeChanges is timestamp round off to week
                slopeDelta = s.slopeChanges[weekCursor];
            }
            // Calculate biasDelta = lastPoint.slope * (weekCursor - lastCheckpoint)
            int128 biasDelta = lastPoint.slope * SafeCast.toInt128(int256((weekCursor - lastCheckpoint)));
            lastPoint.bias = lastPoint.bias - biasDelta;
            lastPoint.slope = lastPoint.slope + slopeDelta;
            if (lastPoint.bias < 0) {
                // This can happen
                lastPoint.bias = 0;
            }
            if (lastPoint.slope < 0) {
                // This cannot happen, just make sure
                lastPoint.slope = 0;
            }
            // Update lastPoint to the new one
            lastCheckpoint = weekCursor;
            lastPoint.timestamp = weekCursor;
            // As we cannot figure that out block timestamp -> block number exactly
            // when query states from xxxAt methods, we need to calculate block number
            // based on initalLastPoint
            lastPoint.blockNumber =
                initialLastPoint.blockNumber + ((blockSlope * ((weekCursor - initialLastPoint.timestamp))) / MULTIPLIER);
            epoch_ = epoch_ + 1;
            if (weekCursor == block.timestamp) {
                // Hard to be happened, but better handling this case too
                lastPoint.blockNumber = block.number;
                break;
            } else {
                s.pointHistory.push(lastPoint);
            }
        }
        // Now, each week pointHistory has been filled until current timestamp (round off by week)
        // Update epoch to be the latest state
        s.epoch = epoch_;

        if (address_ != address(0)) {
            // If the last point was in the block, the slope change should have been applied already
            // But in such case slope shall be 0
            lastPoint.slope = lastPoint.slope + userNewPoint.slope - userPrevPoint.slope;
            lastPoint.bias = lastPoint.bias + userNewPoint.bias - userPrevPoint.bias;
            if (lastPoint.slope < 0) {
                lastPoint.slope = 0;
            }
            if (lastPoint.bias < 0) {
                lastPoint.bias = 0;
            }
        }

        // Record the new point to pointHistory
        // This would be the latest point for global epoch
        s.pointHistory.push(lastPoint);

        if (address_ != address(0)) {
            // Schedule the slope changes (slope is going downward)
            // We substract newSlopeDelta from `newLocked.end`
            // and add prevSlopeDelta to `prevLocked.end`
            if (prevLocked.end > block.timestamp) {
                // prevSlopeDelta was <something> - userPrevPoint.slope, so we offset that first
                prevSlopeDelta = prevSlopeDelta + userPrevPoint.slope;
                if (newLocked.end == prevLocked.end) {
                    // Handle the new deposit. Not increasing lock.
                    prevSlopeDelta = prevSlopeDelta - userNewPoint.slope;
                }
                s.slopeChanges[prevLocked.end] = prevSlopeDelta;
            }
            if (newLocked.end > block.timestamp) {
                if (newLocked.end > prevLocked.end) {
                    // At this line, the old slope should gone
                    newSlopeDelta = newSlopeDelta - userNewPoint.slope;
                    s.slopeChanges[newLocked.end] = newSlopeDelta;
                }
            }
        }
    }

    /// @notice Trigger global checkpoint
    function checkpoint() external {
        LockedBalance memory empty = LockedBalance({ amount: 0, end: 0, transferredAmount: 0 });
        _checkpoint(address(0), empty, empty);
    }

    /// @notice Create a new lock.
    /// @dev This will crate a new lock and deposit WCT to Stake Weight Vault
    /// @param amount the amount that user wishes to deposit
    /// @param unlockTime the timestamp when WCT get unlocked, it will be
    /// floored down to whole weeks
    function createLock(uint256 amount, uint256 unlockTime) external nonReentrant {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        if (Pauser(s.config.getPauser()).isStakeWeightPaused()) revert Paused();
        _createLock(msg.sender, amount, unlockTime, true);
    }

    function createLockFor(
        address for_,
        uint256 amount,
        uint256 unlockTime
    )
        external
        nonReentrant
        onlyRole(LOCKED_TOKEN_STAKER_ROLE)
    {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        if (Pauser(s.config.getPauser()).isStakeWeightPaused()) revert Paused();
        _createLock(for_, amount, unlockTime, false);
    }

    function _createLock(address for_, uint256 amount, uint256 unlockTime, bool isTransferred) internal {
        unlockTime = _timestampToFloorWeek(unlockTime);
        StakeWeightStorage storage s = _getStakeWeightStorage();
        LockedBalance memory locked = s.locks[for_];

        if (amount == 0) revert InvalidAmount(amount);
        if (locked.amount != 0) revert AlreadyCreatedLock();
        if (unlockTime <= block.timestamp) revert InvalidUnlockTime(unlockTime);
        if (unlockTime > block.timestamp + s.maxLock) {
            revert LockMaxDurationExceeded(unlockTime, block.timestamp + s.maxLock);
        }

        _depositFor(for_, amount, unlockTime, locked, ACTION_CREATE_LOCK, isTransferred);
    }
    /// @notice Deposit `amount` tokens for `for_` and add to `locks[for_]`
    /// @dev This function is used for deposit to created lock. Not for extend locktime.
    /// @param for_ The address to do the deposit
    /// @param amount The amount that user wishes to deposit

    function depositFor(address for_, uint256 amount) external nonReentrant {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        if (Pauser(s.config.getPauser()).isStakeWeightPaused()) revert Paused();
        if (L2WCT(s.config.getL2wct()).transferRestrictionsDisabledAfter() >= block.timestamp) {
            revert TransferRestrictionsEnabled();
        }
        LockedBalance memory lock = LockedBalance({
            amount: s.locks[for_].amount,
            end: s.locks[for_].end,
            transferredAmount: s.locks[for_].transferredAmount
        });

        if (for_ == address(0)) revert InvalidAddress(for_);
        if (amount == 0) revert InvalidAmount(amount);
        if (lock.amount == 0) revert NonExistentLock();
        if (lock.end <= block.timestamp) revert ExpiredLock(block.timestamp, lock.end);

        _depositFor(for_, amount, 0, lock, ACTION_DEPOSIT_FOR, true);
    }

    /// @notice Internal function to perform deposit and lock WCT for a user
    /// @param for_ The address to be locked and received Stake Weight
    /// @param amount The amount to deposit
    /// @param unlockTime New time to unlock WCT. Pass 0 if no change.
    /// @param prevLocked Existed locks[for]
    /// @param actionType The action that user did as this internal function shared among
    function _depositFor(
        address for_,
        uint256 amount,
        uint256 unlockTime,
        LockedBalance memory prevLocked,
        uint256 actionType,
        bool isTransferred
    )
        internal
    {
        StakeWeightStorage storage s = _getStakeWeightStorage();

        // Initiate supplyBefore & update supply
        uint256 supplyBefore = s.supply;
        s.supply = supplyBefore + amount;

        // Store prevLocked
        LockedBalance memory newLocked = LockedBalance({
            amount: prevLocked.amount,
            end: prevLocked.end,
            transferredAmount: prevLocked.transferredAmount
        });

        // Adding new lock to existing lock, or if lock is expired
        // - creating a new one
        newLocked.amount = newLocked.amount + SafeCast.toInt128(int256(amount));
        if (unlockTime != 0) {
            newLocked.end = unlockTime;
        }

        if (isTransferred) {
            newLocked.transferredAmount += amount;
        }

        s.locks[for_] = newLocked;

        // Handling checkpoint here
        _checkpoint(for_, prevLocked, newLocked);

        if (isTransferred) {
            IERC20(s.config.getL2wct()).safeTransferFrom(msg.sender, address(this), amount);
        }

        emit Deposit(for_, amount, newLocked.end, actionType, isTransferred ? amount : 0, block.timestamp);
        emit Supply(supplyBefore, s.supply);
    }

    /// @notice Do Binary Search to find out block timestamp for block number
    /// @param blockNumber The block number to find timestamp
    /// @param maxEpoch No beyond this timestamp
    function _findBlockEpoch(uint256 blockNumber, uint256 maxEpoch) internal view returns (uint256) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        uint256 min = 0;
        uint256 max = maxEpoch;
        // Loop for 128 times -> enough for 128-bit numbers
        for (uint256 i = 0; i < 128; i++) {
            if (min >= max) {
                break;
            }
            uint256 mid = (min + max + 1) / 2;
            if (s.pointHistory[mid].blockNumber <= blockNumber) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return min;
    }

    /// @notice Do Binary Search to find the most recent user point history preceeding block
    /// @param user The address of user to find
    /// @param blockNumber Find the most recent point history before this block number
    function _findUserBlockEpoch(address user, uint256 blockNumber) internal view returns (uint256) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        uint256 min = 0;
        uint256 max = s.userPointEpoch[user];
        for (uint256 i = 0; i < 128; i++) {
            if (min >= max) {
                break;
            }
            uint256 mid = (min + max + 1) / 2;
            if (s.userPointHistory[user][mid].blockNumber <= blockNumber) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return min;
    }

    /// @notice Increase lock amount without increase "end"
    /// @param amount The amount of WCT to be added to the lock
    function increaseLockAmount(uint256 amount) external nonReentrant {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        if (Pauser(s.config.getPauser()).isStakeWeightPaused()) revert Paused();
        _increaseLockAmount(msg.sender, amount, true);
    }

    function increaseLockAmountFor(
        address for_,
        uint256 amount
    )
        external
        nonReentrant
        onlyRole(LOCKED_TOKEN_STAKER_ROLE)
    {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        if (Pauser(s.config.getPauser()).isStakeWeightPaused()) revert Paused();
        _increaseLockAmount(for_, amount, false);
    }

    function _increaseLockAmount(address for_, uint256 amount, bool isTransferred) internal {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        LockedBalance memory lock = s.locks[for_];
        if (amount == 0) revert InvalidAmount(amount);
        if (lock.amount == 0) revert NonExistentLock();
        if (lock.end <= block.timestamp) revert ExpiredLock(block.timestamp, lock.end);
        _depositFor(for_, amount, 0, lock, ACTION_INCREASE_LOCK_AMOUNT, isTransferred);
    }

    /// @notice Increase unlock time without changing locked amount
    /// @param newUnlockTime The new unlock time to be updated
    function increaseUnlockTime(uint256 newUnlockTime) external nonReentrant {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        if (Pauser(s.config.getPauser()).isStakeWeightPaused()) revert Paused();
        LockedBalance memory locked = s.locks[msg.sender];
        newUnlockTime = _timestampToFloorWeek(newUnlockTime);
        if (locked.amount == 0) revert NonExistentLock();
        if (locked.end <= block.timestamp) revert ExpiredLock(block.timestamp, locked.end);
        if (newUnlockTime <= locked.end) revert LockTimeNotIncreased(locked.end, newUnlockTime);
        if (newUnlockTime > block.timestamp + s.maxLock) {
            revert LockMaxDurationExceeded(newUnlockTime, _timestampToFloorWeek(block.timestamp + s.maxLock));
        }
        _depositFor(msg.sender, 0, newUnlockTime, locked, ACTION_INCREASE_UNLOCK_TIME, false);
    }

    /// @notice Atomically update both lock duration and amount
    /// @param amount The additional amount to lock
    /// @param unlockTime The new unlock time
    function updateLock(uint256 amount, uint256 unlockTime) external nonReentrant {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        if (Pauser(s.config.getPauser()).isStakeWeightPaused()) revert Paused();

        LockedBalance memory lock = s.locks[msg.sender];
        if (lock.amount == 0) revert NonExistentLock();
        if (lock.end <= block.timestamp) revert ExpiredLock(block.timestamp, lock.end);
        if (amount == 0) revert InvalidAmount(amount);

        // Floor the unlock time first
        unlockTime = _timestampToFloorWeek(unlockTime);
        if (unlockTime <= lock.end) revert LockTimeNotIncreased(lock.end, unlockTime);
        if (unlockTime > _timestampToFloorWeek(block.timestamp + s.maxLock)) {
            revert LockMaxDurationExceeded(unlockTime, _timestampToFloorWeek(block.timestamp + s.maxLock));
        }

        // Update both unlock time and amount in a single _depositFor call
        _depositFor(msg.sender, amount, unlockTime, lock, ACTION_UPDATE_LOCK, true);
    }

    /// @notice Round off random timestamp to week
    /// @param timestamp The timestamp to be rounded off
    function _timestampToFloorWeek(uint256 timestamp) internal pure returns (uint256) {
        return (timestamp / 1 weeks) * 1 weeks;
    }

    /// @notice Calculate total supply of Stake Weight
    function totalSupply() external view returns (uint256) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        return _totalSupplyAt(s.pointHistory[s.epoch], block.timestamp);
    }

    /// @notice Calculate total supply of Stake Weight at at specific timestamp
    /// @param timestamp The specific timestamp to calculate totalSupply
    function totalSupplyAtTime(uint256 timestamp) external view returns (uint256) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        return _totalSupplyAt(s.pointHistory[s.epoch], timestamp);
    }

    /// @notice Calculate total supply of Stake Weight at specific block
    /// @param blockNumber The specific block number to calculate totalSupply
    function totalSupplyAt(uint256 blockNumber) external view returns (uint256) {
        if (blockNumber > block.number) revert FutureBlockNumber(block.number, blockNumber);
        StakeWeightStorage storage s = _getStakeWeightStorage();
        uint256 epoch_ = s.epoch;
        uint256 targetEpoch = _findBlockEpoch(blockNumber, epoch_);

        Point memory point = s.pointHistory[targetEpoch];
        uint256 timeDelta = 0;
        if (targetEpoch < epoch_) {
            Point memory nextPoint = s.pointHistory[targetEpoch + 1];
            if (point.blockNumber != nextPoint.blockNumber) {
                timeDelta = ((blockNumber - point.blockNumber) * (nextPoint.timestamp - point.timestamp))
                    / (nextPoint.blockNumber - point.blockNumber);
            }
        } else {
            if (point.blockNumber != block.number) {
                timeDelta = ((blockNumber - point.blockNumber) * (block.timestamp - point.timestamp))
                    / (block.number - point.blockNumber);
            }
        }

        return _totalSupplyAt(point, point.timestamp + timeDelta);
    }

    /// @notice Calculate total supply of Stake Weight at some point in the past
    /// @param point The point to start to search from
    /// @param timestamp The timestamp to calculate the total voting power at
    function _totalSupplyAt(Point memory point, uint256 timestamp) internal view returns (uint256) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        Point memory lastPoint = point;
        uint256 weekCursor = _timestampToFloorWeek(point.timestamp);
        // Iterate through weeks to take slopChanges into the account
        for (uint256 i = 0; i < 255; i++) {
            weekCursor = weekCursor + 1 weeks;
            int128 slopeDelta = 0;
            if (weekCursor > timestamp) {
                // If weekCursor goes beyond timestamp -> leave slopeDelta
                // to be 0 as there is no more slopeChanges
                weekCursor = timestamp;
            } else {
                // If weekCursor still behind timestamp, then slopeDelta
                // should be taken into the account.
                slopeDelta = s.slopeChanges[weekCursor];
            }
            // Update bias at weekCursor
            lastPoint.bias =
                lastPoint.bias - (lastPoint.slope * SafeCast.toInt128(int256(weekCursor - lastPoint.timestamp)));
            if (weekCursor == timestamp) {
                break;
            }
            // Update slope and timestamp
            lastPoint.slope = lastPoint.slope + slopeDelta;
            lastPoint.timestamp = weekCursor;
        }

        if (lastPoint.bias < 0) {
            lastPoint.bias = 0;
        }

        return SafeCast.toUint256(lastPoint.bias);
    }

    /// @notice Withdraw all WCT when lock has expired.
    function withdrawAll() external nonReentrant {
        _withdrawAll(msg.sender);
    }

    function withdrawAllFor(address user) external nonReentrant onlyRole(LOCKED_TOKEN_STAKER_ROLE) {
        _withdrawAll(user);
    }

    function forceWithdrawAll(address to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (to == address(0)) {
            revert InvalidAddress(to);
        }
        StakeWeightStorage storage s = _getStakeWeightStorage();

        if (Pauser(s.config.getPauser()).isStakeWeightPaused()) revert Paused();

        LockedBalance memory lock = s.locks[to];

        uint256 amount = SafeCast.toUint256(lock.amount);

        if (amount == 0) revert NonExistentLock();

        uint256 end = lock.end;
        uint256 transferredAmount = lock.transferredAmount;

        _unlock(to, lock, amount);

        // transfer remaining back to owner
        if (transferredAmount > 0) {
            IERC20(s.config.getL2wct()).safeTransfer(to, transferredAmount);
        }

        emit ForcedWithdraw(to, amount, transferredAmount, block.timestamp, end);
    }

    function _withdrawAll(address user) internal {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        WalletConnectConfig wcConfig = s.config;
        if (Pauser(wcConfig.getPauser()).isStakeWeightPaused()) revert Paused();
        LockedBalance memory lock = s.locks[user];
        uint256 amount = SafeCast.toUint256(lock.amount);
        if (amount == 0) revert NonExistentLock();
        if (lock.end > block.timestamp) revert LockStillActive(lock.end);

        uint256 transferredAmount = lock.transferredAmount;

        _unlock(user, lock, amount);

        if (transferredAmount > 0) {
            IERC20(wcConfig.getL2wct()).safeTransfer(user, transferredAmount);
        }

        emit Withdraw(user, amount, transferredAmount, block.timestamp);
    }

    function _unlock(address user, LockedBalance memory lock, uint256 withdrawAmount) internal {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        // Cast here for readability
        uint256 lockedAmount = SafeCast.toUint256(lock.amount);
        if (withdrawAmount > lockedAmount) {
            revert InsufficientLockedAmount(withdrawAmount, lockedAmount);
        }

        LockedBalance memory prevLock =
            LockedBalance({ end: lock.end, amount: lock.amount, transferredAmount: lock.transferredAmount });
        //lock.end should remain the same if we do partially withdraw
        lock.end = lockedAmount == withdrawAmount ? 0 : lock.end;
        lock.amount = SafeCast.toInt128(int256(lockedAmount - withdrawAmount));
        // reset transferredAmount to 0, as it's sent to user on _withdrawAll
        lock.transferredAmount = 0;
        s.locks[user] = lock;

        uint256 supplyBefore = s.supply;
        s.supply = supplyBefore - withdrawAmount;

        // prevLock can have either block.timstamp >= lock.end or zero end
        // lock has only 0 end
        // Both can have >= 0 amount
        _checkpoint(user, prevLock, lock);

        emit Supply(supplyBefore, s.supply);
    }

    /// @notice Set the maximum lock duration
    /// @param newMaxLock The maximum lock duration in seconds
    /// @dev The maximum lock duration is 209 weeks (4 years)
    /// @dev The maximum lock duration cannot be less than the current max lock duration to prevent bricking existing
    /// locks
    function setMaxLock(uint256 newMaxLock) external onlyRole(DEFAULT_ADMIN_ROLE) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        if (newMaxLock < s.maxLock || newMaxLock > MAX_LOCK_CAP) revert InvalidMaxLock(newMaxLock);
        emit MaxLockUpdated(s.maxLock, newMaxLock);
        s.maxLock = newMaxLock;
    }

    function maxLock() external view returns (uint256) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        return s.maxLock;
    }

    function epoch() external view returns (uint256) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        return s.epoch;
    }

    function pointHistory(uint256 epoch_) external view returns (Point memory) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        return s.pointHistory[epoch_];
    }

    function userPointHistory(address user, uint256 epoch_) external view returns (Point memory) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        return s.userPointHistory[user][epoch_];
    }

    function locks(address user) external view returns (LockedBalance memory) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        return s.locks[user];
    }

    function userPointEpoch(address user) external view returns (uint256) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        return s.userPointEpoch[user];
    }

    function slopeChanges(uint256 timestamp) external view returns (int128) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        return s.slopeChanges[timestamp];
    }

    function supply() external view returns (uint256) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        return s.supply;
    }

    function config() external view returns (WalletConnectConfig) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        return s.config;
    }
}
