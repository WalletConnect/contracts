// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title BakersSyndicateConfig
/// @notice Configuration contract for the BakersSyndicate system
/// @author Coinbase
contract BakersSyndicateConfig is Initializable, AccessControlUpgradeable {
    /// @notice Error thrown when attempting to set an identical value
    error IdenticalValue();

    /// @notice Error thrown when an invalid address is provided
    error InvalidAddress();

    /// @notice Emitted when a contract address is set
    /// @param key The key identifying the contract
    /// @param val The new contract address
    event ContractSet(bytes32 indexed key, address val);

    /// @notice Emitted when an account address is set
    /// @param key The key identifying the account
    /// @param val The new account address
    event AccountSet(bytes32 indexed key, address val);

    /// @notice Role for administrative actions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Configuration for contract initialization
    struct Init {
        address admin;
    }

    // Storage
    mapping(bytes32 => address) private _accountsMap;
    mapping(bytes32 => address) private _contractsMap;

    bytes32 public constant BAKERSSYNDICATE_REWARDS_VAULT = keccak256("BAKERSSYNDICATE_REWARDS_VAULT");
    bytes32 public constant BRR_TOKEN = keccak256("BRR_TOKEN");
    bytes32 public constant PERMISSIONED_NODE_REGISTRY = keccak256("PERMISSIONED_NODE_REGISTRY");
    bytes32 public constant REWARD_MANAGER = keccak256("REWARD_MANAGER");
    bytes32 public constant STAKING = keccak256("STAKING");
    bytes32 public constant PAUSER = keccak256("PAUSER");

    /// @notice Initializes the contract
    /// @dev MUST be called during the contract upgrade to set up the proxies state
    /// @param init Initialization parameters
    function initialize(Init memory init) public initializer {
        __AccessControl_init();
        _grantRole(ADMIN_ROLE, init.admin);
    }

    /// @notice Gets the BRR token address
    /// @return The address of the BRR token contract
    function getBrr() external view returns (address) {
        return _contractsMap[BRR_TOKEN];
    }

    /// @notice Gets the Pauser address
    /// @return The address of the Pauser contract
    function getPauser() external view returns (address) {
        return _contractsMap[PAUSER];
    }

    /// @notice Gets the Permissioned Node Registry address
    /// @return The address of the Permissioned Node Registry contract
    function getPermissionedNodeRegistry() external view returns (address) {
        return _contractsMap[PERMISSIONED_NODE_REGISTRY];
    }

    /// @notice Gets the Reward Manager address
    /// @return The address of the Reward Manager contract
    function getRewardManager() external view returns (address) {
        return _contractsMap[REWARD_MANAGER];
    }

    /// @notice Gets the Staking address
    /// @return The address of the Staking contract
    function getStaking() external view returns (address) {
        return _contractsMap[STAKING];
    }

    /// @notice Gets the BakersSyndicate Rewards Vault address
    /// @return The address of the BakersSyndicate Rewards Vault
    function getBakersSyndicateRewardsVault() external view returns (address) {
        return _accountsMap[BAKERSSYNDICATE_REWARDS_VAULT];
    }

    /// @notice Updates the BRR token address
    /// @param brr The new BRR token address
    function updateBrr(address brr) external onlyRole(ADMIN_ROLE) {
        _setContract({ key: BRR_TOKEN, val: brr });
    }

    /// @notice Updates the Pauser address
    /// @param pauser The new Pauser address
    function updatePauser(address pauser) external onlyRole(ADMIN_ROLE) {
        _setContract({ key: PAUSER, val: pauser });
    }

    /// @notice Updates the Permissioned Node Registry address
    /// @param permissionedNodeRegistry The new Permissioned Node Registry address
    function updatePermissionedNodeRegistry(address permissionedNodeRegistry) external onlyRole(ADMIN_ROLE) {
        _setContract({ key: PERMISSIONED_NODE_REGISTRY, val: permissionedNodeRegistry });
    }

    /// @notice Updates the Reward Manager address
    /// @param rewardManager The new Reward Manager address
    function updateRewardManager(address rewardManager) external onlyRole(ADMIN_ROLE) {
        _setContract({ key: REWARD_MANAGER, val: rewardManager });
    }

    /// @notice Updates the Staking address
    /// @param staking The new Staking address
    function updateStaking(address staking) external onlyRole(ADMIN_ROLE) {
        _setContract({ key: STAKING, val: staking });
    }

    /// @notice Updates the BakersSyndicate Rewards Vault address
    /// @param bakersSyndicateRewardsVault The new BakersSyndicate Rewards Vault address
    function updateBakersSyndicateRewardsVault(address bakersSyndicateRewardsVault) external onlyRole(ADMIN_ROLE) {
        _setAccount({ key: BAKERSSYNDICATE_REWARDS_VAULT, val: bakersSyndicateRewardsVault });
    }

    /// @notice Checks if the given address is a recognized BakersSyndicate contract
    /// @param addr The address to check
    /// @param contractName The name of the contract to check against
    /// @return True if the address matches the stored contract address, false otherwise
    function isBakersSyndicateContract(address addr, bytes32 contractName) external view returns (bool) {
        return (addr == _contractsMap[contractName]);
    }

    /// @dev Sets a contract address
    /// @param key The key identifying the contract
    /// @param val The new contract address
    function _setContract(bytes32 key, address val) private {
        if (val == address(0)) {
            revert InvalidAddress();
        }
        if (_contractsMap[key] == val) {
            revert IdenticalValue();
        }
        _contractsMap[key] = val;
        emit ContractSet({ key: key, val: val });
    }

    /// @dev Sets an account address
    /// @param key The key identifying the account
    /// @param val The new account address
    function _setAccount(bytes32 key, address val) private {
        if (val == address(0)) {
            revert InvalidAddress();
        }
        if (_accountsMap[key] == val) {
            revert IdenticalValue();
        }
        _accountsMap[key] = val;
        emit AccountSet({ key: key, val: val });
    }
}
