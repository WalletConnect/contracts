// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { L2CNKT } from "./L2CNKT.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Staking is Initializable, OwnableUpgradeable {
    using SafeERC20 for L2CNKT;

    L2CNKT public l2cnkt;

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

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    /*//////////////////////////////////////////////////////////////////////////
                                    ERRORS
    //////////////////////////////////////////////////////////////////////////*/
    error InvalidInput();
    error InvalidRewardRate();
    error InsufficientRewardBalance();

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Configuration for contract initialization.
    struct Init {
        address owner;
        address l2cnkt;
        uint256 duration;
    }

    /// @notice Initializes the contract.
    /// @dev MUST be called during the contract upgrade to set up the proxies state.
    function initialize(Init memory init) external initializer {
        __Ownable_init(init.owner);
        l2cnkt = L2CNKT(init.l2cnkt);
        duration = init.duration;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return _min(finishAt, block.timestamp);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) / totalSupply;
    }

    /// @notice Interface for nodes to stake their CNKT with the protocol.
    function stake(uint256 amount) external updateReward(msg.sender) {
        if (amount == 0) revert InvalidInput();
        totalSupply += amount;
        balanceOf[msg.sender] += amount;
        l2cnkt.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    /// @notice Interface for users to unstake their CNKT from the protocol.
    function withdraw(uint256 amount) external updateReward(msg.sender) {
        if (amount == 0) revert InvalidInput();
        totalSupply -= amount;
        balanceOf[msg.sender] -= amount;
        l2cnkt.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function earned(address account) public view returns (uint256) {
        return (balanceOf[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18 + rewards[account];
    }

    // Function for users to claim rewards
    function getReward() external updateReward(msg.sender) {
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

    function notifyRewardAmount(uint256 newRewardRate) external onlyOwner updateReward(address(0)) {
        uint256 remainingRewards = 0;
        if (block.timestamp < finishAt) {
            remainingRewards = (finishAt - block.timestamp) * rewardRate;
        }

        rewardRate = newRewardRate;

        if (rewardRate == 0) revert InvalidRewardRate();

        uint256 newRewardAmount = rewardRate * duration;
        if (newRewardAmount + remainingRewards > l2cnkt.balanceOf(address(this))) {
            revert InsufficientRewardBalance();
        }

        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;
        emit RewardAdded(newRewardAmount);
    }

    function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x <= y ? x : y;
    }
}
