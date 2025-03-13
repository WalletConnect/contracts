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
import { NttTokenUpgradeable } from "src/NttTokenUpgradeable.sol";
import { INttToken } from "src/interfaces/INttToken.sol";

/// @title WCT Token
/// @notice This contract implements the L1 WCT token with burn, permit, and voting functionality
/// @author WalletConnect
contract WCT is NttTokenUpgradeable, ERC20VotesUpgradeable, ERC20PermitUpgradeable, OwnableUpgradeable {
    /// @notice Initialization data for the contract
    struct Init {
        /// @dev The address that will be the initial owner of the contract
        address initialOwner;
        /// @dev The initial minter address
        address initialMinter;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the WCT token
    /// @param init The initialization data for the contract
    function initialize(Init calldata init) public initializer {
        __NttToken_init(init.initialMinter, "WalletConnect", "WCT");
        __ERC20Permit_init("WalletConnect");
        __ERC20Votes_init();
        __ERC20Burnable_init();
        __Ownable_init({ initialOwner: init.initialOwner });
    }

    /// @notice A function to set the new minter for the tokens.
    /// @param newMinter The address to add as both a minter and burner.
    function setMinter(address newMinter) external override onlyOwner {
        _setMinter(newMinter);
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
