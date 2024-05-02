// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WalletConnectToken is ERC20, ERC20Burnable, ERC20Permit, ERC20Votes, Ownable {
    /**
     * @dev Constructor
     */
    constructor(address initialOwner)
        ERC20("WalletConnectToken", "WAL")
        ERC20Permit("WalletConnectToken")
        Ownable(initialOwner)
    { }

    function mint(address _account, uint256 _amount) public onlyOwner {
        _mint(_account, _amount);
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
