// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { AccessControlEnumerable } from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

contract Pauser is AccessControlEnumerable {
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
        address admin;
        address pauser;
        address unpauser;
    }

    constructor(Init memory init) {
        _grantRole(DEFAULT_ADMIN_ROLE, init.admin);
        _grantRole(PAUSER_ROLE, init.pauser);
        _grantRole(UNPAUSER_ROLE, init.unpauser);
    }

    /// @notice Pauses or unpauses staking.
    /// @dev If pausing, checks if the caller has the pauser role. If unpausing,
    /// checks if the caller has the unpauser role.
    function setIsStakingPaused(bool isPaused) external onlyPauserUnpauserRole(isPaused) {
        _setIsStakingPaused(isPaused);
    }

    /// @notice Pauses or unpauses submit oracle records.
    /// @dev If pausing, checks if the caller has the pauser role. If unpausing,
    /// checks if the caller has the unpauser role.
    function setIsSubmitOracleRecordsPaused(bool isPaused) external onlyPauserUnpauserRole(isPaused) {
        _setIsSubmitOracleRecordsPaused(isPaused);
    }

    /// @notice Pauses all actions.
    /// @dev Can be called by the oracle or any account with the pauser role.
    function pauseAll() external onlyRole(PAUSER_ROLE) {
        _setIsStakingPaused(true);
        _setIsSubmitOracleRecordsPaused(true);
    }

    /// @notice Unpauses all actions.
    function unpauseAll() external onlyRole(UNPAUSER_ROLE) {
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

    modifier onlyPauserUnpauserRole(bool isPaused) {
        if (isPaused) {
            _checkRole(PAUSER_ROLE);
        } else {
            _checkRole(UNPAUSER_ROLE);
        }
        _;
    }
}
