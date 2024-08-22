// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ILegacyMintableERC20, IOptimismMintableERC20 } from "src/interfaces/IOptimismMintableERC20.sol";

interface IERC20Burnable is IERC20 {
    function burn(address account, uint256 amount) external;
}

contract MockBridge {
    event ERC20BridgeInitiated(
        address indexed localToken,
        address indexed remoteToken,
        address indexed from,
        address to,
        uint256 amount,
        bytes extraData
    );

    event ERC20BridgeFinalized(
        address indexed localToken,
        address indexed remoteToken,
        address indexed from,
        address to,
        uint256 amount,
        bytes extraData
    );

    /// @dev Mock implementation of the bridgeERC20 function. When localToken is L2CNKT, it mints the amount of tokens
    /// to
    /// the to address. When remoteToken is L2CNKT, it burns the amount of tokens from the from address.
    function bridgeERC20(
        address localToken,
        address remoteToken,
        uint256 amount,
        uint32 minGasLimit,
        bytes calldata extraData
    )
        external
    {
        if (_isOptimismMintableERC20(address(localToken))) {
            // Simulating L1 to L2 transfer
            try IOptimismMintableERC20(localToken).mint(msg.sender, amount) {
                emit ERC20BridgeFinalized(
                    localToken, remoteToken, msg.sender, msg.sender, amount, abi.encodePacked(minGasLimit, extraData)
                );
            } catch Error(string memory reason) {
                revert(string(abi.encodePacked("Mint failed: ", reason)));
            }
        } else {
            IERC20Burnable token = IERC20Burnable(remoteToken);
            require(token.balanceOf(msg.sender) >= amount, "Insufficient balance for burn");
            // Bridging from L2 to L1
            token.burn(msg.sender, amount);
            emit ERC20BridgeInitiated(
                localToken, remoteToken, msg.sender, msg.sender, amount, abi.encodePacked(minGasLimit, extraData)
            );
        }
    }

    /// @notice Checks if a given address is an OptimismMintableERC20. Not perfect, but good enough.
    ///         Just the way we like it.
    /// @param _token Address of the token to check.
    /// @return True if the token is an OptimismMintableERC20.
    function _isOptimismMintableERC20(address _token) internal view returns (bool) {
        return ERC165Checker.supportsInterface(_token, type(ILegacyMintableERC20).interfaceId)
            || ERC165Checker.supportsInterface(_token, type(IOptimismMintableERC20).interfaceId);
    }
}
