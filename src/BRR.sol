// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { ERC20VotesUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import { ERC20PermitUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import { NoncesUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ERC20BurnableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

/// @title BRR Token
/// @notice This contract implements the L1 BRR token with burn, permit, and voting functionality
/// @author BakersSyndicate
contract BRR is ERC20VotesUpgradeable, ERC20PermitUpgradeable, ERC20BurnableUpgradeable, OwnableUpgradeable {
    /// @notice Initialization data for the contract
    struct Init {
        /// @dev The address that will be the initial owner of the contract
        address initialOwner;
    }

    /// @notice Initializes the BRR token
    /// @param init The initialization data for the contract
    function initialize(Init calldata init) public initializer {
        __ERC20_init({ name_: "Brownie", symbol_: "BRR" });
        __ERC20Permit_init("Brownie");
        __ERC20Votes_init();
        __Ownable_init({ initialOwner: init.initialOwner });
    }

    /// @notice Mints new tokens
    /// @param account The address that will receive the minted tokens
    /// @param amount The amount of tokens to mint
    /// @dev Only the owner (MintManager) can call this function
    function mint(address account, uint256 amount) external onlyOwner {
        _mint({ account: account, value: amount });
    }

    /// @notice Returns the current timestamp as a uint48
    /// @return The current block timestamp
    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    /// @notice Returns the clock mode
    /// @return A string indicating the clock mode
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256 value
    )
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._update(from, to, value);
    }

    function nonces(address nonceOwner)
        public
        view
        override(ERC20PermitUpgradeable, NoncesUpgradeable)
        returns (uint256)
    {
        return super.nonces(nonceOwner);
    }
}
