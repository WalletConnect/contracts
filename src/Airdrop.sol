// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Airdrop
/// @notice A contract for distributing tokens via a Merkle airdrop
/// @author WalletConnect
contract Airdrop is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    address public immutable reserveAddress;
    bytes32 public immutable merkleRoot;
    IERC20 public immutable token;

    mapping(address account => bool claimed) public claimed;

    event TokensClaimed(address indexed recipient, uint256 amount);

    error InvalidReserveAddress();
    error InvalidTokenAddress();
    error InvalidMerkleRoot();
    error InvalidAmount();
    error AlreadyClaimed();
    error InvalidProof();

    /// @notice Initializes the Airdrop contract
    /// @param initialAdmin Address to be granted the default admin role
    /// @param initialPauser Address to be granted the pauser role
    /// @param reserveAddress_ Address holding tokens to be distributed
    /// @param merkleRoot_ Root of the Merkle tree containing claim data
    /// @param token_ Address of the token to be distributed
    constructor(
        address initialAdmin,
        address initialPauser,
        address reserveAddress_,
        bytes32 merkleRoot_,
        address token_
    )
        Pausable()
        ReentrancyGuard()
    {
        if (reserveAddress_ == address(0)) revert InvalidReserveAddress();
        if (token_ == address(0)) revert InvalidTokenAddress();
        if (merkleRoot_ == bytes32(0)) revert InvalidMerkleRoot();

        reserveAddress = reserveAddress_;
        merkleRoot = merkleRoot_;
        token = IERC20(token_);

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(PAUSER_ROLE, initialPauser);
    }

    /// @notice Allows a user to claim their tokens
    /// @param index Index of the claim in the Merkle tree
    /// @param amount Amount of tokens to claim
    /// @param merkleProof Merkle proof verifying the claim
    function claimTokens(
        uint256 index,
        uint256 amount,
        bytes32[] calldata merkleProof
    )
        external
        whenNotPaused
        nonReentrant
    {
        if (amount == 0) revert InvalidAmount();
        if (claimed[msg.sender]) revert AlreadyClaimed();

        claimed[msg.sender] = true;

        bytes32 node = keccak256(abi.encodePacked(index, msg.sender, amount));
        if (!MerkleProof.verify(merkleProof, merkleRoot, node)) revert InvalidProof();

        token.safeTransferFrom(reserveAddress, msg.sender, amount);

        emit TokensClaimed({ recipient: msg.sender, amount: amount });
    }

    /// @notice Pauses the contract
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Unpauses the contract
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}
