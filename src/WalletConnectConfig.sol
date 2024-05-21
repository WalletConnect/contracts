// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.25;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { UtilLib } from "./library/UtilLib.sol";

contract WalletConnectConfig is Ownable {
    error IndenticalValue();

    event SetContract(bytes32 key, address val);
    event SetAccount(bytes32 key, address val);

    mapping(bytes32 => address) private _accountsMap;
    mapping(bytes32 => address) private _contractsMap;

    bytes32 public constant WALLETCONNECT_REWARDS_VAULT = keccak256("WALLETCONNECT_REWARDS_VAULT");

    bytes32 public constant CNCT_TOKEN = keccak256("CNCT_TOKEN");
    bytes32 public constant PERMISSIONED_NODE_REGISTRY = keccak256("PERMISSIONED_NODE_REGISTRY");
    bytes32 public constant REWARD_MANAGER = keccak256("REWARD_MANAGER");
    bytes32 public constant STAKING = keccak256("STAKING");
    bytes32 public constant PAUSER = keccak256("PAUSER");

    constructor(address initialOwner) Ownable(initialOwner) { }

    function getCnct() external view returns (address) {
        return _contractsMap[CNCT_TOKEN];
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

    function getWalletConnectRewardsVault() external view returns (address) {
        return _accountsMap[WALLETCONNECT_REWARDS_VAULT];
    }

    function updateCnct(address cnct) external onlyOwner {
        setContract(CNCT_TOKEN, cnct);
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

    function updateWalletConnectRewardsVault(address walletConnectRewardsVault) external onlyOwner {
        setAccount(WALLETCONNECT_REWARDS_VAULT, walletConnectRewardsVault);
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

    function onlyWalletConnectContract(address _addr, bytes32 _contractName) external view returns (bool) {
        return (_addr == _contractsMap[_contractName]);
    }
}
