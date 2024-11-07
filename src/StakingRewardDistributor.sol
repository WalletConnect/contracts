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

/**
 * @title StakingRewardDistributor
 * @notice This contract manages the distribution of staking rewards for the WalletConnect token.
 * @dev Implements a weekly reward distribution system based on user stake weights (inspired by Curve's FeeDistributor
 * and PancakeSwap's RevenueSharingPool)
 * @author WalletConnect
 */
contract StakingRewardDistributor is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    /// @notice Emitted when the contract is killed and emergency return is triggered
    event Killed();

    /// @notice Emitted when tokens are added to the contract
    event Fed(uint256 amount);

    /// @notice Emitted when a token checkpoint is created
    event TokenCheckpointed(uint256 timestamp, uint256 tokens);

    /// @notice Emitted when rewards are claimed
    event RewardsClaimed(
        address indexed user, address indexed recipient, uint256 amount, uint256 claimEpoch, uint256 maxEpoch
    );

    /// @notice Emitted when a user updates their recipient address
    /// @param user The user who updated their recipient
    /// @param oldRecipient The previous recipient address
    /// @param newRecipient The new recipient address
    event RecipientUpdated(address indexed user, address indexed oldRecipient, address indexed newRecipient);

    /// @notice Thrown when attempting to interact with a killed contract
    error ContractKilled();

    /// @notice Thrown when the number of users exceeds the maximum allowed
    error TooManyUsers();

    /// @notice Thrown when an invalid user address is provided
    error InvalidUser();

    /// @notice Thrown when an invalid configuration is provided
    error InvalidConfig();

    /// @notice Thrown when an invalid emergency return address is provided
    error InvalidEmergencyReturn();

    /// @notice Thrown when an unauthorized action is attempted
    error Unauthorized();

    /// @notice The starting week cursor for the distribution
    uint256 public startWeekCursor;

    /// @notice The current week cursor for the distribution
    uint256 public weekCursor;

    /// @notice Mapping of user addresses to their individual week cursors
    mapping(address account => uint256 weekCursor) public weekCursorOf;

    /// @notice Mapping of user addresses to their current epoch
    mapping(address account => uint256 userEpoch) public userEpochOf;

    /// @notice Timestamp of the last token distribution
    uint256 public lastTokenTimestamp;

    /// @notice Mapping of weeks to the number of tokens distributed in that week
    mapping(uint256 week => uint256 tokens) public tokensPerWeek;

    /// @notice The WalletConnectConfig contract instance
    WalletConnectConfig public config;

    /// @notice The balance of tokens at the last distribution
    uint256 public lastTokenBalance;

    /// @notice The total number of tokens distributed so far
    uint256 public totalDistributed;

    /// @notice Mapping of weeks to the total StakeWeight supply at that week's bounds
    mapping(uint256 => uint256) public totalSupplyAt;

    /// @notice Mapping of user addresses to their designated recipient addresses for claims
    /// @dev User can set recipient address for claim
    mapping(address => address) public recipient;

    /// @notice Flag indicating whether the contract has been killed
    bool public isKilled;

    /// @notice Address to receive tokens when the contract is emergency stopped
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
    /// @param init Initialization parameters
    function initialize(Init memory init) public initializer {
        __Ownable_init(init.admin);
        __ReentrancyGuard_init();

        if (init.config == address(0)) revert InvalidConfig();
        if (init.emergencyReturn == address(0)) revert InvalidEmergencyReturn();
        config = WalletConnectConfig(init.config);

        uint256 startTimeFloorWeek = _timestampToFloorWeek(init.startTime);
        startWeekCursor = startTimeFloorWeek;
        lastTokenTimestamp = startTimeFloorWeek;
        weekCursor = startTimeFloorWeek;
        emergencyReturn = init.emergencyReturn;
    }

    modifier onlyLive() {
        if (isKilled) revert ContractKilled();
        _;
    }

    /// @notice Get StakeWeight balance of "user" at "timestamp"
    /// @param user The user address
    /// @param timestamp The timestamp to get user's balance
    function balanceOfAt(address user, uint256 timestamp) external view returns (uint256) {
        StakeWeight stakeWeight = StakeWeight(config.getStakeWeight());
        uint256 maxUserEpoch = stakeWeight.userPointEpoch(user);
        if (maxUserEpoch == 0) {
            return 0;
        }

        uint256 epoch = _findTimestampUserEpoch(user, timestamp, maxUserEpoch);
        StakeWeight.Point memory point = stakeWeight.userPointHistory(user, epoch);
        int128 bias = point.bias - point.slope * SafeCast.toInt128(int256(timestamp - point.timestamp));
        if (bias < 0) {
            return 0;
        }
        return SafeCast.toUint256(bias);
    }

    /// @notice Record token distribution checkpoint
    /**
     * @dev Checkpoints and distributes tokens across weeks since the last checkpoint.
     *
     * Key points:
     * - Distribution starts from lastTokenTimestamp and goes up to current block.timestamp
     * - Tokens are distributed proportionally across all affected weeks
     * - Handles partial weeks at the start and end of the distribution period
     * - Total distributed always matches input amount, regardless of time elapsed (considering rounding errors)
     *
     * Key variables:
     * timeCursor: Tracks current position in time during week iterations
     * deltaSinceLastTimestamp: Total time since last checkpoint, used for proportions
     * thisWeekCursor: Start of the current week being processed
     */
    function _checkpointToken() internal {
        // Find out how many tokens to be distributed
        uint256 rewardTokenBalance = IERC20(config.getL2wct()).balanceOf(address(this));
        uint256 toDistribute = rewardTokenBalance - lastTokenBalance;
        lastTokenBalance = rewardTokenBalance;

        totalDistributed += toDistribute;

        // Prepare and update time-related variables
        // 1. Setup timeCursor to be the "lastTokenTimestamp"
        // 2. Find out how long from previous checkpoint
        // 3. Setup iterable cursor
        // 4. Update lastTokenTimestamp to be block.timestamp
        uint256 timeCursor = lastTokenTimestamp;
        uint256 deltaSinceLastTimestamp = block.timestamp - timeCursor;
        uint256 thisWeekCursor = _timestampToFloorWeek(timeCursor);
        uint256 nextWeekCursor = 0;
        lastTokenTimestamp = block.timestamp;

        // Iterate through weeks to filled out missing tokensPerWeek (if any)
        for (uint256 i = 0; i < 52; i++) {
            nextWeekCursor = thisWeekCursor + 1 weeks;

            // if block.timestamp < nextWeekCursor, means nextWeekCursor goes
            // beyond the actual block.timestamp, hence it is the last iteration
            // to fill out tokensPerWeek
            if (block.timestamp < nextWeekCursor) {
                if (deltaSinceLastTimestamp == 0 && block.timestamp == timeCursor) {
                    tokensPerWeek[thisWeekCursor] = tokensPerWeek[thisWeekCursor] + toDistribute;
                } else {
                    tokensPerWeek[thisWeekCursor] = tokensPerWeek[thisWeekCursor]
                        + ((toDistribute * (block.timestamp - timeCursor)) / deltaSinceLastTimestamp);
                }
                break;
            } else {
                if (deltaSinceLastTimestamp == 0 && nextWeekCursor == timeCursor) {
                    tokensPerWeek[thisWeekCursor] = tokensPerWeek[thisWeekCursor] + toDistribute;
                } else {
                    tokensPerWeek[thisWeekCursor] = tokensPerWeek[thisWeekCursor]
                        + ((toDistribute * (nextWeekCursor - timeCursor)) / deltaSinceLastTimestamp);
                }
            }
            timeCursor = nextWeekCursor;
            thisWeekCursor = nextWeekCursor;
        }

        emit TokenCheckpointed(block.timestamp, toDistribute);
    }

    /// @notice Update token checkpoint
    /// @dev Calculate the total token to be distributed in a given week.
    function checkpointToken() external nonReentrant {
        _checkpointToken();
    }

    /// @notice Record StakeWeight total supply for each week
    function _checkpointTotalSupply() internal {
        StakeWeight stakeWeight = StakeWeight(config.getStakeWeight());
        uint256 weekCursor_ = weekCursor;
        uint256 roundedTimestamp = _timestampToFloorWeek(block.timestamp);

        stakeWeight.checkpoint();

        for (uint256 i = 0; i < 52; i++) {
            if (weekCursor_ > roundedTimestamp) {
                break;
            } else {
                uint256 epoch = _findTimestampEpoch(weekCursor_);
                StakeWeight.Point memory point = stakeWeight.pointHistory(epoch);
                int128 timeDelta = 0;
                if (weekCursor_ > point.timestamp) {
                    timeDelta = SafeCast.toInt128(int256(weekCursor_ - point.timestamp));
                }
                int128 bias = point.bias - point.slope * timeDelta;
                if (bias < 0) {
                    totalSupplyAt[weekCursor_] = 0;
                } else {
                    totalSupplyAt[weekCursor_] = SafeCast.toUint256(bias);
                }
            }
            weekCursor_ = weekCursor_ + 1 weeks;
        }

        weekCursor = weekCursor_;
    }

    /// @notice Update StakeWeight total supply checkpoint
    /// @dev This function can be called independently or at the first claim of
    /// the new epoch week.
    function checkpointTotalSupply() external nonReentrant {
        _checkpointTotalSupply();
    }

    /// @notice Claim rewardToken
    /// @dev Perform claim rewardToken
    function _claim(address user, address recipient_, uint256 maxClaimTimestamp) internal returns (uint256) {
        StakeWeight stakeWeight = StakeWeight(config.getStakeWeight());

        uint256 userEpoch = 0;
        uint256 toDistribute = 0;

        uint256 maxUserEpoch = stakeWeight.userPointEpoch(user);
        uint256 startWeekCursor_ = startWeekCursor;
        // maxUserEpoch = 0, meaning no lock.
        // Hence, no yield for user
        if (maxUserEpoch == 0) {
            return 0;
        }

        uint256 userWeekCursor = weekCursorOf[user];
        if (userWeekCursor == 0) {
            // if user has no userWeekCursor with GrassHouse yet
            // then we need to perform binary search
            userEpoch = _findTimestampUserEpoch(user, startWeekCursor_, maxUserEpoch);
        } else {
            // else, user must has epoch with GrassHouse already
            userEpoch = userEpochOf[user];
        }

        if (userEpoch == 0) {
            userEpoch = 1;
        }

        StakeWeight.Point memory userPoint = stakeWeight.userPointHistory(user, userEpoch);

        if (userWeekCursor == 0) {
            userWeekCursor = ((userPoint.timestamp + 1 weeks - 1) / 1 weeks) * 1 weeks;
        }

        // userWeekCursor is already at/beyond maxClaimTimestamp
        // meaning nothing to be claimed for this user.
        // This can be:
        // 1) User just lock their WCT less than 1 week
        // 2) User already claimed their rewards
        if (userWeekCursor >= maxClaimTimestamp) {
            return 0;
        }

        // Handle when user lock WCT before StakeWeight started
        // by assign userWeekCursor to StakeWeight's startWeekCursor_
        if (userWeekCursor < startWeekCursor_) {
            userWeekCursor = startWeekCursor_;
        }
        StakeWeight.Point memory prevUserPoint = StakeWeight.Point({ bias: 0, slope: 0, timestamp: 0, blockNumber: 0 });

        // Go through weeks
        for (uint256 i = 0; i < 52; i++) {
            // If userWeekCursor is iterated to be at/beyond maxClaimTimestamp
            // This means we went through all weeks that user subject to claim rewards already
            if (userWeekCursor >= maxClaimTimestamp) {
                break;
            }
            // Move to the new epoch if need to,
            // else calculate rewards that user should get.
            if (userWeekCursor >= userPoint.timestamp && userEpoch <= maxUserEpoch) {
                userEpoch = userEpoch + 1;
                prevUserPoint = StakeWeight.Point({
                    bias: userPoint.bias,
                    slope: userPoint.slope,
                    timestamp: userPoint.timestamp,
                    blockNumber: userPoint.blockNumber
                });
                // When userEpoch goes beyond maxUserEpoch then there is no more Point,
                // else take userEpoch as a new Point
                if (userEpoch > maxUserEpoch) {
                    userPoint = StakeWeight.Point({ bias: 0, slope: 0, timestamp: 0, blockNumber: 0 });
                } else {
                    userPoint = stakeWeight.userPointHistory(user, userEpoch);
                }
            } else {
                int128 timeDelta = SafeCast.toInt128(int256(userWeekCursor - prevUserPoint.timestamp));
                uint256 balanceOf =
                    SafeCast.toUint256(Math128.max(prevUserPoint.bias - timeDelta * prevUserPoint.slope, 0));
                if (balanceOf == 0 && userEpoch > maxUserEpoch) {
                    break;
                }
                if (balanceOf > 0) {
                    toDistribute =
                        toDistribute + (balanceOf * tokensPerWeek[userWeekCursor]) / totalSupplyAt[userWeekCursor];
                }
                userWeekCursor = userWeekCursor + 1 weeks;
            }
        }

        userEpoch = Math128.min(maxUserEpoch, userEpoch - 1);
        userEpochOf[user] = userEpoch;
        weekCursorOf[user] = userWeekCursor;

        emit RewardsClaimed(user, recipient_, toDistribute, userEpoch, maxUserEpoch);

        return toDistribute;
    }

    /// @notice Get claim recipient address
    /// @param user The address to claim rewards for
    function getRecipient(address user) public view returns (address recipient_) {
        recipient_ = user;

        address userRecipient = recipient[recipient_];
        if (userRecipient != address(0)) {
            recipient_ = userRecipient;
        }
    }

    /// @notice Claim rewardToken for user and user's recipient
    /// @dev Need owner permission
    /// @param recipient_ The recipient address will be claimed to
    function claimTo(address recipient_) external nonReentrant onlyLive returns (uint256) {
        return _claimWithCustomRecipient(msg.sender, recipient_);
    }

    /// @notice Claim rewardToken for user and user's recipient
    /// @dev Do not need owner permission
    /// @param user The address to claim rewards for
    function claim(address user) external nonReentrant onlyLive returns (uint256) {
        return _claimWithCustomRecipient(user, address(0));
    }

    function _claimWithCustomRecipient(address user, address recipient_) internal returns (uint256) {
        if (block.timestamp >= weekCursor) _checkpointTotalSupply();

        uint256 lastTokenTimestamp_ = lastTokenTimestamp;

        _checkpointToken();
        lastTokenTimestamp_ = block.timestamp;

        lastTokenTimestamp_ = _timestampToFloorWeek(lastTokenTimestamp_);
        if (recipient_ == address(0)) {
            recipient_ = getRecipient(user);
        }
        uint256 total = _claim(user, recipient_, lastTokenTimestamp_);
        if (total != 0) {
            lastTokenBalance = lastTokenBalance - total;
            IERC20(config.getL2wct()).safeTransfer(recipient_, total);
        }

        return total;
    }

    /// @notice Claim rewardToken for multiple users
    /// @param users The array of addresses to claim reward for
    function claimMany(address[] calldata users) external nonReentrant onlyLive returns (bool) {
        if (users.length > 20) revert TooManyUsers();

        if (block.timestamp >= weekCursor) _checkpointTotalSupply();

        uint256 lastTokenTimestamp_ = lastTokenTimestamp;

        _checkpointToken();
        lastTokenTimestamp_ = block.timestamp;

        lastTokenTimestamp_ = _timestampToFloorWeek(lastTokenTimestamp_);
        uint256 total = 0;

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            if (user == address(0)) revert InvalidUser();

            address recipient_ = getRecipient(user);
            uint256 amount = _claim(user, recipient_, lastTokenTimestamp_);

            if (amount != 0) {
                IERC20(config.getL2wct()).safeTransfer(recipient_, amount);
                total = total + amount;
            }
        }

        if (total != 0) {
            lastTokenBalance = lastTokenBalance - total;
        }

        return true;
    }

    /// @notice Receive rewardTokens into the contract and trigger token checkpoint
    function feed(uint256 amount) external nonReentrant onlyLive returns (bool) {
        IERC20(config.getL2wct()).safeTransferFrom(msg.sender, address(this), amount);

        _checkpointToken();

        emit Fed(amount);

        return true;
    }

    /// @notice Do Binary Search to find out epoch from timestamp
    /// @param timestamp Timestamp to find epoch
    function _findTimestampEpoch(uint256 timestamp) internal view returns (uint256) {
        StakeWeight stakeWeight = StakeWeight(config.getStakeWeight());

        uint256 min = 0;
        uint256 max = stakeWeight.epoch();
        // Loop for 128 times -> enough for 128-bit numbers
        for (uint256 i = 0; i < 128; i++) {
            if (min >= max) {
                break;
            }
            uint256 mid = (min + max + 1) / 2;
            StakeWeight.Point memory point = stakeWeight.pointHistory(mid);
            if (point.timestamp <= timestamp) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return min;
    }

    /// @notice Perform binary search to find out user's epoch from the given timestamp
    /// @param user The user address
    /// @param timestamp The timestamp that you wish to find out epoch
    /// @param maxUserEpoch Max epoch to find out the timestamp
    function _findTimestampUserEpoch(
        address user,
        uint256 timestamp,
        uint256 maxUserEpoch
    )
        internal
        view
        returns (uint256)
    {
        uint256 min = 0;
        uint256 max = maxUserEpoch;
        for (uint256 i = 0; i < 128; i++) {
            if (min >= max) {
                break;
            }
            uint256 mid = (min + max + 1) / 2;
            StakeWeight.Point memory point = StakeWeight(config.getStakeWeight()).userPointHistory(user, mid);
            if (point.timestamp <= timestamp) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return min;
    }

    /// @notice Emergency stop the contract and transfer remaining tokens to the emergency return address
    function kill() external onlyOwner nonReentrant {
        IERC20 rewardToken = IERC20(config.getL2wct());
        isKilled = true;
        rewardToken.safeTransfer(emergencyReturn, rewardToken.balanceOf(address(this)));

        emit Killed();
    }

    /// @notice Round off random timestamp to week
    /// @param timestamp The timestamp to be rounded off
    function _timestampToFloorWeek(uint256 timestamp) internal pure returns (uint256) {
        return (timestamp / 1 weeks) * 1 weeks;
    }

    /// @notice Inject rewardToken into the contract
    /// @param timestamp The timestamp of the rewardToken to be distributed
    /// @param amount The amount of rewardToken to be distributed
    function injectReward(uint256 timestamp, uint256 amount) external onlyOwner nonReentrant {
        _injectReward(timestamp, amount);
    }

    /// @notice Inject rewardToken for currect week into the contract
    /// @param amount The amount of rewardToken to be distributed
    function injectRewardForCurrentWeek(uint256 amount) external onlyOwner nonReentrant {
        _injectReward(block.timestamp, amount);
    }

    function _injectReward(uint256 timestamp, uint256 amount) internal {
        IERC20(config.getL2wct()).safeTransferFrom(msg.sender, address(this), amount);
        lastTokenBalance += amount;
        totalDistributed += amount;
        uint256 weekTimestamp = _timestampToFloorWeek(timestamp);
        tokensPerWeek[weekTimestamp] += amount;
    }

    /// @notice Set recipient address
    /// @param recipient_ Recipient address
    function setRecipient(address recipient_) external {
        address oldRecipient = recipient[msg.sender];
        recipient[msg.sender] = recipient_;
        emit RecipientUpdated(msg.sender, oldRecipient, recipient_);
    }
}
