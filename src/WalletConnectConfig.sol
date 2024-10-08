// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title WalletConnectConfig
/// @notice Configuration contract for the WalletConnect system
/// @author WalletConnect
contract WalletConnectConfig is Initializable, AccessControlUpgradeable {
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

    bytes32 public constant WALLETCONNECT_REWARDS_VAULT = keccak256("WALLETCONNECT_REWARDS_VAULT");
    bytes32 public constant WCT_TOKEN = keccak256("WCT_TOKEN");
    bytes32 public constant L2WCT_TOKEN = keccak256("L2WCT_TOKEN");
    bytes32 public constant PERMISSIONED_NODE_REGISTRY = keccak256("PERMISSIONED_NODE_REGISTRY");
    bytes32 public constant REWARD_MANAGER = keccak256("REWARD_MANAGER");
    bytes32 public constant STAKE_WEIGHT = keccak256("STAKE_WEIGHT");
    bytes32 public constant PAUSER = keccak256("PAUSER");

    /// @notice Initializes the contract
    /// @dev MUST be called during the contract upgrade to set up the proxies state
    /// @param init Initialization parameters
    function initialize(Init memory init) public initializer {
        __AccessControl_init();
        _grantRole(ADMIN_ROLE, init.admin);
    }

    /// @notice Gets the WCT token address
    /// @return The address of the WCT token contract
    function getWCT() external view returns (address) {
        return _contractsMap[WCT_TOKEN];
    }

    /// @notice Gets the L2WCT token address
    /// @return The address of the L2WCT token contract
    function getL2wct() external view returns (address) {
        return _contractsMap[L2WCT_TOKEN];
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

    /// @notice Gets the StakeWeight address
    /// @return The address of the StakeWeight contract
    function getStakeWeight() external view returns (address) {
        return _contractsMap[STAKE_WEIGHT];
    }

    /// @notice Gets the WalletConnect Rewards Vault address
    /// @return The address of the WalletConnect Rewards Vault
    function getWalletConnectRewardsVault() external view returns (address) {
        return _accountsMap[WALLETCONNECT_REWARDS_VAULT];
    }

    /// @notice Updates the WCT token address
    /// @param wct The new WCT token address
    function updateWCT(address wct) external onlyRole(ADMIN_ROLE) {
        _setContract({ key: WCT_TOKEN, val: wct });
    }

    /// @notice Updates the L2WCT token address
    /// @param l2wct The new L2WCT token address
    function updateL2wct(address l2wct) external onlyRole(ADMIN_ROLE) {
        _setContract({ key: L2WCT_TOKEN, val: l2wct });
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

    /// @notice Updates the StakeWeight address
    /// @param stakeWeight The new StakeWeight address
    function updateStakeWeight(address stakeWeight) external onlyRole(ADMIN_ROLE) {
        _setContract({ key: STAKE_WEIGHT, val: stakeWeight });
    }

    /// @notice Updates the WalletConnect Rewards Vault address
    /// @param walletConnectRewardsVault The new WalletConnect Rewards Vault address
    function updateWalletConnectRewardsVault(address walletConnectRewardsVault) external onlyRole(ADMIN_ROLE) {
        _setAccount({ key: WALLETCONNECT_REWARDS_VAULT, val: walletConnectRewardsVault });
    }

    /// @notice Checks if the given address is a recognized WalletConnect contract
    /// @param addr The address to check
    /// @param contractName The name of the contract to check against
    /// @return True if the address matches the stored contract address, false otherwise
    function isWalletConnectContract(address addr, bytes32 contractName) external view returns (bool) {
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
