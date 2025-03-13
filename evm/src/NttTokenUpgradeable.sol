// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { INttToken } from "src/interfaces/INttToken.sol";
import { ERC20BurnableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

/**
 * @title NttTokenUpgradeable
 * @notice Abstract base contract implementing the INttToken interface with dedicated storage slots
 * @dev This contract should be inherited by token contracts that need to implement INttToken
 */
abstract contract NttTokenUpgradeable is ERC20BurnableUpgradeable, INttToken, IERC165 {
    // =============== Storage ==============================================================

    struct MinterStorage {
        address _minter;
    }

    bytes32 private constant MINTER_SLOT = bytes32(uint256(keccak256("walletconnect.minter")) - 1);

    // =============== Storage Getters/Setters ==============================================

    function _getMinterStorage() internal pure returns (MinterStorage storage $) {
        uint256 slot = uint256(MINTER_SLOT);
        assembly ("memory-safe") {
            $.slot := slot
        }
    }

    /**
     * @notice Initialize the minter role
     * @param initialMinter The initial minter address
     */
    function __NttToken_init(
        address initialMinter,
        string memory name,
        string memory symbol
    )
        internal
        onlyInitializing
    {
        __ERC20_init(name, symbol);
        __ERC20Burnable_init();

        if (initialMinter != address(0)) {
            _getMinterStorage()._minter = initialMinter;
            emit NewMinter(address(0), initialMinter);
        }
    }

    /**
     * @notice ERC165 interface check function
     * @param interfaceId Interface ID to check
     * @return Whether or not the interface is supported by this contract
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(INttToken).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    /**
     * @dev Returns the address of the current minter.
     */
    function minter() public view returns (address) {
        MinterStorage storage $ = _getMinterStorage();
        return $._minter;
    }

    /**
     * @dev Throws if called by any account other than the minter.
     */
    modifier onlyMinter() {
        if (minter() != _msgSender()) {
            revert CallerNotMinter(_msgSender());
        }
        _;
    }

    /**
     * @notice Sets a new minter address
     * @param newMinter The address to set as the new minter
     */
    function setMinter(address newMinter) external virtual override onlyMinter {
        _setMinter(newMinter);
    }

    /**
     * @dev Internal function to set the minter.
     * @param newMinter The address to set as the minter.
     */
    function _setMinter(address newMinter) internal {
        if (newMinter == address(0)) {
            revert InvalidMinterZeroAddress();
        }
        address previousMinter = minter();
        _getMinterStorage()._minter = newMinter;
        emit NewMinter(previousMinter, newMinter);
    }

    /**
     * @notice A function that mints new tokens to a specific account.
     * @param _account The address where new tokens will be minted.
     * @param _amount The amount of new tokens that will be minted.
     */
    function mint(address _account, uint256 _amount) external override onlyMinter {
        _mint(_account, _amount);
    }

    /**
     * @notice Burns a specific amount of tokens.
     * @dev Overrides both ERC20BurnableUpgradeable and INttToken implementations
     * @param amount The amount of tokens to burn.
     */
    function burn(uint256 amount) public virtual override(ERC20BurnableUpgradeable, INttToken) onlyMinter {
        super.burn(amount);
    }
}
