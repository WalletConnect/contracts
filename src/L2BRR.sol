// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { Nonces } from "@openzeppelin/contracts/utils/Nonces.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IOptimismMintableERC20 } from "./IOptimismMintableERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract L2BRR is IOptimismMintableERC20, ERC20Permit, ERC20Votes, Ownable {
    /// @notice the timestamp after which transfer restrictions are disabled
    uint256 public transferRestrictionsDisabledAfter;
    /// @notice mapping of addresses that are allowed to transfer tokens to any address
    mapping(address => bool) public allowedFrom;
    /// @notice mapping of addresses that are allowed to receive tokens from any address
    mapping(address => bool) public allowedTo;

    /// @notice event emitted when the allowedFrom status of an address is set
    event SetAllowedFrom(address indexed from, bool isAllowedFrom);
    /// @notice event emitted when the allowedTo status of an address is set
    event SetAllowedTo(address indexed to, bool isAllowedTo);
    /// @notice event emitted when the transfer restrictions are set to be disabled after one year in the future
    event TransferRestrictionsDisabledOneYearInFuture();

    /// @notice Address of the corresponding version of this token on the remote chain.
    address public immutable REMOTE_TOKEN;

    /// @notice Address of the StandardBridge on this network.
    address public immutable BRIDGE;

    /// @notice Emitted whenever tokens are minted for an account.
    /// @param account Address of the account tokens are being minted for.
    /// @param amount  Amount of tokens minted.
    event Mint(address indexed account, uint256 amount);

    /// @notice Emitted whenever tokens are burned from an account.
    /// @param account Address of the account tokens are being burned from.
    /// @param amount  Amount of tokens burned.
    event Burn(address indexed account, uint256 amount);

    /// @notice A modifier that only allows the bridge to call.
    modifier onlyBridge() {
        require(msg.sender == BRIDGE, "L2BRR: only bridge can mint and burn");
        _;
    }

    /// @param initialOwner Address of the initial owner of the contract.
    /// @param _bridge      Address of the L2 standard bridge.
    /// @param _remoteToken Address of the corresponding L1 token.
    /// @param _name        ERC20 name.
    /// @param _symbol      ERC20 symbol.
    constructor(
        address initialOwner,
        address _bridge,
        address _remoteToken,
        string memory _name,
        string memory _symbol
    )
        ERC20(_name, _symbol)
        ERC20Permit(_name)
        Ownable(initialOwner)
    {
        REMOTE_TOKEN = _remoteToken;
        BRIDGE = _bridge;
        // set transfer restrictions to be disabled at type(uint256).max to be set down later
        transferRestrictionsDisabledAfter = type(uint256).max;
    }

    /// @custom:legacy
    /// @notice Legacy getter for REMOTE_TOKEN.
    function remoteToken() public view returns (address) {
        return REMOTE_TOKEN;
    }

    /// @custom:legacy
    /// @notice Legacy getter for BRIDGE.
    function bridge() public view returns (address) {
        return BRIDGE;
    }

    /// @notice ERC165 interface check function.
    /// @param _interfaceId Interface ID to check.
    /// @return Whether or not the interface is supported by this contract.
    function supportsInterface(bytes4 _interfaceId) external pure virtual returns (bool) {
        bytes4 iface1 = type(IERC165).interfaceId;
        // Interface corresponding to the updated OptimismMintableERC20 (this contract).
        bytes4 iface2 = type(IOptimismMintableERC20).interfaceId;
        return _interfaceId == iface1 || _interfaceId == iface2;
    }

    /// @notice Allows the StandardBridge on this network to mint tokens.
    /// @param _to     Address to mint tokens to.
    /// @param _amount Amount of tokens to mint.
    function mint(address _to, uint256 _amount) external virtual override(IOptimismMintableERC20) onlyBridge {
        _mint(_to, _amount);
        emit Mint(_to, _amount);
    }

    /// @notice Allows the StandardBridge on this network to burn tokens.
    /// @param _from   Address to burn tokens from.
    /// @param _amount Amount of tokens to burn.
    function burn(address _from, uint256 _amount) external virtual override(IOptimismMintableERC20) onlyBridge {
        _burn(_from, _amount);
        emit Burn(_from, _amount);
    }

    /**
     * s
     * @notice This function allows the owner to set the allowedFrom status of an address
     * @param from the address whose allowedFrom status is being set
     * @param isAllowedFrom the new allowedFrom status
     */
    function setAllowedFrom(address from, bool isAllowedFrom) external onlyOwner {
        _setAllowedFrom(from, isAllowedFrom);
    }

    /**
     * @notice This function allows the owner to set the allowedTo status of an address
     * @param to the address whose allowedTo status is being set
     * @param isAllowedTo the new allowedTo status
     */
    function setAllowedTo(address to, bool isAllowedTo) external onlyOwner {
        _setAllowedTo(to, isAllowedTo);
    }

    /**
     * @notice This function allows the owner to set the transfer restrictions to be disabled after one year in the
     * future
     */
    function setTransferRestrictionsDisabledAfterToOneYearInFuture() external onlyOwner {
        require(
            transferRestrictionsDisabledAfter == type(uint256).max,
            "L2BRR.setTransferRestrictionsDisabledAfterToOneYearInFuture: transfer restrictions are already disabled"
        );
        transferRestrictionsDisabledAfter = block.timestamp + 365 days;
        emit TransferRestrictionsDisabledOneYearInFuture();
    }

    /// VIEW FUNCTIONS

    /**
     * @dev Clock used for flagging checkpoints. Has been overridden to implement timestamp based
     * checkpoints (and voting).
     */
    function clock() public view override returns (uint48) {
        return SafeCast.toUint48(block.timestamp);
    }

    /**
     * @dev Machine-readable description of the clock as specified in EIP-6372.
     * Has been overridden to inform callers that this contract uses timestamps instead of block numbers, to match
     * `clock()`
     */
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    /// INTERNAL FUNCTIONS

    function _setAllowedFrom(address from, bool isAllowedFrom) internal {
        allowedFrom[from] = isAllowedFrom;
        emit SetAllowedFrom(from, isAllowedFrom);
    }

    function _setAllowedTo(address to, bool isAllowedTo) internal {
        allowedTo[to] = isAllowedTo;
        emit SetAllowedTo(to, isAllowedTo);
    }

    /**
     * @notice Overrides the update function to enforce transfer restrictions
     * @param from the address tokens are being transferred from
     * @param to the address tokens are being transferred to
     * @param value the amount of tokens being transferred
     */
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        // if transfer restrictions are enabled
        if (block.timestamp <= transferRestrictionsDisabledAfter) {
            // if both from and to are not whitelisted
            require(
                allowedFrom[from] || allowedTo[to] || from == address(0),
                "L2BRR._update: from or to must be whitelisted"
            );
        }
        super._update(from, to, value);
    }

    // The following functions are overrides required by Solidity.

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
