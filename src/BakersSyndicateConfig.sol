// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.25;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UtilLib } from "./library/UtilLib.sol";

contract BakersSyndicateConfig is Initializable, OwnableUpgradeable {
    error IndenticalValue();

    event SetContract(bytes32 key, address val);
    event SetAccount(bytes32 key, address val);

    mapping(bytes32 => address) private _accountsMap;
    mapping(bytes32 => address) private _contractsMap;

    bytes32 public constant BAKERSSYNDICATE_REWARDS_VAULT = keccak256("BAKERSSYNDICATE_REWARDS_VAULT");

    bytes32 public constant BRR_TOKEN = keccak256("BRR_TOKEN");
    bytes32 public constant PERMISSIONED_NODE_REGISTRY = keccak256("PERMISSIONED_NODE_REGISTRY");
    bytes32 public constant REWARD_MANAGER = keccak256("REWARD_MANAGER");
    bytes32 public constant STAKING = keccak256("STAKING");
    bytes32 public constant PAUSER = keccak256("PAUSER");

    /// @notice Configuration for contract initialization.
    struct Init {
        address owner;
    }

    /// @notice Inititalizes the contract.
    /// @dev MUST be called during the contract upgrade to set up the proxies state.
    function initialize(Init memory init) public initializer {
        __Ownable_init(init.owner);
    }

    function getBrr() external view returns (address) {
        return _contractsMap[BRR_TOKEN];
    }

    function getPauser() external view returns (address) {
        return _contractsMap[PAUSER];
    }

    function getPermissionedNodeRegistry() external view returns (address) {
        return _contractsMap[PERMISSIONED_NODE_REGISTRY];
    }

    function getRewardManager() external view returns (address) {
        return _contractsMap[REWARD_MANAGER];
    }

    function getStaking() external view returns (address) {
        return _contractsMap[STAKING];
    }

    function getBakersSyndicateRewardsVault() external view returns (address) {
        return _accountsMap[BAKERSSYNDICATE_REWARDS_VAULT];
    }

    function updateBrr(address brr) external onlyOwner {
        setContract(BRR_TOKEN, brr);
    }

    function updatePauser(address pauser) external onlyOwner {
        setContract(PAUSER, pauser);
    }

    function updatePermissionedNodeRegistry(address permissionedNodeRegistry) external onlyOwner {
        setContract(PERMISSIONED_NODE_REGISTRY, permissionedNodeRegistry);
    }

    function updateRewardManager(address rewardManager) external onlyOwner {
        setContract(REWARD_MANAGER, rewardManager);
    }

    function updateStaking(address staking) external onlyOwner {
        setContract(STAKING, staking);
    }

    function updateBakersSyndicateRewardsVault(address bakersSyndicateRewardsVault) external onlyOwner {
        setAccount(BAKERSSYNDICATE_REWARDS_VAULT, bakersSyndicateRewardsVault);
    }

    function setContract(bytes32 key, address val) internal {
        UtilLib.checkNonZeroAddress(val);
        if (_contractsMap[key] == val) {
            revert IndenticalValue();
        }
        _contractsMap[key] = val;
        emit SetContract(key, val);
    }

    function setAccount(bytes32 key, address val) internal {
        UtilLib.checkNonZeroAddress(val);
        if (_accountsMap[key] == val) {
            revert IndenticalValue();
        }
        _accountsMap[key] = val;
        emit SetAccount(key, val);
    }

    function onlyBakersSyndicateContract(address _addr, bytes32 _contractName) external view returns (bool) {
        return (_addr == _contractsMap[_contractName]);
    }
}
