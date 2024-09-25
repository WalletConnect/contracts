// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.25;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { WalletConnectConfig } from "./WalletConnectConfig.sol";

contract Staking is Initializable, OwnableUpgradeable {
    using SafeERC20 for L2CNKT;

    WalletConnectConfig public config;

    // Duration of rewards to be paid out (in seconds)
    uint256 public duration;
    // Timestamp of when the rewards finish
    uint256 public finishAt;
    // Minimum of last updated time and reward finish time
    uint256 public updatedAt;
    // Reward to be paid out per second
    uint256 public rewardRate;
    // Sum of (reward rate * dt * 1e18 / total supply)
    uint256 public rewardPerTokenStored;
    // User address => rewardPerTokenStored
    mapping(address => uint256) public userRewardPerTokenPaid;
    // User address => rewards to be claimed
    mapping(address => uint256) public rewards;

    // Total staked
    uint256 public totalSupply;
    // User address => staked amount
    mapping(address => uint256) public balanceOf;

    /*//////////////////////////////////////////////////////////////////////////
                                    EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    event RewardRateUpdated(uint256 oldRewardRate, uint256 newRewardRate);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    /*//////////////////////////////////////////////////////////////////////////
                                    ERRORS
    //////////////////////////////////////////////////////////////////////////*/
    error Paused();
    error InsufficientStake(address staker, uint256 currentStake, uint256 amount);
    error StakingBelowMinimum(uint256 minStakeAmount, uint256 stakingAmount);
    error UnstakingBelowMinimum(uint256 minStakeAmount, uint256 currentStake, uint256 amount);
    error NotWhitelisted();
    error UnchangedState();
    error InvalidInput();
    error InvalidRewardRate();
    error InsufficientRewardBalance();
    error NoChange();
    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice The staking allowlist flag which, when enabled, allows staking only for addresses in allowlist.
    bool public isStakingAllowlist;

    /// @notice The minimum staking amount for each node.
    uint256 public minStakeAmount;

    /// @notice The accrued rewards for each node.
    mapping(address staker => uint256 pendingRewards) public pendingRewards;

    /// @notice Stake amount for each node.
    mapping(address staker => uint256 amount) public stakes;

    WalletConnectConfig public bakersSyndicateConfig;

    /// @notice Configuration for contract initialization.
    struct Init {
        address admin;
        WalletConnectConfig config;
        uint256 duration;
    }

    /// @notice Initializes the contract.
    /// @dev MUST be called during the contract upgrade to set up the proxies state.
    function initialize(Init memory init) external initializer {
        __Ownable_init(init.admin);
        config = WalletConnectConfig(init.config);
        duration = init.duration;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/
    /// @notice Interface for nodes to stake their WCT with the protocol. Note: when allowlist is enabled, only nodes
    /// with the allowlist can stake.
    function stake(uint256 amount) external {
        if (Pauser(bakersSyndicateConfig.getPauser()).isStakingPaused()) {
            revert Paused();
        }

        if (isStakingAllowlist) {
            if (
                !PermissionedNodeRegistry(bakersSyndicateConfig.getPermissionedNodeRegistry()).isNodeWhitelisted(
                    msg.sender
                )
            ) {
                revert NotWhitelisted();
            }
        }

        if (amount < minStakeAmount) {
            revert StakingBelowMinimum({ minStakeAmount: minStakeAmount, stakingAmount: amount });
        }

    /// @notice Interface for nodes to stake their CNKT with the protocol.
    function stake(uint256 amount) external updateReward(msg.sender) {
        L2CNKT l2cnkt = L2CNKT(config.getL2cnkt());
        if (amount == 0) revert InvalidInput();
        totalSupply += amount;
        balanceOf[msg.sender] += amount;
        l2cnkt.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);

        stakes[msg.sender] += amount;

        IERC20(bakersSyndicateConfig.getWCT()).transferFrom(msg.sender, address(this), amount);
    }

    /// @notice Interface for users to unstake their CNKT from the protocol.
    function withdraw(uint256 amount) external updateReward(msg.sender) {
        L2CNKT l2cnkt = L2CNKT(config.getL2cnkt());
        if (amount == 0) revert InvalidInput();
        totalSupply -= amount;
        balanceOf[msg.sender] -= amount;
        l2cnkt.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Sets the staking allowlist flag.
    function setStakingAllowlist(bool isStakingAllowlist_) external onlyOwner {
        if (isStakingAllowlist == isStakingAllowlist_) {
            revert UnchangedState();
        }
        isStakingAllowlist = isStakingAllowlist_;
        emit StakingAllowlistSet(isStakingAllowlist_);
    }

    /// @notice Updates the minimum staking amount.
    function updateMinStakeAmount(uint256 minStakeAmount_) external onlyOwner {
        if (minStakeAmount == minStakeAmount_) {
            revert UnchangedState();
        }
        emit MinStakeAmountUpdated(minStakeAmount, minStakeAmount_);
        minStakeAmount = minStakeAmount_;
    }

    /// @notice Function for the reward manager to add rewards to a node's pending rewards balance.
    function updateRewards(address node, uint256 amount, uint256 reportingEpoch) external {
        UtilLib.onlyWalletConnectContract(msg.sender, bakersSyndicateConfig, bakersSyndicateConfig.REWARD_MANAGER());
        if (Pauser(bakersSyndicateConfig.getPauser()).isStakingPaused()) {
            revert Paused();
        }
        if (stakes[node] >= minStakeAmount) {
            pendingRewards[node] += amount;
        }
        emit RewardsUpdated({ node: node, reportingEpoch: reportingEpoch, newRewards: amount });
    }

    // Function for users to claim rewards
    function getReward() external updateReward(msg.sender) {
        L2CNKT l2cnkt = L2CNKT(config.getL2cnkt());
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            l2cnkt.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function setRewardsDuration(uint256 _duration) external onlyOwner {
        require(finishAt < block.timestamp, "reward duration not finished");
        duration = _duration;
    }

    function updateRewardRate(uint256 newRewardRate) external onlyOwner updateReward(address(0)) {
        L2CNKT l2cnkt = L2CNKT(config.getL2cnkt());
        uint256 oldRewardRate = rewardRate;
        uint256 remainingRewards = 0;

        if (block.timestamp < finishAt) {
            remainingRewards = (finishAt - block.timestamp) * oldRewardRate;
        }

        if (newRewardRate == 0) revert InvalidRewardRate();

        uint256 newRewardAmount = newRewardRate * duration;
        if (newRewardAmount + remainingRewards > l2cnkt.balanceOf(address(this))) {
            revert InsufficientRewardBalance();
        }

        rewardRate = newRewardRate;
        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;

        emit RewardRateUpdated(oldRewardRate, newRewardRate);
    }

    function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x <= y ? x : y;
    }
}
