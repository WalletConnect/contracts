// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.25;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { UtilLib } from "./library/UtilLib.sol";
import { WalletConnectConfig } from "./WalletConnectConfig.sol";
import { PermissionedNodeRegistry } from "./PermissionedNodeRegistry.sol";
import { Pauser } from "./Pauser.sol";

contract Staking is Initializable, OwnableUpgradeable {
    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////////////////
                                    EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    event Staked(address indexed node, uint256 amount);
    event Unstaked(address indexed node, uint256 amount);
    event RewardsClaimed(address indexed node, uint256 rewardsClaimed);
    event RewardsUpdated(address indexed node, uint256 indexed reportingEpoch, uint256 newRewards);
    event StakingAllowlistSet(bool isStakingAllowlist);
    event MinStakeAmountUpdated(uint256 oldMinStakeAmount, uint256 newMinStakeAmount);

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
    error NoRewards(address node);

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
        address owner;
        uint256 minStakeAmount;
        bool isStakingAllowlist;
        WalletConnectConfig bakersSyndicateConfig;
    }

    /// @notice Initializes the contract.
    /// @dev MUST be called during the contract upgrade to set up the proxies state.
    function initialize(Init memory init) external initializer {
        __Ownable_init(init.owner);
        UtilLib.checkNonZeroAddress(address(init.bakersSyndicateConfig));

        minStakeAmount = init.minStakeAmount;
        bakersSyndicateConfig = init.bakersSyndicateConfig;
        isStakingAllowlist = init.isStakingAllowlist;
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

        emit Staked(msg.sender, amount);

        stakes[msg.sender] += amount;

        IERC20(bakersSyndicateConfig.getWCT()).transferFrom(msg.sender, address(this), amount);
    }

    /// @notice Interface for users to unstake their WCT from the protocol.
    function unstake(uint256 amount) external {
        if (Pauser(bakersSyndicateConfig.getPauser()).isStakingPaused()) {
            revert Paused();
        }

        if (amount == 0) {
            revert InvalidInput();
        }

        uint256 currentStake = stakes[msg.sender];

        if (currentStake < amount) {
            revert InsufficientStake({ staker: msg.sender, currentStake: currentStake, amount: amount });
        }

        uint256 stakeAfterUnstaking = currentStake - amount;

        if (stakeAfterUnstaking < minStakeAmount && stakeAfterUnstaking > 0) {
            revert UnstakingBelowMinimum({ minStakeAmount: minStakeAmount, currentStake: currentStake, amount: amount });
        }

        stakes[msg.sender] -= amount;

        emit Unstaked(msg.sender, amount);

        IERC20(bakersSyndicateConfig.getWCT()).transfer(msg.sender, amount);
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
    function claimRewards() external {
        uint256 reward = pendingRewards[msg.sender];

        if (reward == 0) {
            revert NoRewards(msg.sender);
        }

        // Reset the node's pending reward balance
        pendingRewards[msg.sender] = 0;

        emit RewardsClaimed(msg.sender, reward);

        // Transfer the rewards
        IERC20(bakersSyndicateConfig.getWCT()).safeTransferFrom(
            bakersSyndicateConfig.getWalletConnectRewardsVault(), msg.sender, reward
        );
    }
}
