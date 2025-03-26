// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ERC20PermitUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import { ERC20VotesUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import { ERC20BurnableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import { NoncesUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { ISemver } from "src/interfaces/ISemver.sol";
import { IERC7802 } from "src/interfaces/IERC7802.sol";
import { INttToken } from "src/interfaces/INttToken.sol";
import { NttTokenUpgradeable } from "src/NttTokenUpgradeable.sol";

contract L2WCT is
    NttTokenUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    AccessControlUpgradeable,
    ISemver,
    IERC7802
{
    /// @notice The timestamp after which transfer restrictions are disabled
    uint256 public transferRestrictionsDisabledAfter;
    /// @notice Mapping of addresses that are allowed to transfer tokens to any address
    mapping(address account => bool isAllowed) public allowedFrom;
    /// @notice Mapping of addresses that are allowed to receive tokens from any address
    mapping(address account => bool isAllowed) public allowedTo;

    /// @notice Emitted when the allowedFrom status of an address is set
    event SetAllowedFrom(address indexed from, bool isAllowedFrom);
    /// @notice Emitted when the allowedTo status of an address is set
    event SetAllowedTo(address indexed to, bool isAllowedTo);
    /// @notice Emitted when the transfer restrictions are disabled
    event TransferRestrictionsDisabled();

    /// @notice Address of the corresponding version of this token on the remote chain
    /// @custom:deprecated This storage variable is no longer used but preserved for storage layout compatibility
    /// @custom:oz-renamed-from REMOTE_TOKEN
    address public REMOTE_TOKEN_DEPRECATED;

    /// @notice Address of the StandardBridge on this network
    /// @custom:deprecated This storage variable is no longer used but preserved for storage layout compatibility
    /// @custom:oz-renamed-from BRIDGE
    address public BRIDGE_DEPRECATED;

    /// @notice Custom errors
    error TransferRestrictionsAlreadyDisabled();
    error TransferRestricted();
    error InvalidAddress();
    error CallerNotBridge(address caller);

    /// @notice Emitted when the bridge address is changed
    event NewBridge(address previousBridge, address newBridge);

    /// @notice Semantic version
    /// @custom:semver 2.0.0
    string public constant version = "2.0.0";

    /// @notice Role for managing allowed addresses
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    // =============== Storage ==============================================================

    struct BridgeStorage {
        address _bridge;
    }

    bytes32 private constant BRIDGE_SLOT = bytes32(uint256(keccak256("walletconnect.bridge")) - 1);

    // =============== Storage Getters/Setters ==============================================

    function _getBridgeStorage() internal pure returns (BridgeStorage storage $) {
        uint256 slot = uint256(BRIDGE_SLOT);
        assembly ("memory-safe") {
            $.slot := slot
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialization data for the contract
    struct Init {
        /// @dev The address that will be the initial admin of the contract
        address initialAdmin;
        /// @dev The address that will be the initial manager of the contract
        address initialManager;
        /// @dev Initial minter address
        address initialMinter;
        /// @dev Initial bridge address for cross-chain operations
        address initialBridge;
    }

    /// @notice Initializes the L2WCT token
    function initialize(Init memory init) public initializer {
        __NttToken_init(init.initialMinter, "WalletConnect", "WCT");
        __ERC20Permit_init("WalletConnect");
        __ERC20Votes_init();
        __AccessControl_init();

        if (init.initialAdmin == address(0)) revert InvalidAddress();
        if (init.initialManager == address(0)) revert InvalidAddress();

        // Set transfer restrictions to be disabled at type(uint256).max to be set down later
        transferRestrictionsDisabledAfter = type(uint256).max;

        _grantRole(DEFAULT_ADMIN_ROLE, init.initialAdmin);
        _grantRole(MANAGER_ROLE, init.initialManager);

        // Set initial bridge if provided
        if (init.initialBridge != address(0)) {
            _getBridgeStorage()._bridge = init.initialBridge;
            emit NewBridge(address(0), init.initialBridge);
        }
    }

    /// @custom:legacy
    /// @notice Legacy getter for the remote token. Preserved for storage layout compatibility.
    /// @custom:oz-renamed-from l1Token
    function l1TokenDeprecated() public view returns (address) {
        return REMOTE_TOKEN_DEPRECATED;
    }

    /// @custom:legacy
    /// @notice Legacy getter for the bridge. Preserved for storage layout compatibility.
    /// @custom:oz-renamed-from l2Bridge
    function l2BridgeDeprecated() public view returns (address) {
        return BRIDGE_DEPRECATED;
    }

    /// @custom:legacy
    /// @notice Legacy getter for REMOTE_TOKEN. Preserved for storage layout compatibility.
    /// @custom:oz-renamed-from remoteToken
    function remoteTokenDeprecated() public view returns (address) {
        return REMOTE_TOKEN_DEPRECATED;
    }

    /// @custom:legacy
    /// @notice Legacy getter for BRIDGE. Preserved for storage layout compatibility.
    /// @custom:oz-renamed-from bridge
    function bridgeDeprecated() public view returns (address) {
        return BRIDGE_DEPRECATED;
    }

    /// @notice ERC165 interface check function
    /// @param interfaceId Interface ID to check
    /// @return Whether or not the interface is supported by this contract
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlUpgradeable, IERC165, NttTokenUpgradeable)
        returns (bool)
    {
        return interfaceId == type(IERC7802).interfaceId || NttTokenUpgradeable.supportsInterface(interfaceId)
            || AccessControlUpgradeable.supportsInterface(interfaceId);
    }

    /// @notice A function to set the new minter for the tokens.
    /// @param newMinter The address to add as both a minter and burner.
    function setMinter(address newMinter) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _setMinter(newMinter);
    }

    /// @notice A function to set the new bridge for cross-chain operations.
    /// @param newBridge The address to set as the bridge.
    function setBridge(address newBridge) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newBridge == address(0)) {
            revert InvalidAddress();
        }
        address previousBridge = _getBridgeStorage()._bridge;
        _getBridgeStorage()._bridge = newBridge;
        emit NewBridge(previousBridge, newBridge);
    }

    /// @dev Returns the address of the current bridge.
    function crosschainBridge() public view returns (address) {
        BridgeStorage storage $ = _getBridgeStorage();
        return $._bridge;
    }

    /// @dev Throws if called by any account other than the bridge.
    modifier onlyBridge() {
        if (crosschainBridge() != _msgSender()) {
            revert CallerNotBridge(_msgSender());
        }
        _;
    }

    /// @notice Mint tokens through a crosschain transfer.
    /// @param _to Address to mint tokens to.
    /// @param _amount Amount of tokens to mint.
    function crosschainMint(address _to, uint256 _amount) external override onlyBridge {
        _mint(_to, _amount);
        emit CrosschainMint(_to, _amount, msg.sender);
    }

    /// @notice Burn tokens through a crosschain transfer.
    /// @param _from Address to burn tokens from.
    /// @param _amount Amount of tokens to burn.
    function crosschainBurn(address _from, uint256 _amount) external override onlyBridge {
        _burn(_from, _amount);
        emit CrosschainBurn(_from, _amount, msg.sender);
    }

    /// @notice This function allows the manager to set the allowedFrom status of an address
    /// @param from The address whose allowedFrom status is being set
    /// @param isAllowedFrom The new allowedFrom status
    function setAllowedFrom(address from, bool isAllowedFrom) external onlyRole(MANAGER_ROLE) {
        _setAllowedFrom(from, isAllowedFrom);
    }

    /// @notice This function allows the manager to set the allowedTo status of an address
    /// @param to The address whose allowedTo status is being set
    /// @param isAllowedTo The new allowedTo status
    function setAllowedTo(address to, bool isAllowedTo) external onlyRole(MANAGER_ROLE) {
        _setAllowedTo(to, isAllowedTo);
    }

    /// @notice Allows the admin to disable transfer restrictions
    function disableTransferRestrictions() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (transferRestrictionsDisabledAfter != type(uint256).max) {
            revert TransferRestrictionsAlreadyDisabled();
        }
        transferRestrictionsDisabledAfter = 0;
        emit TransferRestrictionsDisabled();
    }

    /// @dev Clock used for flagging checkpoints. Has been overridden to implement timestamp based
    /// checkpoints (and voting)
    function clock() public view override returns (uint48) {
        return SafeCast.toUint48(block.timestamp);
    }

    /// @dev Machine-readable description of the clock as specified in EIP-6372.
    /// Has been overridden to inform callers that this contract uses timestamps instead of block numbers, to match
    /// `clock()`
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    function _setAllowedFrom(address from, bool isAllowedFrom) internal {
        allowedFrom[from] = isAllowedFrom;
        emit SetAllowedFrom(from, isAllowedFrom);
    }

    function _setAllowedTo(address to, bool isAllowedTo) internal {
        allowedTo[to] = isAllowedTo;
        emit SetAllowedTo(to, isAllowedTo);
    }

    /// @notice Overrides the update function to enforce transfer restrictions
    /// @param from The address tokens are being transferred from
    /// @param to The address tokens are being transferred to
    /// @param value The amount of tokens being transferred
    function _update(
        address from,
        address to,
        uint256 value
    )
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        // If transfer restrictions are enabled
        if (block.timestamp <= transferRestrictionsDisabledAfter) {
            // If both from and to are not whitelisted
            if (!allowedFrom[from] && !allowedTo[to] && from != address(0)) {
                revert TransferRestricted();
            }
        }
        super._update(from, to, value);
    }

    // The following functions are overrides required by Solidity.

    function nonces(address nonceOwner)
        public
        view
        override(ERC20PermitUpgradeable, NoncesUpgradeable)
        returns (uint256)
    {
        return super.nonces(nonceOwner);
    }
}
