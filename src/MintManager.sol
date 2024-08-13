// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { BRR } from "./BRR.sol";

/// @title MintManager
/// @notice Set as `owner` of the BRR L1 token and responsible for the token inflation schedule.
///         Contract acts as the token "mint manager" with permission to the `mint` function only.
///         Currently permitted to mint once per year of up to 2% of the total token supply.
///         Upgradable to allow changes in the inflation schedule.
contract MintManager is Ownable {
    /// @notice The BRR token that the MintManager can mint tokens
    BRR public immutable governanceToken;

    /// @notice The amount of tokens that can be minted per year. The value is a fixed
    ///         point number with 4 decimals.
    uint256 public constant MINT_CAP = 20; // 2%

    /// @notice The number of decimals for the MINT_CAP.
    uint256 public constant DENOMINATOR = 1000;

    /// @notice The amount of time that must pass before the MINT_CAP number of tokens can
    ///         be minted again.
    uint256 public constant MINT_PERIOD = 365 days;

    /// @notice Tracks the time of last mint
    uint256 public mintPermittedAfter;

    /// @notice Emitted when tokens are minted
    /// @param account The address that received the minted tokens
    /// @param amount The amount of tokens minted
    event TokensMinted(address indexed account, uint256 amount);

    /// @notice Error thrown when minting is attempted before the permitted time
    error MintingNotPermittedYet(uint256 timestamp, uint256 mintPermittedAfter);

    /// @notice Error thrown when the mint amount exceeds the cap
    error MintAmountExceedsCap(uint256 mintAmount, uint256 maxMintAmount);

    /// @notice Error thrown when trying to upgrade to an empty address
    error MintManagerCannotBeEmpty();

    /// @param initialOwner The owner of this contract
    /// @param _governanceToken The governance token this contract can mint tokens of
    constructor(address initialOwner, address _governanceToken) Ownable(initialOwner) {
        governanceToken = BRR(_governanceToken);
    }
    /// @notice Only the token owner is allowed to mint a certain amount of BRR per year.
    /// @param account Address to mint new tokens to.
    /// @param amount Amount of tokens to be minted.

    function mint(address account, uint256 amount) public onlyOwner {
        if (mintPermittedAfter > 0) {
            if (mintPermittedAfter > block.timestamp) {
                revert MintingNotPermittedYet(block.timestamp, mintPermittedAfter);
            }

            uint256 maxMintAmount = (governanceToken.totalSupply() * MINT_CAP) / DENOMINATOR;
            if (amount > maxMintAmount) {
                revert MintAmountExceedsCap(amount, maxMintAmount);
            }
        }

        mintPermittedAfter = block.timestamp + MINT_PERIOD;

        emit TokensMinted(account, amount);
        governanceToken.mint(account, amount);
    }

    /// @notice Upgrade the owner of the governance token to a new MintManager.
    /// @param newMintManager The MintManager to upgrade to
    function upgrade(address newMintManager) public onlyOwner {
        if (newMintManager == address(0)) {
            revert MintManagerCannotBeEmpty();
        }

        governanceToken.transferOwnership(newMintManager);
    }
}
