// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import { StakingStorage } from "./StakingStorage.sol";
import { RewardCalculator } from "./RewardCalculator.sol";
import { StakeWeightCalculator } from "./StakeWeightCalculator.sol";

/// @title BakersSyndicate Staking Contract
/// @notice This contract manages the staking of BRR tokens and reward distribution
/// @author BakersSyndicate
contract BakersSyndicateStaking is StakingStorage, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    RewardCalculator public rewardCalculator;
    StakeWeightCalculator public stakeWeightCalculator;

    /// @notice Emitted when a user stakes tokens
    /// @param user The address of the user who staked
    /// @param amount The amount of tokens staked
    /// @param lockDuration The duration for which the tokens are locked
    event Staked(address indexed user, uint256 amount, uint256 lockDuration);

    /// @notice Emitted when a user unstakes tokens
    /// @param user The address of the user who unstaked
    /// @param amount The amount of tokens unstaked
    event Unstaked(address indexed user, uint256 amount);

    /// @notice Emitted when a user claims rewards
    /// @param user The address of the user who claimed rewards
    /// @param amount The amount of rewards claimed
    event RewardsClaimed(address indexed user, uint256 amount);

    /// @notice Emitted when reward parameters are updated
    /// @param bMax The new maximum reward rate
    /// @param bMin The new minimum reward rate
    /// @param k The new kink parameter
    /// @param p The new power parameter
    event RewardParametersUpdated(uint256 bMax, uint256 bMin, uint256 k, uint256 p);

    /// @notice Thrown when staking amount is zero
    error ZeroStakeAmount();

    /// @notice Thrown when lock duration is invalid
    error InvalidLockDuration();

    /// @notice Thrown when trying to unstake before lock period ends
    error LockPeriodNotEnded();

    /// @notice Thrown when there are no rewards to claim
    error NoRewardsToClaim();

    /// @notice Thrown when an invalid address is provided
    error InvalidAddress();

    /// @notice Thrown when invalid reward parameters are provided
    error InvalidRewardParameters();

    /// @notice Initializes the contract
    /// @param brr The address of the BRR token
    /// @param _rewardCalculator The address of the RewardCalculator contract
    /// @param _stakeWeightCalculator The address of the StakeWeightCalculator contract
    function initialize(address brr, address _rewardCalculator, address _stakeWeightCalculator) external initializer {
        __ReentrancyGuard_init();
        __Ownable_init();

        if (brr == address(0)) revert InvalidAddress();
        if (_rewardCalculator == address(0)) revert InvalidAddress();
        if (_stakeWeightCalculator == address(0)) revert InvalidAddress();

        StakingStorageData storage $ = _getStorage();
        $.brr = IERC20Upgradeable(brr);
        rewardCalculator = RewardCalculator(_rewardCalculator);
        stakeWeightCalculator = StakeWeightCalculator(_stakeWeightCalculator);

        $.bMax = 90; // 0.9% in basis points
        $.bMin = 10; // 0.1% in basis points
        $.k = 5000; // 50% in basis points
        $.p = 1; // Power factor
    }

    /// @notice Stakes tokens for a specified lock duration
    /// @param amount The amount of tokens to stake
    /// @param lockDuration The duration to lock the tokens
    function stake(uint256 amount, uint256 lockDuration) external nonReentrant {
        StakingStorageData storage $ = _getStorage();
        if (amount == 0) revert ZeroStakeAmount();
        if (lockDuration < MIN_LOCK_DURATION || lockDuration > MAX_LOCK_DURATION) revert InvalidLockDuration();

        _updateReward(msg.sender);

        $.stakes[msg.sender].amount += amount;
        $.stakes[msg.sender].lockEndTime = uint40(block.timestamp + lockDuration);
        $.totalStaked += amount;

        uint256 newStakeWeight = stakeWeightCalculator.calculateStakeWeight({
            user: msg.sender,
            stakeAmount: $.stakes[msg.sender].amount,
            lockEndTime: $.stakes[msg.sender].lockEndTime,
            totalStaked: $.totalStaked
        });
        $.totalStakeWeight += newStakeWeight;

        $.brr.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount, lockDuration);
    }

    /// @notice Unstakes tokens and claims rewards
    function unstake() external nonReentrant {
        StakingStorageData storage $ = _getStorage();
        if (block.timestamp < $.stakes[msg.sender].lockEndTime) revert LockPeriodNotEnded();

        _updateReward(msg.sender);

        uint256 amount = $.stakes[msg.sender].amount;
        uint256 rewards = $.stakes[msg.sender].accumulatedRewards;

        uint256 oldStakeWeight = stakeWeightCalculator.calculateStakeWeight({
            user: msg.sender,
            stakeAmount: amount,
            lockEndTime: $.stakes[msg.sender].lockEndTime,
            totalStaked: $.totalStaked
        });

        $.totalStaked -= amount;
        $.totalStakeWeight -= oldStakeWeight;

        $.stakes[msg.sender].amount = 0;
        $.stakes[msg.sender].accumulatedRewards = 0;

        $.brr.safeTransfer(msg.sender, amount + rewards);

        emit Unstaked(msg.sender, amount);
        emit RewardsClaimed(msg.sender, rewards);
    }

    /// @notice Claims accumulated rewards
    function claimRewards() external nonReentrant {
        StakingStorageData storage $ = _getStorage();
        _updateReward(msg.sender);

        uint256 rewards = $.stakes[msg.sender].accumulatedRewards;
        if (rewards == 0) revert NoRewardsToClaim();

        $.stakes[msg.sender].accumulatedRewards = 0;

        $.brr.safeTransfer(msg.sender, rewards);

        emit RewardsClaimed(msg.sender, rewards);
    }

    /// @notice Sets new reward parameters
    /// @param bMax The new maximum reward rate
    /// @param bMin The new minimum reward rate
    /// @param k The new kink parameter
    /// @param p The new power parameter
    function setRewardParameters(uint256 bMax, uint256 bMin, uint256 k, uint256 p) external onlyOwner {
        if (bMax <= bMin || k > 10_000) revert InvalidRewardParameters();

        StakingStorageData storage $ = _getStorage();
        $.bMax = bMax;
        $.bMin = bMin;
        $.k = k;
        $.p = p;

        emit RewardParametersUpdated(bMax, bMin, k, p);
    }

    /// @notice Updates the reward for a given account
    /// @param account The address of the account to update rewards for
    function _updateReward(address account) internal {
        StakingStorageData storage $ = _getStorage();

        uint256 circulatingSupply = rewardCalculator.getCirculatingSupply();

        // Calculate the reward rate
        $.rewardRate = rewardCalculator.calculateRewardRate({
            bMax: $.bMax,
            bMin: $.bMin,
            k: $.k,
            p: $.p,
            totalStaked: $.totalStaked,
            circulatingSupply: circulatingSupply
        });

        uint256 newRewardPerToken = rewardCalculator.calculateRewardPerToken({
            rewardRate: $.rewardRate,
            lastUpdateTime: $.lastUpdateTime,
            totalStakeWeight: $.totalStakeWeight
        });

        if (account != address(0)) {
            uint256 accountStakeWeight = stakeWeightCalculator.calculateStakeWeight({
                user: account,
                stakeAmount: $.stakes[account].amount,
                lockEndTime: $.stakes[account].lockEndTime,
                totalStaked: $.totalStaked
            });

            $.stakes[account].accumulatedRewards = rewardCalculator.calculateEarned({
                account: account,
                stakeWeight: accountStakeWeight,
                rewardPerToken: newRewardPerToken,
                lastRewardCalculationTime: $.stakes[account].lastRewardCalculationTime,
                accumulatedRewards: $.stakes[account].accumulatedRewards
            });
            $.stakes[account].lastRewardCalculationTime = uint40(block.timestamp);
        }

        $.lastUpdateTime = uint40(block.timestamp);
    }
}
