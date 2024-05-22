// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Pauser is Initializable, OwnableUpgradeable {
    /*//////////////////////////////////////////////////////////////////////////
                                    EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a flag has been updated.
    /// @param selector The selector of the flag that was updated.
    /// @param isPaused The new value of the flag.
    /// @param flagName The name of the flag that was updated.
    event FlagUpdated(bytes4 indexed selector, bool indexed isPaused, string flagName);

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Pauser role can pause flags in the contract.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Unpauser role can unpause flags in the contract.
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");

    /// @notice Flag indicating if staking is paused.
    bool public isStakingPaused;

    /// @notice Flag indicating if submit oracle records is paused.
    bool public isSubmitOracleRecordsPaused;

    /// @notice Configuration for contract initialization.
    struct Init {
        address owner;
    }

    /// @notice Initializes the contract.
    /// @dev MUST be called during the contract upgrade to set up the proxies state.
    function initialize(Init memory init) external initializer {
        __Ownable_init(init.owner);
    }

    /// @notice Pauses or unpauses staking.
    /// @dev If pausing, checks if the caller has the pauser role. If unpausing,
    /// checks if the caller has the unpauser role.
    function setIsStakingPaused(bool isPaused) external onlyOwner {
        _setIsStakingPaused(isPaused);
    }

    /// @notice Pauses or unpauses submit oracle records.
    /// @dev If pausing, checks if the caller has the pauser role. If unpausing,
    /// checks if the caller has the unpauser role.
    function setIsSubmitOracleRecordsPaused(bool isPaused) external onlyOwner {
        _setIsSubmitOracleRecordsPaused(isPaused);
    }

    /// @notice Pauses all actions.
    /// @dev Can be called by the oracle or any account with the pauser role.
    function pauseAll() external onlyOwner {
        _setIsStakingPaused(true);
        _setIsSubmitOracleRecordsPaused(true);
    }

    /// @notice Unpauses all actions.
    function unpauseAll() external onlyOwner {
        _setIsStakingPaused(false);
        _setIsSubmitOracleRecordsPaused(false);
    }

    // Internal setter functions.
    function _setIsStakingPaused(bool isPaused) internal {
        isStakingPaused = isPaused;
        emit FlagUpdated(this.isStakingPaused.selector, isPaused, "isStakingPaused");
    }

    function _setIsSubmitOracleRecordsPaused(bool isPaused) internal {
        isSubmitOracleRecordsPaused = isPaused;
        emit FlagUpdated(this.isSubmitOracleRecordsPaused.selector, isPaused, "isSubmitOracleRecordsPaused");
    }
}
