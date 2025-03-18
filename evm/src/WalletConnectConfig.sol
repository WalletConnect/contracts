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

    /// @notice Role for administrative actions
    /// @notice Configuration for contract initialization
    struct Init {
        address admin;
    }

    // Storage
    mapping(bytes32 => address) private _contractsMap;

    bytes32 public constant L2WCT_TOKEN = keccak256("L2WCT_TOKEN");
    bytes32 public constant PERMISSIONED_NODE_REGISTRY = keccak256("PERMISSIONED_NODE_REGISTRY");
    bytes32 public constant NODE_REWARD_MANAGER = keccak256("NODE_REWARD_MANAGER");
    bytes32 public constant WALLET_REWARD_MANAGER = keccak256("WALLET_REWARD_MANAGER");
    bytes32 public constant STAKE_WEIGHT = keccak256("STAKE_WEIGHT");
    bytes32 public constant ORACLE = keccak256("ORACLE");
    bytes32 public constant PAUSER = keccak256("PAUSER");
    bytes32 public constant STAKING_REWARD_DISTRIBUTOR = keccak256("STAKING_REWARD_DISTRIBUTOR");

    /// @notice Initializes the contract
    /// @dev MUST be called during the contract upgrade to set up the proxies state
    /// @param init Initialization parameters
    function initialize(Init memory init) public initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, init.admin);
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

    /// @notice Gets the Node Reward Manager address
    /// @return The address of the Node Reward Manager contract
    function getNodeRewardManager() external view returns (address) {
        return _contractsMap[NODE_REWARD_MANAGER];
    }

    /// @notice Gets the Wallet Reward Manager address
    /// @return The address of the Wallet Reward Manager contract
    function getWalletRewardManager() external view returns (address) {
        return _contractsMap[WALLET_REWARD_MANAGER];
    }

    /// @notice Gets the StakeWeight address
    /// @return The address of the StakeWeight contract
    function getStakeWeight() external view returns (address) {
        return _contractsMap[STAKE_WEIGHT];
    }

    /// @notice Gets the Oracle address
    /// @return The address of the Oracle contract
    function getOracle() external view returns (address) {
        return _contractsMap[ORACLE];
    }

    /// @notice Gets the StakingRewardDistributor address
    /// @return The address of the StakingRewardDistributor contract
    function getStakingRewardDistributor() external view returns (address) {
        return _contractsMap[STAKING_REWARD_DISTRIBUTOR];
    }

    /// @notice Updates the L2WCT token address
    /// @param l2wct The new L2WCT token address
    function updateL2wct(address l2wct) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setContract({ key: L2WCT_TOKEN, val: l2wct });
    }

    /// @notice Updates the Pauser address
    /// @param pauser The new Pauser address
    function updatePauser(address pauser) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setContract({ key: PAUSER, val: pauser });
    }

    /// @notice Updates the Permissioned Node Registry address
    /// @param permissionedNodeRegistry The new Permissioned Node Registry address
    function updatePermissionedNodeRegistry(address permissionedNodeRegistry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setContract({ key: PERMISSIONED_NODE_REGISTRY, val: permissionedNodeRegistry });
    }

    /// @notice Updates the Node Reward Manager address
    /// @param nodeRewardManager The new Node Reward Manager address
    function updateNodeRewardManager(address nodeRewardManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setContract({ key: NODE_REWARD_MANAGER, val: nodeRewardManager });
    }

    /// @notice Updates the Wallet Reward Manager address
    /// @param walletRewardManager The new Wallet Reward Manager address
    function updateWalletRewardManager(address walletRewardManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setContract({ key: WALLET_REWARD_MANAGER, val: walletRewardManager });
    }

    /// @notice Updates the Oracle address
    /// @param oracle The new Oracle address
    function updateOracle(address oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setContract({ key: ORACLE, val: oracle });
    }

    /// @notice Updates the StakeWeight address
    /// @param stakeWeight The new StakeWeight address
    function updateStakeWeight(address stakeWeight) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setContract({ key: STAKE_WEIGHT, val: stakeWeight });
    }

    /// @notice Updates the StakingRewardDistributor address
    /// @param stakingRewardDistributor The new StakingRewardDistributor address
    function updateStakingRewardDistributor(address stakingRewardDistributor) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setContract({ key: STAKING_REWARD_DISTRIBUTOR, val: stakingRewardDistributor });
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
}
