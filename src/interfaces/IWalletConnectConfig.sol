// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IWalletConnectConfig {
    function getCnct() external view returns (address);
    function getPermissionedNodeRegistry() external view returns (address);
}
