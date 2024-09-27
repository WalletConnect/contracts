// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25;

struct Users {
    // Admin
    address payable admin;
    // Manager
    address payable manager;
    // Timelock canceller
    address payable timelockCanceller;
    // Treasury
    address treasury;
    // Attacker
    address payable attacker;
    // Permissioned Node
    address payable permissionedNode;
    // Non-Permissioned Node
    address payable nonPermissionedNode;
    // Bob: User
    address payable bob;
    // Alice: User
    address payable alice;
}
