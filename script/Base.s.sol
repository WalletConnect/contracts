// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { WCT } from "src/WCT.sol";
import { L2WCT } from "src/L2WCT.sol";
import { Timelock } from "src/Timelock.sol";
import { Eip1967Logger } from "script/utils/Eip1967Logger.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

struct EthereumDeployments {
    WCT wct;
    Timelock timelock;
}

struct OptimismDeployments {
    L2WCT l2wct;
    Timelock adminTimelock;
    Timelock managerTimelock;
}

abstract contract BaseScript is Script, StdCheats {
    /// @dev Included to enable compilation of the script without a $MNEMONIC environment variable.
    string internal constant TEST_MNEMONIC = "test test test test test test test test test test test junk";

    /// @dev Needed for the deterministic deployments.
    bytes32 internal constant ZERO_SALT = bytes32(0);

    /// @dev The address of the transaction broadcaster.
    address internal broadcaster;

    /// @dev Used to derive the broadcaster's address if $ETH_FROM is not defined.
    string internal mnemonic;

    /// @dev Initializes the transaction broadcaster like this:
    ///
    /// - If $ETH_FROM is defined, use it.
    /// - Otherwise, derive the broadcaster address from $MNEMONIC.
    /// - If $MNEMONIC is not defined, default to a test mnemonic.
    ///
    /// The use case for $ETH_FROM is to specify the broadcaster key and its address via the command line.
    ///
    /// Note: Using a mnemonic will revert in non-testnet chains
    constructor() {
        // Validate the chain ID
        require(vm.envUint("CHAIN_ID") == block.chainid, "Chain ID mismatch");
        // Get the specified sender
        address specifiedSender = vm.envOr({ name: "ETH_FROM", defaultValue: address(0) });
        bool isMainnetOrOptimism =
            block.chainid == getChain("mainnet").chainId || block.chainid == getChain("optimism").chainId;

        // We exit early if the chain is mainnet or optimism and no sender is specified
        if (isMainnetOrOptimism && specifiedSender == address(0)) {
            revert("You must specify a sender for a production deployment");
        }

        // Select the broadcaster, either the specified sender or the first derived address from the mnemonic
        broadcaster = (specifiedSender != address(0)) ? specifiedSender : deriveBroadcasterFromMnemonic();
    }

    modifier broadcast() {
        vm.startBroadcast(broadcaster);
        _;
        vm.stopBroadcast();
    }

    function readEthereumDeployments(uint256 chainId) public returns (EthereumDeployments memory) {
        bytes memory data = _readDeployments(chainId);
        if (data.length == 0) {
            return EthereumDeployments({ wct: WCT(address(0)), timelock: Timelock(payable(address(0))) });
        }
        return abi.decode(data, (EthereumDeployments));
    }

    function readOptimismDeployments(uint256 chainId) public returns (OptimismDeployments memory) {
        bytes memory data = _readDeployments(chainId);
        if (data.length == 0) {
            return OptimismDeployments({
                l2wct: L2WCT(address(0)),
                adminTimelock: Timelock(payable(address(0))),
                managerTimelock: Timelock(payable(address(0)))
            });
        }
        return abi.decode(data, (OptimismDeployments));
    }

    function deriveBroadcasterFromMnemonic() private returns (address) {
        mnemonic = vm.envOr({ name: "MNEMONIC", defaultValue: TEST_MNEMONIC });
        (address derived,) = deriveRememberKey({ mnemonic: mnemonic, index: 0 });
        return derived;
    }

    function _deploymentsFile(uint256 chainId) internal view returns (string memory) {
        string memory root = vm.projectRoot();
        return string.concat(root, "/deployments/", vm.toString(chainId));
    }

    function _readDeployments(uint256 chainId) private returns (bytes memory) {
        console2.log("Reading deployments for chain %s", vm.toString(chainId));
        string memory deploymentsFile = _deploymentsFile(chainId);
        if (!vm.exists(deploymentsFile)) {
            return "";
        }
        return vm.readFileBinary(deploymentsFile);
    }

    function _writeDeployments(bytes memory encodedDeployments) internal {
        vm.writeFileBinary(_deploymentsFile(block.chainid), encodedDeployments);
    }

    function _singleAddressArray(address addr) internal pure returns (address[] memory) {
        address[] memory arr = new address[](1);
        arr[0] = addr;
        return arr;
    }

    function logEip1967(string memory name, address proxy) public view {
        console2.log("%s:", name, proxy);
        bytes32 ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        address admin = slotToAddress(proxy, ADMIN_SLOT);
        if (admin == address(0)) {
            return console2.log("No admin found. Are you sure %s is a proxy?", name);
        }
        console2.log("%s Admin:", name, admin);
        bytes32 IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        address implementation = slotToAddress(proxy, IMPLEMENTATION_SLOT);
        console2.log("%s Implementation:", name, implementation);
    }

    function slotToAddress(address proxy, bytes32 slot) public view returns (address) {
        return address(uint160(uint256(vm.load(proxy, slot))));
    }
}
