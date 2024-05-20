// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.25;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { UtilLib } from "./library/UtilLib.sol";

contract WalletConnectConfig is Ownable {
    error IndenticalValue();

    event SetContract(bytes32 key, address val);

    mapping(bytes32 => address) private contractsMap;

    bytes32 public constant CNCT_TOKEN = keccak256("CNCT_TOKEN");
    bytes32 public constant PERMISSIONED_NODE_REGISTRY = keccak256("PERMISSIONED_NODE_REGISTRY");

    constructor(address initialOwner) Ownable(initialOwner) { }

    function getCnct() external view returns (address) {
        return contractsMap[CNCT_TOKEN];
    }

    function getPermissionedNodeRegistry() external view returns (address) {
        return contractsMap[PERMISSIONED_NODE_REGISTRY];
    }

    function updateCnct(address cnct) external onlyOwner {
        setContract(CNCT_TOKEN, cnct);
    }

    function updatePermissionedNodeRegistry(address permissionedNodeRegistry) external onlyOwner {
        setContract(PERMISSIONED_NODE_REGISTRY, permissionedNodeRegistry);
    }

    function setContract(bytes32 key, address val) internal {
        UtilLib.checkNonZeroAddress(val);
        if (contractsMap[key] == val) {
            revert IndenticalValue();
        }
        contractsMap[key] = val;
        emit SetContract(key, val);
    }
}
