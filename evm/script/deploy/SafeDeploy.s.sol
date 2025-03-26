// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { BaseScript } from "script/Base.s.sol";
import { SafeProxyFactory } from "safe-smart-account/contracts/proxies/SafeProxyFactory.sol";

struct SafeSetup {
    address[] owners;
    uint256 threshold;
    address to;
    bytes data;
    address fallbackHandler;
    address paymentToken;
    uint256 payment;
    address payable paymentReceiver;
    uint256 saltNonce;
}

struct LegacyDeploymentParams {
    address admin;
    address manager;
    address bridge;
    address superchainBridge;
    address remoteToken;
    bytes32 salt;
}

contract SafeDeploy is BaseScript {
    // Gnosis Safe core contract addresses that are the same across all chains (L2 variant - v1.3.0)
    address constant SAFE_SINGLETON = 0xfb1bffC9d739B8D520DaF37dF666da4C687191EA;
    address constant SAFE_FACTORY = 0xC22834581EbC8527d974F8a1c97E1bEA4EF910BC;
    address constant SAFE_FALLBACK_HANDLER = 0x017062a1dE2FE6b99BE3d9d37841FeD19F573804;
    address constant SAFE_PAYMENT_RECEIVER = 0x5afe7A11E7000000000000000000000000000000;

    // Enum for Safe role
    enum SafeRole {
        Admin,
        Manager
    }

    function run() public broadcast {
        // Get the role from command line argument
        SafeRole role = SafeRole(vm.envUint("SAFE_ROLE"));
        string memory roleName = role == SafeRole.Admin ? "admin" : "manager";

        console2.log("Deploying %s Safe wallet on %s", roleName, getChain(block.chainid).name);

        // Deploy Safe wallet using existing core contracts
        address safe = deploySafeInstance(getSafeSetup());
        console2.log("%s Safe deployed at:", roleName, safe);
    }

    function deploySafeInstance(SafeSetup memory setup) public returns (address safe) {
        bytes memory init = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            setup.owners,
            setup.threshold,
            setup.to,
            setup.data,
            setup.fallbackHandler,
            setup.paymentToken,
            setup.payment,
            setup.paymentReceiver
        );
        console2.logBytes(init);
        safe = address(SafeProxyFactory(SAFE_FACTORY).createProxyWithNonce(SAFE_SINGLETON, init, setup.saltNonce));
    }

    function getSafeSetup() public view returns (SafeSetup memory setup) {
        address[] memory owners = new address[](1);
        owners[0] = vm.envAddress("SAFE_OWNER_ADDRESS");

        setup = SafeSetup({
            owners: owners,
            threshold: 1,
            to: address(0),
            data: "",
            fallbackHandler: SAFE_FALLBACK_HANDLER,
            paymentToken: address(0),
            payment: 0,
            paymentReceiver: payable(SAFE_PAYMENT_RECEIVER),
            saltNonce: uint256(0)
        });
    }
}
