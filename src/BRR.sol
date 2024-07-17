// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title BRR Token
/// @notice This contract implements the L1 BRR token with burn, permit, and voting functionality
contract BRR is ERC20, ERC20Burnable, ERC20Permit, ERC20Votes, Ownable {
    /// @notice Constructs the BRR token
    /// @param initialOwner The address that will own the contract and have minting rights
    constructor(address initialOwner) ERC20("Brownie", "BRR") ERC20Permit("Brownie") Ownable(initialOwner) { }

    /// @notice Mints new tokens
    /// @param account The address that will receive the minted tokens
    /// @param amount The amount of tokens to mint
    /// @dev Only the owner (MintManager) can call this function
    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
