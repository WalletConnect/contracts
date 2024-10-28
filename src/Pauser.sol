// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title Pauser
/// @notice Contract for managing pause states of various system functions
/// @author WalletConnect
contract Pauser is Initializable, AccessControlUpgradeable {
    /// @notice Emitted when a flag has been updated
    /// @param selector The selector of the flag that was updated
    /// @param isPaused The new value of the flag
    /// @param flagName The name of the flag that was updated
    event FlagUpdated(bytes4 indexed selector, bool indexed isPaused, string flagName);

    error InvalidInput();

    /// @notice Role for pausing functions
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Role for unpausing functions
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");

    /// @notice Flag indicating if stakeWeight is paused
    bool public isStakeWeightPaused;

    /// @notice Flag indicating if submit oracle records is paused
    bool public isSubmitOracleRecordsPaused;

    /// @notice Configuration for contract initialization
    struct Init {
        address admin;
        address pauser;
    }

    /// @notice Initializes the contract
    /// @dev MUST be called during the contract upgrade to set up the proxies state
    /// @param init Initialization parameters
    function initialize(Init memory init) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, init.admin);
        if (init.pauser == address(0)) {
            revert InvalidInput();
        }
        _grantRole(PAUSER_ROLE, init.pauser);
        _grantRole(UNPAUSER_ROLE, init.admin);
    }

    /// @notice Pauses or unpauses staking
    /// @param isPaused The new pause state
    function setIsStakeWeightPaused(bool isPaused) external {
        if (isPaused) {
            _checkRole(PAUSER_ROLE);
        } else {
            _checkRole(UNPAUSER_ROLE);
        }
        _setIsStakeWeightPaused(isPaused);
    }

    /// @notice Pauses or unpauses submit oracle records
    /// @param isPaused The new pause state
    function setIsSubmitOracleRecordsPaused(bool isPaused) external {
        if (isPaused) {
            _checkRole(PAUSER_ROLE);
        } else {
            _checkRole(UNPAUSER_ROLE);
        }
        _setIsSubmitOracleRecordsPaused(isPaused);
    }

    /// @notice Pauses all actions
    function pauseAll() external onlyRole(PAUSER_ROLE) {
        _setIsStakeWeightPaused(true);
        _setIsSubmitOracleRecordsPaused(true);
    }

    /// @notice Unpauses all actions
    function unpauseAll() external onlyRole(UNPAUSER_ROLE) {
        _setIsStakeWeightPaused(false);
        _setIsSubmitOracleRecordsPaused(false);
    }

    /// @dev Sets the staking pause state
    /// @param isPaused The new pause state
    function _setIsStakeWeightPaused(bool isPaused) private {
        isStakeWeightPaused = isPaused;
        emit FlagUpdated({
            selector: this.isStakeWeightPaused.selector,
            isPaused: isPaused,
            flagName: "isStakeWeightPaused"
        });
    }

    /// @dev Sets the submit oracle records pause state
    /// @param isPaused The new pause state
    function _setIsSubmitOracleRecordsPaused(bool isPaused) private {
        isSubmitOracleRecordsPaused = isPaused;
        emit FlagUpdated({
            selector: this.isSubmitOracleRecordsPaused.selector,
            isPaused: isPaused,
            flagName: "isSubmitOracleRecordsPaused"
        });
    }
}
