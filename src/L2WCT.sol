// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { Nonces } from "@openzeppelin/contracts/utils/Nonces.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IOptimismMintableERC20, ILegacyMintableERC20 } from "src/interfaces/IOptimismMintableERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { ISemver } from "src/interfaces/ISemver.sol";

contract L2WCT is IOptimismMintableERC20, ILegacyMintableERC20, ERC20Permit, ERC20Votes, AccessControl, ISemver {
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
    address public immutable REMOTE_TOKEN;

    /// @notice Address of the StandardBridge on this network
    address public immutable BRIDGE;

    /// @notice Emitted whenever tokens are minted for an account
    /// @param account Address of the account tokens are being minted for
    /// @param amount Amount of tokens minted
    event Mint(address indexed account, uint256 amount);

    /// @notice Emitted whenever tokens are burned from an account
    /// @param account Address of the account tokens are being burned from
    /// @param amount Amount of tokens burned
    event Burn(address indexed account, uint256 amount);

    /// @notice Custom errors
    error OnlyBridge();
    error TransferRestrictionsAlreadyDisabled();
    error TransferRestricted();
    error InvalidAddress();

    /// @notice A modifier that only allows the bridge to call
    modifier onlyBridge() {
        if (msg.sender != BRIDGE) revert OnlyBridge();
        _;
    }

    /// @notice Semantic version
    /// @custom:semver 1.0.0
    string public constant version = "1.0.0";

    /// @notice Role for managing allowed addresses
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @param initialAdmin Address of the initial admin of the contract
    /// @param initialManager Address of the initial manager of the contract
    /// @param _bridge Address of the L2 standard bridge
    /// @param _remoteToken Address of the corresponding L1 token
    constructor(
        address initialAdmin,
        address initialManager,
        address _bridge,
        address _remoteToken
    )
        ERC20("WalletConnect", "WCT")
        ERC20Permit("WalletConnect")
    {
        if (_remoteToken == address(0)) revert InvalidAddress();
        if (_bridge == address(0)) revert InvalidAddress();
        if (initialAdmin == address(0)) revert InvalidAddress();
        if (initialManager == address(0)) revert InvalidAddress();
        REMOTE_TOKEN = _remoteToken;
        BRIDGE = _bridge;
        // Set transfer restrictions to be disabled at type(uint256).max to be set down later
        transferRestrictionsDisabledAfter = type(uint256).max;

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(MANAGER_ROLE, initialManager);
    }

    /// @custom:legacy
    /// @notice Legacy getter for the remote token. Use REMOTE_TOKEN going forward
    function l1Token() public view returns (address) {
        return REMOTE_TOKEN;
    }

    /// @custom:legacy
    /// @notice Legacy getter for the bridge. Use BRIDGE going forward
    function l2Bridge() public view returns (address) {
        return BRIDGE;
    }

    /// @custom:legacy
    /// @notice Legacy getter for REMOTE_TOKEN
    function remoteToken() public view returns (address) {
        return REMOTE_TOKEN;
    }

    /// @custom:legacy
    /// @notice Legacy getter for BRIDGE
    function bridge() public view returns (address) {
        return BRIDGE;
    }

    /// @notice ERC165 interface check function
    /// @param interfaceId Interface ID to check
    /// @return Whether or not the interface is supported by this contract
    function supportsInterface(bytes4 interfaceId) public view override(AccessControl, IERC165) returns (bool) {
        return interfaceId == type(ILegacyMintableERC20).interfaceId
            || interfaceId == type(IOptimismMintableERC20).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice Allows the StandardBridge on this network to mint tokens
    /// @param _to Address to mint tokens to
    /// @param _amount Amount of tokens to mint
    function mint(
        address _to,
        uint256 _amount
    )
        external
        virtual
        override(IOptimismMintableERC20, ILegacyMintableERC20)
        onlyBridge
    {
        _mint(_to, _amount);
        emit Mint(_to, _amount);
    }

    /// @notice Allows the StandardBridge on this network to burn tokens
    /// @param _from Address to burn tokens from
    /// @param _amount Amount of tokens to burn
    function burn(
        address _from,
        uint256 _amount
    )
        external
        virtual
        override(IOptimismMintableERC20, ILegacyMintableERC20)
        onlyBridge
    {
        _burn(_from, _amount);
        emit Burn(_from, _amount);
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
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
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

    function nonces(address nonceOwner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(nonceOwner);
    }
}
