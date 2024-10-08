// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { WalletConnectConfig } from "./WalletConnectConfig.sol";
import { StakeWeight } from "./StakeWeight.sol";
import { Math128 } from "./library/Math128.sol";

struct Point {
    int128 bias;
    int128 slope;
    uint256 timestamp;
    uint256 blockNumber;
}

interface IStakeWeight {
    /// @notice Calculate total supply of Stake Weight
    function totalSupply() external view returns (uint256);
    /// @notice Calculate total supply of Stake Weight at at specific timestamp
    function totalSupplyAtTime(uint256 _timestamp) external view returns (uint256);
    /// @notice Calculate total supply of Stake Weight at specific block
    function totalSupplyAt(uint256 _blockNumber) external view returns (uint256);
    /// @notice Return the voting weight of a given user
    function balanceOf(address _user) external view returns (uint256);
    /// @notice Return the balance of Stake Weight at a given "_blockNumber"
    function balanceOfAt(address _user, uint256 _blockNumber) external view returns (uint256);
    /// @notice Return the balance of Stake Weight at a given timestamp
    function balanceOfAtTime(address _user, uint256 _timestamp) external view returns (uint256);
    /// @notice Trigger global checkpoint
    function checkpoint() external;
    /// @notice Get the current epoch for a user
    function userPointEpoch(address _user) external view returns (uint256);
    /// @notice Get the current global epoch
    function epoch() external view returns (uint256);
    /// @notice Get a specific point from a user's point history
    function userPointHistory(address _user, uint256 _epoch) external view returns (StakeWeight.Point memory);
    /// @notice Get a specific point from the global point history
    function pointHistory(uint256 _epoch) external view returns (StakeWeight.Point memory);
}

contract StakingRewardDistributor is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    /// @dev Events
    event Feed(uint256 _amount);
    event CheckpointToken(uint256 _timestamp, uint256 _tokens);
    event Claimed(
        address indexed _user, address indexed _recipient, uint256 _amount, uint256 _claimEpoch, uint256 _maxEpoch
    );
    event Killed();
    event UpdateRecipient(
        address _owner, address indexed _user, address indexed _oldRecipient, address indexed _newRecipient
    );

    /// @dev Custom Errors
    error ContractKilled();
    error TooManyUsers();
    error InvalidUser();
    error InvalidConfig();
    error InvalidEmergencyReturn();
    error Unauthorized();

    uint256 public startWeekCursor;
    uint256 public weekCursor;
    mapping(address => uint256) public weekCursorOf;
    mapping(address => uint256) public userEpochOf;

    uint256 public lastTokenTimestamp;
    mapping(uint256 => uint256) public tokensPerWeek;

    WalletConnectConfig public config;
    uint256 public lastTokenBalance;

    uint256 public totalDistributed;

    /// @dev StakeWeight supply at week bounds
    mapping(uint256 => uint256) public totalSupplyAt;

    /// @dev User can set recipient address for claim
    mapping(address => address) public recipient;

    /// @dev address to get token when contract is emergency stop
    bool public isKilled;
    address public emergencyReturn;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    /// @notice Initialization parameters
    struct Init {
        /// @param admin Address of the admin
        address admin;
        /// @param startTime Start time for the distribution
        uint256 startTime;
        /// @param emergencyReturn Address for emergency return
        address emergencyReturn;
        /// @param config Address of the WalletConnectConfig contract
        address config;
    }

    /// @notice Initializes the contract
    /// @param _init Initialization parameters
    function initialize(Init memory _init) public initializer {
        __Ownable_init(_init.admin);
        __ReentrancyGuard_init();

        if (_init.config == address(0)) revert InvalidConfig();
        if (_init.emergencyReturn == address(0)) revert InvalidEmergencyReturn();
        config = WalletConnectConfig(_init.config);

        uint256 _startTimeFloorWeek = _timestampToFloorWeek(_init.startTime);
        startWeekCursor = _startTimeFloorWeek;
        lastTokenTimestamp = _startTimeFloorWeek;
        weekCursor = _startTimeFloorWeek;
        emergencyReturn = _init.emergencyReturn;
    }

    modifier onlyLive() {
        if (isKilled) revert ContractKilled();
        _;
    }

    /// @notice Get StakeWeight balance of "_user" at "_timestamp"
    /// @param _user The user address
    /// @param _timestamp The timestamp to get user's balance
    function balanceOfAt(address _user, uint256 _timestamp) external view returns (uint256) {
        IStakeWeight stakeWeight = IStakeWeight(config.getStakeWeight());
        uint256 _maxUserEpoch = stakeWeight.userPointEpoch(_user);
        if (_maxUserEpoch == 0) {
            return 0;
        }

        uint256 _epoch = _findTimestampUserEpoch(_user, _timestamp, _maxUserEpoch);
        StakeWeight.Point memory _point = stakeWeight.userPointHistory(_user, _epoch);
        int128 _bias = _point.bias - _point.slope * SafeCast.toInt128(int256(_timestamp - _point.timestamp));
        if (_bias < 0) {
            return 0;
        }
        return SafeCast.toUint256(_bias);
    }

    /// @notice Record token distribution checkpoint
    function _checkpointToken() internal {
        // Find out how many tokens to be distributed
        uint256 _rewardTokenBalance = IERC20(config.getL2wct()).balanceOf(address(this));
        uint256 _toDistribute = _rewardTokenBalance - lastTokenBalance;
        lastTokenBalance = _rewardTokenBalance;

        totalDistributed += _toDistribute;

        // Prepare and update time-related variables
        // 1. Setup _timeCursor to be the "lastTokenTimestamp"
        // 2. Find out how long from previous checkpoint
        // 3. Setup iterable cursor
        // 4. Update lastTokenTimestamp to be block.timestamp
        uint256 _timeCursor = lastTokenTimestamp;
        uint256 _deltaSinceLastTimestamp = block.timestamp - _timeCursor;
        uint256 _thisWeekCursor = _timestampToFloorWeek(_timeCursor);
        uint256 _nextWeekCursor = 0;
        lastTokenTimestamp = block.timestamp;

        // Iterate through weeks to filled out missing tokensPerWeek (if any)
        for (uint256 _i = 0; _i < 52; _i++) {
            _nextWeekCursor = _thisWeekCursor + 1 weeks;

            // if block.timestamp < _nextWeekCursor, means _nextWeekCursor goes
            // beyond the actual block.timestamp, hence it is the last iteration
            // to fill out tokensPerWeek
            if (block.timestamp < _nextWeekCursor) {
                if (_deltaSinceLastTimestamp == 0 && block.timestamp == _timeCursor) {
                    tokensPerWeek[_thisWeekCursor] = tokensPerWeek[_thisWeekCursor] + _toDistribute;
                } else {
                    tokensPerWeek[_thisWeekCursor] = tokensPerWeek[_thisWeekCursor]
                        + ((_toDistribute * (block.timestamp - _timeCursor)) / _deltaSinceLastTimestamp);
                }
                break;
            } else {
                if (_deltaSinceLastTimestamp == 0 && _nextWeekCursor == _timeCursor) {
                    tokensPerWeek[_thisWeekCursor] = tokensPerWeek[_thisWeekCursor] + _toDistribute;
                } else {
                    tokensPerWeek[_thisWeekCursor] = tokensPerWeek[_thisWeekCursor]
                        + ((_toDistribute * (_nextWeekCursor - _timeCursor)) / _deltaSinceLastTimestamp);
                }
            }
            _timeCursor = _nextWeekCursor;
            _thisWeekCursor = _nextWeekCursor;
        }

        emit CheckpointToken(block.timestamp, _toDistribute);
    }

    /// @notice Update token checkpoint
    /// @dev Calculate the total token to be distributed in a given week.
    function checkpointToken() external nonReentrant {
        _checkpointToken();
    }

    /// @notice Record StakeWeight total supply for each week
    function _checkpointTotalSupply() internal {
        IStakeWeight stakeWeight = IStakeWeight(config.getStakeWeight());
        uint256 _weekCursor = weekCursor;
        uint256 _roundedTimestamp = _timestampToFloorWeek(block.timestamp);

        stakeWeight.checkpoint();

        for (uint256 _i = 0; _i < 52; _i++) {
            if (_weekCursor > _roundedTimestamp) {
                break;
            } else {
                uint256 _epoch = _findTimestampEpoch(_weekCursor);
                StakeWeight.Point memory _point = stakeWeight.pointHistory(_epoch);
                int128 _timeDelta = 0;
                if (_weekCursor > _point.timestamp) {
                    _timeDelta = SafeCast.toInt128(int256(_weekCursor - _point.timestamp));
                }
                int128 _bias = _point.bias - _point.slope * _timeDelta;
                if (_bias < 0) {
                    totalSupplyAt[_weekCursor] = 0;
                } else {
                    totalSupplyAt[_weekCursor] = SafeCast.toUint256(_bias);
                }
            }
            _weekCursor = _weekCursor + 1 weeks;
        }

        weekCursor = _weekCursor;
    }

    /// @notice Update StakeWeight total supply checkpoint
    /// @dev This function can be called independently or at the first claim of
    /// the new epoch week.
    function checkpointTotalSupply() external nonReentrant {
        _checkpointTotalSupply();
    }

    /// @notice Claim rewardToken
    /// @dev Perform claim rewardToken
    function _claim(address _user, address _recipient, uint256 _maxClaimTimestamp) internal returns (uint256) {
        IStakeWeight stakeWeight = IStakeWeight(config.getStakeWeight());

        uint256 _userEpoch = 0;
        uint256 _toDistribute = 0;

        uint256 _maxUserEpoch = stakeWeight.userPointEpoch(_user);
        uint256 _startWeekCursor = startWeekCursor;

        // _maxUserEpoch = 0, meaning no lock.
        // Hence, no yield for _user
        if (_maxUserEpoch == 0) {
            return 0;
        }

        uint256 _userWeekCursor = weekCursorOf[_user];
        if (_userWeekCursor == 0) {
            // if _user has no _userWeekCursor with GrassHouse yet
            // then we need to perform binary search
            _userEpoch = _findTimestampUserEpoch(_user, _startWeekCursor, _maxUserEpoch);
        } else {
            // else, _user must has epoch with GrassHouse already
            _userEpoch = userEpochOf[_user];
        }

        if (_userEpoch == 0) {
            _userEpoch = 1;
        }

        StakeWeight.Point memory _userPoint = stakeWeight.userPointHistory(_user, _userEpoch);

        if (_userWeekCursor == 0) {
            _userWeekCursor = ((_userPoint.timestamp + 1 weeks - 1) / 1 weeks) * 1 weeks;
        }

        // _userWeekCursor is already at/beyond _maxClaimTimestamp
        // meaning nothing to be claimed for this user.
        // This can be:
        // 1) User just lock their WCT less than 1 week
        // 2) User already claimed their rewards
        if (_userWeekCursor >= _maxClaimTimestamp) {
            return 0;
        }

        // Handle when user lock WCT before StakeWeight started
        // by assign _userWeekCursor to StakeWeight's _startWeekCursor
        if (_userWeekCursor < _startWeekCursor) {
            _userWeekCursor = _startWeekCursor;
        }

        StakeWeight.Point memory _prevUserPoint = StakeWeight.Point({ bias: 0, slope: 0, timestamp: 0, blockNumber: 0 });

        // Go through weeks
        for (uint256 _i = 0; _i < 52; _i++) {
            // If _userWeekCursor is iterated to be at/beyond _maxClaimTimestamp
            // This means we went through all weeks that user subject to claim rewards already
            if (_userWeekCursor >= _maxClaimTimestamp) {
                break;
            }
            // Move to the new epoch if need to,
            // else calculate rewards that user should get.
            if (_userWeekCursor >= _userPoint.timestamp && _userEpoch <= _maxUserEpoch) {
                _userEpoch = _userEpoch + 1;
                _prevUserPoint = StakeWeight.Point({
                    bias: _userPoint.bias,
                    slope: _userPoint.slope,
                    timestamp: _userPoint.timestamp,
                    blockNumber: _userPoint.blockNumber
                });
                // When _userEpoch goes beyond _maxUserEpoch then there is no more Point,
                // else take _userEpoch as a new Point
                if (_userEpoch > _maxUserEpoch) {
                    _userPoint = StakeWeight.Point({ bias: 0, slope: 0, timestamp: 0, blockNumber: 0 });
                } else {
                    _userPoint = stakeWeight.userPointHistory(_user, _userEpoch);
                }
            } else {
                int128 _timeDelta = SafeCast.toInt128(int256(_userWeekCursor - _prevUserPoint.timestamp));
                uint256 _balanceOf =
                    SafeCast.toUint256(Math128.max(_prevUserPoint.bias - _timeDelta * _prevUserPoint.slope, 0));
                if (_balanceOf == 0 && _userEpoch > _maxUserEpoch) {
                    break;
                }
                if (_balanceOf > 0) {
                    _toDistribute =
                        _toDistribute + (_balanceOf * tokensPerWeek[_userWeekCursor]) / totalSupplyAt[_userWeekCursor];
                }
                _userWeekCursor = _userWeekCursor + 1 weeks;
            }
        }

        _userEpoch = Math128.min(_maxUserEpoch, _userEpoch - 1);
        userEpochOf[_user] = _userEpoch;
        weekCursorOf[_user] = _userWeekCursor;

        emit Claimed(_user, _recipient, _toDistribute, _userEpoch, _maxUserEpoch);

        return _toDistribute;
    }

    /// @notice Get claim recipient address
    /// @param _user The address to claim rewards for
    function getRecipient(address _user) public view returns (address _recipient) {
        _recipient = _user;

        address userRecipient = recipient[_recipient];
        if (userRecipient != address(0)) {
            _recipient = userRecipient;
        }
    }

    /// @notice Claim rewardToken for user and user's recipient
    /// @dev Need owner permission
    /// @param _recipient The recipient address will be claimed to
    function claimTo(address _recipient) external nonReentrant onlyLive returns (uint256) {
        return _claimWithCustomRecipient(msg.sender, _recipient);
    }

    /// @notice Claim rewardToken for user and user's recipient
    /// @dev Do not need owner permission
    /// @param _user The address to claim rewards for
    function claim(address _user) external nonReentrant onlyLive returns (uint256) {
        return _claimWithCustomRecipient(_user, address(0));
    }

    function _claimWithCustomRecipient(address _user, address _recipient) internal returns (uint256) {
        if (block.timestamp >= weekCursor) _checkpointTotalSupply();

        uint256 _lastTokenTimestamp = lastTokenTimestamp;

        _checkpointToken();
        _lastTokenTimestamp = block.timestamp;

        _lastTokenTimestamp = _timestampToFloorWeek(_lastTokenTimestamp);
        if (_recipient == address(0)) {
            _recipient = getRecipient(_user);
        }
        uint256 _total = _claim(_user, _recipient, _lastTokenTimestamp);
        if (_total != 0) {
            lastTokenBalance = lastTokenBalance - _total;
            IERC20(config.getL2wct()).safeTransfer(_recipient, _total);
        }

        return _total;
    }

    /// @notice Claim rewardToken for multiple users
    /// @param _users The array of addresses to claim reward for
    function claimMany(address[] calldata _users) external nonReentrant onlyLive returns (bool) {
        if (_users.length > 20) revert TooManyUsers();

        if (block.timestamp >= weekCursor) _checkpointTotalSupply();

        uint256 _lastTokenTimestamp = lastTokenTimestamp;

        _checkpointToken();
        _lastTokenTimestamp = block.timestamp;

        _lastTokenTimestamp = _timestampToFloorWeek(_lastTokenTimestamp);
        uint256 _total = 0;

        for (uint256 i = 0; i < _users.length; i++) {
            address _user = _users[i];
            if (_user == address(0)) revert InvalidUser();

            address _recipient = getRecipient(_user);
            uint256 _amount = _claim(_user, _recipient, _lastTokenTimestamp);

            if (_amount != 0) {
                IERC20(config.getL2wct()).safeTransfer(_recipient, _amount);
                _total = _total + _amount;
            }
        }

        if (_total != 0) {
            lastTokenBalance = lastTokenBalance - _total;
        }

        return true;
    }

    /// @notice Receive rewardTokens into the contract and trigger token checkpoint
    function feed(uint256 _amount) external nonReentrant onlyLive returns (bool) {
        IERC20(config.getL2wct()).safeTransferFrom(msg.sender, address(this), _amount);

        _checkpointToken();

        emit Feed(_amount);

        return true;
    }

    /// @notice Do Binary Search to find out epoch from timestamp
    /// @param _timestamp Timestamp to find epoch
    function _findTimestampEpoch(uint256 _timestamp) internal view returns (uint256) {
        IStakeWeight stakeWeight = IStakeWeight(config.getStakeWeight());

        uint256 _min = 0;
        uint256 _max = stakeWeight.epoch();
        // Loop for 128 times -> enough for 128-bit numbers
        for (uint256 i = 0; i < 128; i++) {
            if (_min >= _max) {
                break;
            }
            uint256 _mid = (_min + _max + 1) / 2;
            StakeWeight.Point memory _point = stakeWeight.pointHistory(_mid);
            if (_point.timestamp <= _timestamp) {
                _min = _mid;
            } else {
                _max = _mid - 1;
            }
        }
        return _min;
    }

    /// @notice Perform binary search to find out user's epoch from the given timestamp
    /// @param _user The user address
    /// @param _timestamp The timestamp that you wish to find out epoch
    /// @param _maxUserEpoch Max epoch to find out the timestamp
    function _findTimestampUserEpoch(
        address _user,
        uint256 _timestamp,
        uint256 _maxUserEpoch
    )
        internal
        view
        returns (uint256)
    {
        uint256 _min = 0;
        uint256 _max = _maxUserEpoch;
        for (uint256 i = 0; i < 128; i++) {
            if (_min >= _max) {
                break;
            }
            uint256 _mid = (_min + _max + 1) / 2;
            StakeWeight.Point memory _point = IStakeWeight(config.getStakeWeight()).userPointHistory(_user, _mid);
            if (_point.timestamp <= _timestamp) {
                _min = _mid;
            } else {
                _max = _mid - 1;
            }
        }
        return _min;
    }

    function kill() external onlyOwner {
        IERC20 rewardToken = IERC20(config.getL2wct());
        isKilled = true;
        rewardToken.safeTransfer(emergencyReturn, rewardToken.balanceOf(address(this)));

        emit Killed();
    }

    /// @notice Round off random timestamp to week
    /// @param _timestamp The timestamp to be rounded off
    function _timestampToFloorWeek(uint256 _timestamp) internal pure returns (uint256) {
        return (_timestamp / 1 weeks) * 1 weeks;
    }

    /// @notice Inject rewardToken into the contract
    /// @param _timestamp The timestamp of the rewardToken to be distributed
    /// @param _amount The amount of rewardToken to be distributed
    function injectReward(uint256 _timestamp, uint256 _amount) external onlyOwner {
        _injectReward(_timestamp, _amount);
    }

    /// @notice Inject rewardToken for currect week into the contract
    /// @param _amount The amount of rewardToken to be distributed
    function injectRewardForCurrentWeek(uint256 _amount) external onlyOwner {
        _injectReward(block.timestamp, _amount);
    }

    function _injectReward(uint256 _timestamp, uint256 _amount) internal {
        IERC20(config.getL2wct()).safeTransferFrom(msg.sender, address(this), _amount);
        lastTokenBalance += _amount;
        totalDistributed += _amount;
        uint256 weekTimestamp = _timestampToFloorWeek(_timestamp);
        tokensPerWeek[weekTimestamp] += _amount;
    }

    /// @notice Set recipient address
    /// @dev If the user address is not EOA, You can set recipient once , then owner will lose permission to set
    /// recipient for the user
    /// @param _user User address
    /// @param _recipient Recipient address
    function setRecipient(address _user, address _recipient) external {
        if (msg.sender != _user) {
            revert Unauthorized();
        }
        address oldRecipient = recipient[_user];
        recipient[_user] = _recipient;
        emit UpdateRecipient(msg.sender, _user, oldRecipient, _recipient);
    }
}
