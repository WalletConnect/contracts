// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { WalletConnectConfig } from "./WalletConnectConfig.sol";
import { Pauser } from "./Pauser.sol";
import { StorageSlot } from "@openzeppelin/contracts/utils/StorageSlot.sol";

/**
 * @dev This contract was inspired by Curve's veCRV and PancakeSwap's veCake implementations.
 * It implements a vote-escrowed token model for WCT (WalletConnect Token) to create
 * a staking mechanism with time-weighted power.
 */
contract StakeWeight is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////////////////
                                    STRUCTS
    //////////////////////////////////////////////////////////////////////////*/

    struct Point {
        int128 bias;
        int128 slope;
        uint256 timestamp;
        uint256 blockNumber;
    }

    struct LockedBalance {
        int128 amount;
        uint256 end;
    }

    struct Init {
        address admin;
        address config;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    // MAX_LOCK 209 weeks - 1 seconds
    uint256 public constant MAX_LOCK = (209 weeks) - 1;
    uint256 public constant MULTIPLIER = 1e18;

    /*//////////////////////////////////////////////////////////////////////////
                                    STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    // Define the storage namespace
    bytes32 constant STAKE_WEIGHT_STORAGE_POSITION = keccak256("com.walletconnect.stakeweight.storage");

    struct StakeWeightStorage {
        // Configuration for WalletConnect
        WalletConnectConfig config;
        // Total supply of WCT locked
        uint256 supply;
        // Mapping (user => LockedBalance) to keep locking information for each user
        mapping(address => LockedBalance) locks;
        // A global point of time
        uint256 epoch;
        // An array of points (global)
        Point[] pointHistory;
        // Mapping (user => Point[]) to keep track of user point of a given epoch (index of Point is epoch)
        mapping(address => Point[]) userPointHistory;
        // Mapping (user => epoch) to keep track which epoch user is at
        mapping(address => uint256) userPointEpoch;
        // Mapping (round off timestamp to week => slopeDelta) to keep track of slope changes over epoch
        mapping(uint256 => int128) slopeChanges;
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

    event Deposit(address indexed provider, uint256 value, uint256 locktime, uint256 type_, uint256 timestamp);
    event Withdraw(address indexed provider, uint256 value, uint256 timestamp);
    event Supply(uint256 previousSupply, uint256 newSupply);

    /*//////////////////////////////////////////////////////////////////////////
                                    ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    error InvalidInput();
    error InvalidAmount(uint256 amount);
    error InvalidAddress();
    error InvalidLockState();
    error InvalidUnlockTime(uint256 unlockTime);
    error ExpiredLock(uint256 currentTime, uint256 lockEndTime);
    error VotingLockMaxExceeded();
    error CanOnlyIncreaseLockDuration();
    error AmountTooLarge(uint256 attemptedAmount, uint256 maxAllowedAmount);
    error BadBlockNumber(uint256 blockNumber);
    error InsufficientBalance(uint256 requiredBalance, uint256 actualBalance);
    error Paused();

    uint256 public constant ACTION_DEPOSIT_FOR = 0;
    uint256 public constant ACTION_CREATE_LOCK = 1;
    uint256 public constant ACTION_INCREASE_LOCK_AMOUNT = 2;
    uint256 public constant ACTION_INCREASE_UNLOCK_TIME = 3;

    /*//////////////////////////////////////////////////////////////////////////
                                INITIALIZER
    //////////////////////////////////////////////////////////////////////////*/

    function initialize(Init memory init) external initializer {
        __Ownable_init(init.admin);
        __ReentrancyGuard_init();
        if (init.config == address(0)) revert InvalidInput();

        StakeWeightStorage storage s = _getStakeWeightStorage();
        s.config = WalletConnectConfig(init.config);

        s.pointHistory.push(Point({ bias: 0, slope: 0, timestamp: block.timestamp, blockNumber: block.number }));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Return the balance of Stake Weight at a given "_blockNumber"
    /// @param _user The address to get a balance of Stake Weight
    /// @param _blockNumber The specific block number that you want to check the balance of Stake Weight
    function balanceOfAt(address _user, uint256 _blockNumber) external view returns (uint256) {
        return _balanceOfAt(_user, _blockNumber);
    }

    function _balanceOfAt(address _user, uint256 _blockNumber) internal view returns (uint256) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        // Get most recent user Point to block
        uint256 _userEpoch = _findUserBlockEpoch(_user, _blockNumber);
        if (_userEpoch == 0) {
            return 0;
        }
        Point memory _userPoint = s.userPointHistory[_user][_userEpoch];

        // Get most recent global point to block
        uint256 _maxEpoch = s.epoch;
        uint256 _epoch = _findBlockEpoch(_blockNumber, _maxEpoch);
        Point memory _point0 = s.pointHistory[_epoch];

        uint256 _blockDelta = 0;
        uint256 _timeDelta = 0;
        if (_epoch < _maxEpoch) {
            Point memory _point1 = s.pointHistory[_epoch + 1];
            _blockDelta = _point1.blockNumber - _point0.blockNumber;
            _timeDelta = _point1.timestamp - _point0.timestamp;
        } else {
            _blockDelta = block.number - _point0.blockNumber;
            _timeDelta = block.timestamp - _point0.timestamp;
        }
        uint256 _blockTime = _point0.timestamp;
        if (_blockDelta != 0) {
            _blockTime += (_timeDelta * (_blockNumber - _point0.blockNumber)) / _blockDelta;
        }

        _userPoint.bias -= (_userPoint.slope * SafeCast.toInt128(int256(_blockTime - _userPoint.timestamp)));

        if (_userPoint.bias < 0) {
            return 0;
        }

        return SafeCast.toUint256(_userPoint.bias);
    }

    /// @notice Return the voting weight of a givne user
    /// @param _user The address of a user
    function balanceOf(address _user) external view returns (uint256) {
        return _balanceOf(_user, block.timestamp);
    }
    /// @notice Calculate the stake weight of a user at a specific timestamp
    /// @dev This function is primarily designed for calculating future balances.
    ///      CAUTION: It will revert due to underflow for timestamps before the user's last checkpoint.
    ///      This behavior is intentional and should be carefully considered when calling this function.
    ///      - For timestamps > last checkpoint: Projects future balance based on current slope
    ///      - For timestamps == last checkpoint: Returns current balance
    ///      - For timestamps < last checkpoint: Reverts due to underflow
    ///      Use with care in contract interactions and consider implementing try/catch for calls to this function.
    /// @param _user The address of the user to check
    /// @param _timestamp The timestamp to check the stake weight at
    /// @return The user's projected stake weight at the specified timestamp

    function balanceOfAtTime(address _user, uint256 _timestamp) external view returns (uint256) {
        return _balanceOf(_user, _timestamp);
    }

    function _balanceOf(address _user, uint256 _timestamp) internal view returns (uint256) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        uint256 _epoch = s.userPointEpoch[_user];
        if (_epoch == 0) {
            return 0;
        }
        Point memory _lastPoint = s.userPointHistory[_user][_epoch];
        _lastPoint.bias =
            _lastPoint.bias - (_lastPoint.slope * SafeCast.toInt128(int256(_timestamp - _lastPoint.timestamp)));
        if (_lastPoint.bias < 0) {
            _lastPoint.bias = 0;
        }
        return SafeCast.toUint256(_lastPoint.bias);
    }

    /// @notice Record global and per-user slope to checkpoint
    /// @param _address User's wallet address. Only global if 0x0
    /// @param _prevLocked User's previous locked balance and end lock time
    /// @param _newLocked User's new locked balance and end lock time
    function _checkpoint(
        address _address,
        LockedBalance memory _prevLocked,
        LockedBalance memory _newLocked
    )
        internal
    {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        Point memory _userPrevPoint = Point({ slope: 0, bias: 0, timestamp: 0, blockNumber: 0 });
        Point memory _userNewPoint = Point({ slope: 0, bias: 0, timestamp: 0, blockNumber: 0 });

        int128 _prevSlopeDelta = 0;
        int128 _newSlopeDelta = 0;
        uint256 _epoch = s.epoch;

        // if not 0x0, then update user's point
        if (_address != address(0)) {
            // Calculate slopes and biases according to linear decay graph
            // slope = lockedAmount / MAX_LOCK => Get the slope of a linear decay graph
            // bias = slope * (lockedEnd - currentTimestamp) => Get the voting weight at a given time
            // Kept at zero when they have to
            if (_prevLocked.end > block.timestamp && _prevLocked.amount > 0) {
                // Calculate slope and bias for the prev point
                _userPrevPoint.slope = _prevLocked.amount / SafeCast.toInt128(int256(MAX_LOCK));
                _userPrevPoint.bias =
                    _userPrevPoint.slope * SafeCast.toInt128(int256(_prevLocked.end - block.timestamp));
            }
            if (_newLocked.end > block.timestamp && _newLocked.amount > 0) {
                // Calculate slope and bias for the new point
                _userNewPoint.slope = _newLocked.amount / SafeCast.toInt128(int256(MAX_LOCK));
                _userNewPoint.bias = _userNewPoint.slope * SafeCast.toInt128(int256(_newLocked.end - block.timestamp));
            }

            // Handle user history here
            // Do it here to prevent stack overflow
            uint256 _userEpoch = s.userPointEpoch[_address];
            // If user never ever has any point history, push it here for him.
            if (_userEpoch == 0) {
                s.userPointHistory[_address].push(_userPrevPoint);
            }

            // Shift user's epoch by 1 as we are writing a new point for a user
            s.userPointEpoch[_address] = _userEpoch + 1;

            // Update timestamp & block number then push new point to user's history
            _userNewPoint.timestamp = block.timestamp;
            _userNewPoint.blockNumber = block.number;
            s.userPointHistory[_address].push(_userNewPoint);

            // Read values of scheduled changes in the slope
            // _prevLocked.end can be in the past and in the future
            // _newLocked.end can ONLY be in the FUTURE unless everything expired (anything more than zeros)
            _prevSlopeDelta = s.slopeChanges[_prevLocked.end];
            if (_newLocked.end != 0) {
                // Handle when _newLocked.end != 0
                if (_newLocked.end == _prevLocked.end) {
                    // This will happen when user adjust lock but end remains the same
                    // Possibly when user deposited more WCT to his locker
                    _newSlopeDelta = _prevSlopeDelta;
                } else {
                    // This will happen when user increase lock
                    _newSlopeDelta = s.slopeChanges[_newLocked.end];
                }
            }
        }

        // Handle global states here
        Point memory _lastPoint = Point({ bias: 0, slope: 0, timestamp: block.timestamp, blockNumber: block.number });
        if (_epoch > 0) {
            // If _epoch > 0, then there is some history written
            // Hence, _lastPoint should be pointHistory[_epoch]
            // else _lastPoint should an empty point
            _lastPoint = s.pointHistory[_epoch];
        }
        // _lastCheckpoint => timestamp of the latest point
        // if no history, _lastCheckpoint should be block.timestamp
        // else _lastCheckpoint should be the timestamp of latest pointHistory
        uint256 _lastCheckpoint = _lastPoint.timestamp;

        // initialLastPoint is used for extrapolation to calculate block number
        // (approximately, for xxxAt methods) and save them
        // as we cannot figure that out exactly from inside contract
        Point memory _initialLastPoint =
            Point({ bias: 0, slope: 0, timestamp: _lastPoint.timestamp, blockNumber: _lastPoint.blockNumber });

        // If last point is already recorded in this block, _blockSlope=0
        // That is ok because we know the block in such case
        uint256 _blockSlope = 0;
        if (block.timestamp > _lastPoint.timestamp) {
            // Recalculate _blockSlope if _lastPoint.timestamp < block.timestamp
            // Possiblity when epoch = 0 or _blockSlope hasn't get updated in this block
            _blockSlope =
                (MULTIPLIER * (block.number - _lastPoint.blockNumber)) / (block.timestamp - _lastPoint.timestamp);
        }

        // Go over weeks to fill history and calculate what the current point is
        uint256 _weekCursor = _timestampToFloorWeek(_lastCheckpoint);
        for (uint256 i = 0; i < 255; i++) {
            // This logic will works for 5 years, if more than that vote power will be broken 😟
            // Bump _weekCursor a week
            _weekCursor = _weekCursor + 1 weeks;
            int128 _slopeDelta = 0;
            if (_weekCursor > block.timestamp) {
                // If the given _weekCursor go beyond block.timestamp,
                // We take block.timestamp as the cursor
                _weekCursor = block.timestamp;
            } else {
                // If the given _weekCursor is behind block.timestamp
                // We take _slopeDelta from the recorded slopeChanges
                // We can use _weekCursor directly because key of slopeChanges is timestamp round off to week
                _slopeDelta = s.slopeChanges[_weekCursor];
            }
            // Calculate _biasDelta = _lastPoint.slope * (_weekCursor - _lastCheckpoint)
            int128 _biasDelta = _lastPoint.slope * SafeCast.toInt128(int256((_weekCursor - _lastCheckpoint)));
            _lastPoint.bias = _lastPoint.bias - _biasDelta;
            _lastPoint.slope = _lastPoint.slope + _slopeDelta;
            if (_lastPoint.bias < 0) {
                // This can happen
                _lastPoint.bias = 0;
            }
            if (_lastPoint.slope < 0) {
                // This cannot happen, just make sure
                _lastPoint.slope = 0;
            }
            // Update _lastPoint to the new one
            _lastCheckpoint = _weekCursor;
            _lastPoint.timestamp = _weekCursor;
            // As we cannot figure that out block timestamp -> block number exactly
            // when query states from xxxAt methods, we need to calculate block number
            // based on _initalLastPoint
            _lastPoint.blockNumber = _initialLastPoint.blockNumber
                + ((_blockSlope * ((_weekCursor - _initialLastPoint.timestamp))) / MULTIPLIER);
            _epoch = _epoch + 1;
            if (_weekCursor == block.timestamp) {
                // Hard to be happened, but better handling this case too
                _lastPoint.blockNumber = block.number;
                break;
            } else {
                s.pointHistory.push(_lastPoint);
            }
        }
        // Now, each week pointHistory has been filled until current timestamp (round off by week)
        // Update epoch to be the latest state
        s.epoch = _epoch;

        if (_address != address(0)) {
            // If the last point was in the block, the slope change should have been applied already
            // But in such case slope shall be 0
            _lastPoint.slope = _lastPoint.slope + _userNewPoint.slope - _userPrevPoint.slope;
            _lastPoint.bias = _lastPoint.bias + _userNewPoint.bias - _userPrevPoint.bias;
            if (_lastPoint.slope < 0) {
                _lastPoint.slope = 0;
            }
            if (_lastPoint.bias < 0) {
                _lastPoint.bias = 0;
            }
        }

        // Record the new point to pointHistory
        // This would be the latest point for global epoch
        s.pointHistory.push(_lastPoint);

        if (_address != address(0)) {
            // Schedule the slope changes (slope is going downward)
            // We substract _newSlopeDelta from `_newLocked.end`
            // and add _prevSlopeDelta to `_prevLocked.end`
            if (_prevLocked.end > block.timestamp) {
                // _prevSlopeDelta was <something> - _userPrevPoint.slope, so we offset that first
                _prevSlopeDelta = _prevSlopeDelta + _userPrevPoint.slope;
                if (_newLocked.end == _prevLocked.end) {
                    // Handle the new deposit. Not increasing lock.
                    _prevSlopeDelta = _prevSlopeDelta - _userNewPoint.slope;
                }
                s.slopeChanges[_prevLocked.end] = _prevSlopeDelta;
            }
            if (_newLocked.end > block.timestamp) {
                if (_newLocked.end > _prevLocked.end) {
                    // At this line, the old slope should gone
                    _newSlopeDelta = _newSlopeDelta - _userNewPoint.slope;
                    s.slopeChanges[_newLocked.end] = _newSlopeDelta;
                }
            }
        }
    }

    /// @notice Trigger global checkpoint
    function checkpoint() external {
        LockedBalance memory empty = LockedBalance({ amount: 0, end: 0 });
        _checkpoint(address(0), empty, empty);
    }

    /// @notice Create a new lock.
    /// @dev This will crate a new lock and deposit WCT to Stake Weight Vault
    /// @param _amount the amount that user wishes to deposit
    /// @param _unlockTime the timestamp when WCT get unlocked, it will be
    /// floored down to whole weeks
    function createLock(uint256 _amount, uint256 _unlockTime) external nonReentrant {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        if (Pauser(s.config.getPauser()).isStakeWeightPaused()) revert Paused();
        _createLock(_amount, _unlockTime);
    }

    function _createLock(uint256 _amount, uint256 _unlockTime) internal {
        _unlockTime = _timestampToFloorWeek(_unlockTime);
        StakeWeightStorage storage s = _getStakeWeightStorage();
        LockedBalance memory _locked = s.locks[msg.sender];

        if (_amount <= 0) revert InvalidAmount(_amount);
        if (_locked.amount != 0) revert InvalidLockState();
        if (_unlockTime <= block.timestamp) revert InvalidUnlockTime(_unlockTime);
        if (_unlockTime > block.timestamp + MAX_LOCK) revert VotingLockMaxExceeded();

        _depositFor(msg.sender, _amount, _unlockTime, _locked, ACTION_CREATE_LOCK);
    }
    /// @notice Deposit `_amount` tokens for `_for` and add to `locks[_for]`
    /// @dev This function is used for deposit to created lock. Not for extend locktime.
    /// @param _for The address to do the deposit
    /// @param _amount The amount that user wishes to deposit

    function depositFor(address _for, uint256 _amount) external nonReentrant {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        if (Pauser(s.config.getPauser()).isStakeWeightPaused()) revert Paused();
        LockedBalance memory _lock = LockedBalance({ amount: s.locks[_for].amount, end: s.locks[_for].end });

        if (_for == address(0)) revert InvalidAddress();
        if (_amount == 0) revert InvalidAmount(_amount);
        if (_lock.amount == 0) revert InvalidLockState();
        if (_lock.end <= block.timestamp) revert ExpiredLock(block.timestamp, _lock.end);

        _depositFor(_for, _amount, 0, _lock, ACTION_DEPOSIT_FOR);
    }

    /// @notice Internal function to perform deposit and lock WCT for a user
    /// @param _for The address to be locked and received Stake Weight
    /// @param _amount The amount to deposit
    /// @param _unlockTime New time to unlock WCT. Pass 0 if no change.
    /// @param _prevLocked Existed locks[_for]
    /// @param _actionType The action that user did as this internal function shared among
    function _depositFor(
        address _for,
        uint256 _amount,
        uint256 _unlockTime,
        LockedBalance memory _prevLocked,
        uint256 _actionType
    )
        internal
    {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        // Initiate _supplyBefore & update supply
        uint256 _supplyBefore = s.supply;
        s.supply = _supplyBefore + _amount;

        // Store _prevLocked
        LockedBalance memory _newLocked = LockedBalance({ amount: _prevLocked.amount, end: _prevLocked.end });

        // Adding new lock to existing lock, or if lock is expired
        // - creating a new one
        _newLocked.amount = _newLocked.amount + SafeCast.toInt128(int256(_amount));
        if (_unlockTime != 0) {
            _newLocked.end = _unlockTime;
        }
        s.locks[_for] = _newLocked;

        // Handling checkpoint here
        _checkpoint(_for, _prevLocked, _newLocked);

        IERC20(s.config.getL2wct()).safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposit(_for, _amount, _newLocked.end, _actionType, block.timestamp);
        emit Supply(_supplyBefore, s.supply);
    }

    /// @notice Do Binary Search to find out block timestamp for block number
    /// @param _blockNumber The block number to find timestamp
    /// @param _maxEpoch No beyond this timestamp
    function _findBlockEpoch(uint256 _blockNumber, uint256 _maxEpoch) internal view returns (uint256) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        uint256 _min = 0;
        uint256 _max = _maxEpoch;
        // Loop for 128 times -> enough for 128-bit numbers
        for (uint256 i = 0; i < 128; i++) {
            if (_min >= _max) {
                break;
            }
            uint256 _mid = (_min + _max + 1) / 2;
            if (s.pointHistory[_mid].blockNumber <= _blockNumber) {
                _min = _mid;
            } else {
                _max = _mid - 1;
            }
        }
        return _min;
    }

    /// @notice Do Binary Search to find the most recent user point history preceeding block
    /// @param _user The address of user to find
    /// @param _blockNumber Find the most recent point history before this block number
    function _findUserBlockEpoch(address _user, uint256 _blockNumber) internal view returns (uint256) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        uint256 _min = 0;
        uint256 _max = s.userPointEpoch[_user];
        for (uint256 i = 0; i < 128; i++) {
            if (_min >= _max) {
                break;
            }
            uint256 _mid = (_min + _max + 1) / 2;
            if (s.userPointHistory[_user][_mid].blockNumber <= _blockNumber) {
                _min = _mid;
            } else {
                _max = _mid - 1;
            }
        }
        return _min;
    }

    /// @notice Increase lock amount without increase "end"
    /// @param _amount The amount of WCT to be added to the lock
    function increaseLockAmount(uint256 _amount) external nonReentrant {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        if (Pauser(s.config.getPauser()).isStakeWeightPaused()) revert Paused();
        LockedBalance memory _lock = s.locks[msg.sender];
        if (_amount == 0) revert InvalidAmount(_amount);
        if (_lock.amount == 0) revert InvalidLockState();
        if (_lock.end <= block.timestamp) revert ExpiredLock(block.timestamp, _lock.end);
        _depositFor(msg.sender, _amount, 0, _lock, ACTION_INCREASE_LOCK_AMOUNT);
    }

    /// @notice Increase unlock time without changing locked amount
    /// @param _newUnlockTime The new unlock time to be updated
    function increaseUnlockTime(uint256 _newUnlockTime) external nonReentrant {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        if (Pauser(s.config.getPauser()).isStakeWeightPaused()) revert Paused();
        LockedBalance memory _locked = s.locks[msg.sender];
        _newUnlockTime = _timestampToFloorWeek(_newUnlockTime);
        if (_locked.amount == 0) revert InvalidLockState();
        if (_locked.end <= block.timestamp) revert ExpiredLock(block.timestamp, _locked.end);
        if (_newUnlockTime <= _locked.end) revert CanOnlyIncreaseLockDuration();
        if (_newUnlockTime > block.timestamp + MAX_LOCK) revert VotingLockMaxExceeded();
        _depositFor(msg.sender, 0, _newUnlockTime, _locked, ACTION_INCREASE_UNLOCK_TIME);
    }

    /// @notice Round off random timestamp to week
    /// @param _timestamp The timestamp to be rounded off
    function _timestampToFloorWeek(uint256 _timestamp) internal pure returns (uint256) {
        return (_timestamp / 1 weeks) * 1 weeks;
    }

    /// @notice Calculate total supply of Stake Weight
    function totalSupply() external view returns (uint256) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        return _totalSupplyAt(s.pointHistory[s.epoch], block.timestamp);
    }

    /// @notice Calculate total supply of Stake Weight at at specific timestamp
    /// @param _timestamp The specific timestamp to calculate totalSupply
    function totalSupplyAtTime(uint256 _timestamp) external view returns (uint256) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        return _totalSupplyAt(s.pointHistory[s.epoch], _timestamp);
    }

    /// @notice Calculate total supply of Stake Weight at specific block
    /// @param _blockNumber The specific block number to calculate totalSupply
    function totalSupplyAt(uint256 _blockNumber) external view returns (uint256) {
        if (_blockNumber > block.number) revert BadBlockNumber(_blockNumber);
        StakeWeightStorage storage s = _getStakeWeightStorage();
        uint256 _epoch = s.epoch;
        uint256 _targetEpoch = _findBlockEpoch(_blockNumber, _epoch);

        Point memory _point = s.pointHistory[_targetEpoch];
        uint256 _timeDelta = 0;
        if (_targetEpoch < _epoch) {
            Point memory _nextPoint = s.pointHistory[_targetEpoch + 1];
            if (_point.blockNumber != _nextPoint.blockNumber) {
                _timeDelta = ((_blockNumber - _point.blockNumber) * (_nextPoint.timestamp - _point.timestamp))
                    / (_nextPoint.blockNumber - _point.blockNumber);
            }
        } else {
            if (_point.blockNumber != block.number) {
                _timeDelta = ((_blockNumber - _point.blockNumber) * (block.timestamp - _point.timestamp))
                    / (block.number - _point.blockNumber);
            }
        }

        return _totalSupplyAt(_point, _point.timestamp + _timeDelta);
    }

    /// @notice Calculate total supply of Stake Weight at some point in the past
    /// @param _point The point to start to search from
    /// @param _timestamp The timestamp to calculate the total voting power at
    function _totalSupplyAt(Point memory _point, uint256 _timestamp) internal view returns (uint256) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        Point memory _lastPoint = _point;
        uint256 _weekCursor = _timestampToFloorWeek(_point.timestamp);
        // Iterate through weeks to take slopChanges into the account
        for (uint256 i = 0; i < 255; i++) {
            _weekCursor = _weekCursor + 1 weeks;
            int128 _slopeDelta = 0;
            if (_weekCursor > _timestamp) {
                // If _weekCursor goes beyond _timestamp -> leave _slopeDelta
                // to be 0 as there is no more slopeChanges
                _weekCursor = _timestamp;
            } else {
                // If _weekCursor still behind _timestamp, then _slopeDelta
                // should be taken into the account.
                _slopeDelta = s.slopeChanges[_weekCursor];
            }
            // Update bias at _weekCursor
            _lastPoint.bias =
                _lastPoint.bias - (_lastPoint.slope * SafeCast.toInt128(int256(_weekCursor - _lastPoint.timestamp)));
            if (_weekCursor == _timestamp) {
                break;
            }
            // Update slope and timestamp
            _lastPoint.slope = _lastPoint.slope + _slopeDelta;
            _lastPoint.timestamp = _weekCursor;
        }

        if (_lastPoint.bias < 0) {
            _lastPoint.bias = 0;
        }

        return SafeCast.toUint256(_lastPoint.bias);
    }

    /// @notice Withdraw all WCT when lock has expired.
    function withdrawAll() external nonReentrant {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        WalletConnectConfig config = s.config;
        if (Pauser(config.getPauser()).isStakeWeightPaused()) revert Paused();
        LockedBalance memory _lock = s.locks[msg.sender];
        if (_lock.amount == 0) revert InvalidLockState();
        if (_lock.end > block.timestamp) revert InvalidLockState();

        uint256 _amount = SafeCast.toUint256(_lock.amount);

        _unlock(msg.sender, _lock, _amount);

        IERC20(config.getL2wct()).safeTransfer(msg.sender, _amount);

        emit Withdraw(msg.sender, _amount, block.timestamp);
    }

    function _unlock(address _user, LockedBalance memory _lock, uint256 _withdrawAmount) internal {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        // Cast here for readability
        uint256 _lockedAmount = SafeCast.toUint256(_lock.amount);
        if (_withdrawAmount > _lockedAmount) {
            revert AmountTooLarge(_withdrawAmount, _lockedAmount);
        }

        LockedBalance memory _prevLock = LockedBalance({ end: _lock.end, amount: _lock.amount });
        //_lock.end should remain the same if we do partially withdraw
        _lock.end = _lockedAmount == _withdrawAmount ? 0 : _lock.end;
        _lock.amount = SafeCast.toInt128(int256(_lockedAmount - _withdrawAmount));
        s.locks[_user] = _lock;

        uint256 _supplyBefore = s.supply;
        s.supply = _supplyBefore - _withdrawAmount;

        // _prevLock can have either block.timstamp >= _lock.end or zero end
        // _lock has only 0 end
        // Both can have >= 0 amount
        _checkpoint(_user, _prevLock, _lock);

        emit Supply(_supplyBefore, s.supply);
    }

    // Getters

    function epoch() external view returns (uint256) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        return s.epoch;
    }

    function pointHistory(uint256 _epoch) external view returns (int128, int128, uint256, uint256) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        Point memory point = s.pointHistory[_epoch];
        return (point.bias, point.slope, point.timestamp, point.blockNumber);
    }

    function userPointHistory(address _user, uint256 _epoch) external view returns (int128, int128, uint256, uint256) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        Point memory point = s.userPointHistory[_user][_epoch];
        return (point.bias, point.slope, point.timestamp, point.blockNumber);
    }

    function locks(address _user) external view returns (int128, uint256) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        LockedBalance memory lock = s.locks[_user];
        return (lock.amount, lock.end);
    }

    function userPointEpoch(address _user) external view returns (uint256) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        return s.userPointEpoch[_user];
    }

    function slopeChanges(uint256 _timestamp) external view returns (int128) {
        StakeWeightStorage storage s = _getStakeWeightStorage();
        return s.slopeChanges[_timestamp];
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
