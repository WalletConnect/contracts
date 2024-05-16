// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.25;

import { AccessControlEnumerable } from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPauserRead } from "./interfaces/IPauser.sol";

contract Staking is AccessControlEnumerable {
    /*//////////////////////////////////////////////////////////////////////////
                                    EVENTS
    //////////////////////////////////////////////////////////////////////////*/
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);

    /*//////////////////////////////////////////////////////////////////////////
                                    ERRORS
    //////////////////////////////////////////////////////////////////////////*/
    error Paused();
    error InsufficientStake();

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Role to manage the staking allowlist.
    bytes32 public constant STAKING_ALLOWLIST_MANAGER_ROLE = keccak256("STAKING_ALLOWLIST_MANAGER_ROLE");

    /// @notice Role allowed to stake ETH when allowlist is enabled.
    bytes32 public constant STAKING_ALLOWLIST_ROLE = keccak256("STAKING_ALLOWLIST_ROLE");

    /// @notice The staking allowlist flag which, when enabled, allows staking only for addresses in allowlist.
    bool public isStakingAllowlist;

    /// @notice Stake amount for each user.
    mapping(address staker => uint256 amount) public stakes;

    /// @notice The WalletConnect token contract.
    IERC20 public cnct;

    /// @notice The pauser contract.
    /// @dev Keeps the pause state across the protocol.
    IPauserRead public pauser;

    constructor(address initialOwner) {
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        isStakingAllowlist = true;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/
    /// @notice Interface for users to stake their CNCT with the protocol. Note: when allowlist is enabled, only users
    /// with the allowlist can stake.
    function stake(uint256 amount) external payable {
        if (pauser.isStakingPaused()) {
            revert Paused();
        }

        if (isStakingAllowlist) {
            _checkRole(STAKING_ALLOWLIST_ROLE);
        }

        emit Staked(msg.sender, msg.value);

        stakes[msg.sender] += amount;

        cnct.transferFrom(msg.sender, address(this), amount);
    }

    /// @notice Interface for users to unstake their CNCT from the protocol.
    function unstake(uint256 amount) external {
        if (pauser.isStakingPaused()) {
            revert Paused();
        }

        if (stakes[msg.sender] < amount) {
            revert InsufficientStake();
        }

        emit Unstaked(msg.sender, amount);

        cnct.transfer(msg.sender, amount);
    }
}
