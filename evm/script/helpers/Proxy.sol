// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { WCT } from "src/WCT.sol";
import { LegacyL2WCT } from "src/legacy/LegacyL2WCT.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";
import { Pauser } from "src/Pauser.sol";
import { RewardManager } from "src/RewardManager.sol";
import { Staking } from "src/Staking.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";
import { LockedTokenStaker } from "src/LockedTokenStaker.sol";

// Events for deployment tracking
event ContractDeployed(string contractType, address implementation, address proxy, bytes32 salt);

// Errors
error ZeroAddress();
error EmptyIdentifier();
error DeploymentFailed();

/**
 * @dev Internal helper function to deploy proxy contracts
 * @param impl Implementation contract address
 * @param initialOwner Owner of the proxy admin
 * @param initData Initialization calldata
 * @param salt Salt for CREATE2 deployment
 * @return proxy The deployed proxy address
 */
function _deployProxy(
    address impl,
    address initialOwner,
    bytes memory initData,
    bytes32 salt
)
    returns (address proxy)
{
    if (impl == address(0) || initialOwner == address(0)) revert ZeroAddress();
    
    // Use different salt for proxy to avoid collision
    bytes32 proxySalt = keccak256(abi.encodePacked(salt, "proxy"));
    
    TransparentUpgradeableProxy deployedProxy = new TransparentUpgradeableProxy{ salt: proxySalt }({
        _logic: impl,
        initialOwner: initialOwner,
        _data: initData
    });
    
    proxy = address(deployedProxy);
    if (proxy == address(0)) revert DeploymentFailed();
}

function newWCT(address initialOwner, WCT.Init memory init) returns (WCT) {
    if (initialOwner == address(0)) revert ZeroAddress();
    
    bytes32 salt = keccak256(abi.encodePacked("walletconnect.wct"));
    
    WCT impl = new WCT{ salt: salt }();
    address proxy = _deployProxy(
        address(impl),
        initialOwner,
        abi.encodeCall(WCT.initialize, init),
        salt
    );
    
    emit ContractDeployed("WCT", address(impl), proxy, salt);
    return WCT(proxy);
}

function newL2WCT(address initialOwner, LegacyL2WCT.Init memory init) returns (LegacyL2WCT) {
    if (initialOwner == address(0)) revert ZeroAddress();
    
    bytes32 salt = keccak256(abi.encodePacked("walletconnect.l2wct"));
    
    LegacyL2WCT impl = new LegacyL2WCT{ salt: salt }();
    address proxy = _deployProxy(
        address(impl),
        initialOwner,
        abi.encodeCall(LegacyL2WCT.initialize, init),
        salt
    );
    
    emit ContractDeployed("LegacyL2WCT", address(impl), proxy, salt);
    return LegacyL2WCT(proxy);
}

function newWalletConnectConfig(
    address initialOwner,
    WalletConnectConfig.Init memory init
)
    returns (WalletConnectConfig)
{
    if (initialOwner == address(0)) revert ZeroAddress();
    
    bytes32 salt = keccak256(abi.encodePacked("walletconnect.config"));
    
    WalletConnectConfig impl = new WalletConnectConfig{ salt: salt }();
    address proxy = _deployProxy(
        address(impl),
        initialOwner,
        abi.encodeCall(WalletConnectConfig.initialize, init),
        salt
    );
    
    emit ContractDeployed("WalletConnectConfig", address(impl), proxy, salt);
    return WalletConnectConfig(proxy);
}

function newPauser(address initialOwner, Pauser.Init memory init) returns (Pauser) {
    if (initialOwner == address(0)) revert ZeroAddress();
    
    bytes32 salt = keccak256(abi.encodePacked("walletconnect.pauser"));
    
    Pauser impl = new Pauser{ salt: salt }();
    address proxy = _deployProxy(
        address(impl),
        initialOwner,
        abi.encodeCall(Pauser.initialize, init),
        salt
    );
    
    emit ContractDeployed("Pauser", address(impl), proxy, salt);
    return Pauser(proxy);
}

function newRewardManager(address initialOwner, RewardManager.Init memory init) returns (RewardManager) {
    if (initialOwner == address(0)) revert ZeroAddress();
    
    bytes32 salt = keccak256(abi.encodePacked("walletconnect.rewardmanager"));
    
    RewardManager impl = new RewardManager{ salt: salt }();
    address proxy = _deployProxy(
        address(impl),
        initialOwner,
        abi.encodeCall(RewardManager.initialize, init),
        salt
    );
    
    emit ContractDeployed("RewardManager", address(impl), proxy, salt);
    return RewardManager(proxy);
}

function newStaking(address initialOwner, Staking.Init memory init) returns (Staking) {
    if (initialOwner == address(0)) revert ZeroAddress();
    
    bytes32 salt = keccak256(abi.encodePacked("walletconnect.staking"));
    
    Staking impl = new Staking{ salt: salt }();
    address proxy = _deployProxy(
        address(impl),
        initialOwner,
        abi.encodeCall(Staking.initialize, init),
        salt
    );
    
    emit ContractDeployed("Staking", address(impl), proxy, salt);
    return Staking(proxy);
}

function newStakingRewardDistributor(
    address initialOwner,
    StakingRewardDistributor.Init memory init
)
    returns (StakingRewardDistributor)
{
    if (initialOwner == address(0)) revert ZeroAddress();
    
    bytes32 salt = keccak256(abi.encodePacked("walletconnect.stakingrewarddistributor"));
    
    StakingRewardDistributor impl = new StakingRewardDistributor{ salt: salt }();
    address proxy = _deployProxy(
        address(impl),
        initialOwner,
        abi.encodeCall(StakingRewardDistributor.initialize, init),
        salt
    );
    
    emit ContractDeployed("StakingRewardDistributor", address(impl), proxy, salt);
    return StakingRewardDistributor(proxy);
}

function newStakeWeight(address initialOwner, StakeWeight.Init memory init) returns (StakeWeight) {
    if (initialOwner == address(0)) revert ZeroAddress();
    
    bytes32 salt = keccak256(abi.encodePacked("walletconnect.stakeweight"));
    
    StakeWeight impl = new StakeWeight{ salt: salt }();
    address proxy = _deployProxy(
        address(impl),
        initialOwner,
        abi.encodeCall(StakeWeight.initialize, init),
        salt
    );
    
    emit ContractDeployed("StakeWeight", address(impl), proxy, salt);
    return StakeWeight(proxy);
}

function newLockedTokenStaker(
    address initialOwner,
    LockedTokenStaker.Init memory init,
    string memory identifier
)
    returns (LockedTokenStaker)
{
    if (initialOwner == address(0)) revert ZeroAddress();
    if (bytes(identifier).length == 0) revert EmptyIdentifier();
    
    // Validate identifier contains only alphanumeric and allowed special chars
    bytes memory identifierBytes = bytes(identifier);
    for (uint256 i = 0; i < identifierBytes.length; i++) {
        bytes1 char = identifierBytes[i];
        bool isValid = (char >= 0x30 && char <= 0x39) || // 0-9
            (char >= 0x41 && char <= 0x5A) || // A-Z
            (char >= 0x61 && char <= 0x7A) || // a-z
            char == 0x2D || char == 0x5F; // - or _
        require(isValid, "Invalid identifier character");
    }
    
    bytes32 salt = keccak256(abi.encodePacked("walletconnect.lockedtokenstaker.", identifier));
    
    LockedTokenStaker impl = new LockedTokenStaker{ salt: salt }();
    address proxy = _deployProxy(
        address(impl),
        initialOwner,
        abi.encodeCall(LockedTokenStaker.initialize, init),
        salt
    );
    
    emit ContractDeployed(
        string(abi.encodePacked("LockedTokenStaker-", identifier)),
        address(impl),
        proxy,
        salt
    );
    return LockedTokenStaker(proxy);
}

function newMockERC20(address initialOwner) returns (MockERC20) {
    if (initialOwner == address(0)) revert ZeroAddress();
    
    bytes32 salt = keccak256(abi.encodePacked("walletconnect.mockerc20"));
    
    MockERC20 impl = new MockERC20{ salt: salt }();
    address proxy = _deployProxy(
        address(impl),
        initialOwner,
        abi.encodeCall(MockERC20.initialize, ()),
        salt
    );
    
    emit ContractDeployed("MockERC20", address(impl), proxy, salt);
    return MockERC20(proxy);
}

/**
 * @dev Helper function to predict deployment addresses before actual deployment
 * @param deployer Address that will deploy the contract
 * @param saltString Salt string used in deployment
 * @return implAddress Predicted implementation address
 * @return proxyAddress Predicted proxy address
 */
function predictAddresses(
    address deployer,
    string memory saltString
)
    pure
    returns (address implAddress, address proxyAddress)
{
    bytes32 salt = keccak256(abi.encodePacked(saltString));
    bytes32 proxySalt = keccak256(abi.encodePacked(salt, "proxy"));
    
    // Note: This is simplified - actual prediction requires bytecode hash
    // In practice, you'd use a library like CREATE2 address predictor
    return (address(0), address(0)); // Placeholder
}
