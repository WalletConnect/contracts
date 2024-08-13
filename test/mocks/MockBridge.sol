// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { BakersSyndicateConfig } from "src/BakersSyndicateConfig.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { L2BRR } from "src/L2BRR.sol";
import { ILegacyMintableERC20, IOptimismMintableERC20 } from "src/interfaces/IOptimismMintableERC20.sol";

contract MockBridge {
    BakersSyndicateConfig public config;

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

    constructor(BakersSyndicateConfig _config) {
        config = _config;
    }

    /// @dev Mock implementation of the bridgeERC20 function. When localToken is L2BRR, it mints the amount of tokens to
    /// the to address. When remoteToken is L2BRR, it burns the amount of tokens from the from address.
    function bridgeERC20(
        address localToken,
        address remoteToken,
        uint256 amount,
        uint32 minGasLimit,
        bytes calldata extraData
    )
        external
    {
        L2BRR l2brr = L2BRR(config.getL2brr());
        require(address(l2brr) != address(0), "L2BRR not set");
        if (_isOptimismMintableERC20(address(localToken))) {
            // Simulating L1 to L2 transfer
            try l2brr.mint(msg.sender, amount) {
                emit ERC20BridgeFinalized(
                    localToken, remoteToken, msg.sender, msg.sender, amount, abi.encodePacked(minGasLimit, extraData)
                );
            } catch Error(string memory reason) {
                revert(string(abi.encodePacked("Mint failed: ", reason)));
            }
        } else {
            require(l2brr.balanceOf(msg.sender) >= amount, "Insufficient balance for burn");
            // Bridging from L2 to L1
            l2brr.burn(msg.sender, amount);
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
