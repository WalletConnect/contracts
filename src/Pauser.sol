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

    /// @notice Flag indicating if locked token staker is paused
    bool public isLockedTokenStakerPaused;

    /// @notice Flag indicating if node reward manager is paused
    bool public isNodeRewardManagerPaused;

    /// @notice Flag indicating if wallet reward manager is paused
    bool public isWalletRewardManagerPaused;

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

    /// @notice Pauses or unpauses locked token staker
    /// @param isPaused The new pause state
    function setIsLockedTokenStakerPaused(bool isPaused) external {
        if (isPaused) {
            _checkRole(PAUSER_ROLE);
        } else {
            _checkRole(UNPAUSER_ROLE);
        }
        _setIsLockedTokenStakerPaused(isPaused);
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

    /// @notice Pauses or unpauses node reward manager
    /// @param isPaused The new pause state
    function setIsNodeRewardManagerPaused(bool isPaused) external {
        if (isPaused) {
            _checkRole(PAUSER_ROLE);
        } else {
            _checkRole(UNPAUSER_ROLE);
        }
        _setIsNodeRewardManagerPaused(isPaused);
    }

    /// @notice Pauses or unpauses wallet reward manager
    /// @param isPaused The new pause state
    function setIsWalletRewardManagerPaused(bool isPaused) external {
        if (isPaused) {
            _checkRole(PAUSER_ROLE);
        } else {
            _checkRole(UNPAUSER_ROLE);
        }
        _setIsWalletRewardManagerPaused(isPaused);
    }

    /// @dev Sets the node reward manager pause state
    /// @param isPaused The new pause state
    function _setIsNodeRewardManagerPaused(bool isPaused) private {
        isNodeRewardManagerPaused = isPaused;
        emit FlagUpdated({
            selector: this.isNodeRewardManagerPaused.selector,
            isPaused: isPaused,
            flagName: "isNodeRewardManagerPaused"
        });
    }

    /// @dev Sets the wallet reward manager pause state
    /// @param isPaused The new pause state
    function _setIsWalletRewardManagerPaused(bool isPaused) private {
        isWalletRewardManagerPaused = isPaused;
        emit FlagUpdated({
            selector: this.isWalletRewardManagerPaused.selector,
            isPaused: isPaused,
            flagName: "isWalletRewardManagerPaused"
        });
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

    /// @dev Sets the locked token staker pause state
    /// @param isPaused The new pause state
    function _setIsLockedTokenStakerPaused(bool isPaused) private {
        isLockedTokenStakerPaused = isPaused;
        emit FlagUpdated({
            selector: this.isLockedTokenStakerPaused.selector,
            isPaused: isPaused,
            flagName: "isLockedTokenStakerPaused"
        });
    }
}
