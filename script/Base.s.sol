// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Script } from "forge-std/src/Script.sol";
import { CNCT } from "src/CNCT.sol";
import { Pauser } from "src/Pauser.sol";
import { PermissionedNodeRegistry } from "src/PermissionedNodeRegistry.sol";
import { RewardManager } from "src/RewardManager.sol";
import { Staking } from "src/Staking.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";

struct Deployments {
    CNCT cnct;
    Pauser pauser;
    PermissionedNodeRegistry registry;
    RewardManager rewardManager;
    Staking staking;
    WalletConnectConfig config;
}

abstract contract BaseScript is Script {
    /// @dev Included to enable compilation of the script without a $MNEMONIC environment variable.
    string internal constant TEST_MNEMONIC = "test test test test test test test test test test test junk";

    /// @dev Needed for the deterministic deployments.
    bytes32 internal constant ZERO_SALT = bytes32(0);

    /// @dev The address of the transaction broadcaster.
    address internal broadcaster;

    /// @dev Used to derive the broadcaster's address if $ETH_FROM is not defined.
    string internal mnemonic;

    /// @dev Used to prevent using reserved protocol addresses for other purposes.
    uint32 lastReservedMnemonicIndex = 1;

    /// @dev Initializes the transaction broadcaster like this:
    ///
    /// - If $ETH_FROM is defined, use it.
    /// - Otherwise, derive the broadcaster address from $MNEMONIC.
    /// - If $MNEMONIC is not defined, default to a test mnemonic.
    ///
    /// The use case for $ETH_FROM is to specify the broadcaster key and its address via the command line.
    constructor() {
        require(vm.envUint("CHAIN_ID") == block.chainid, "wrong chain id");
        address from = vm.envOr({ name: "ETH_FROM", defaultValue: address(0) });
        if (from != address(0)) {
            broadcaster = from;
        } else {
            mnemonic = vm.envOr({ name: "MNEMONIC", defaultValue: TEST_MNEMONIC });
            (broadcaster,) = deriveRememberKey({ mnemonic: mnemonic, index: 0 });
        }
    }

    modifier broadcast() {
        vm.startBroadcast(broadcaster);
        _;
        vm.stopBroadcast();
    }

    function _deploymentsFile() internal view returns (string memory) {
        string memory root = vm.projectRoot();
        return string.concat(root, "/deployments/", vm.toString(block.chainid));
    }

    function writeDeployments(Deployments memory deps) public {
        vm.writeFileBinary(_deploymentsFile(), abi.encode(deps));
    }

    function safeReadDeployments() public returns (Deployments memory) {
        Deployments memory depls = _readDeployments();
        require(address(depls.cnct).code.length > 0, "contracts are not deployed yet");
        return depls;
    }

    function readDeployments() public returns (Deployments memory) {
        return _readDeployments();
    }

    function _readDeployments() private returns (Deployments memory) {
        if (vm.exists(_deploymentsFile()) == false) {
            return Deployments({
                cnct: CNCT(address(0)),
                pauser: Pauser(address(0)),
                registry: PermissionedNodeRegistry(address(0)),
                rewardManager: RewardManager(address(0)),
                staking: Staking(address(0)),
                config: WalletConnectConfig(address(0))
            });
        }
        bytes memory data = vm.readFileBinary(_deploymentsFile());
        Deployments memory depls = abi.decode(data, (Deployments));
        return depls;
    }
}
