// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { WCT } from "src/WCT.sol";
import { LegacyL2WCT } from "src/legacy/LegacyL2WCT.sol";
import { L2WCT } from "src/L2WCT.sol";
import { WalletConnectConfig } from "src/WalletConnectConfig.sol";
import { Pauser } from "src/Pauser.sol";
import { RewardManager } from "src/RewardManager.sol";
import { Staking } from "src/Staking.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";

function newWCT(address initialOwner, WCT.Init memory init) returns (WCT) {
    bytes32 salt = keccak256(abi.encodePacked("walletconnect.wct"));

    WCT impl = new WCT{ salt: salt }();
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy{ salt: salt }({
        _logic: address(impl),
        initialOwner: address(initialOwner),
        _data: abi.encodeCall(WCT.initialize, init)
    });

    return WCT(address(proxy));
}

function newL2WCT(address initialOwner, LegacyL2WCT.Init memory init) returns (L2WCT) {
    bytes32 salt = keccak256(abi.encodePacked("walletconnect.l2wct"));

    LegacyL2WCT impl = new LegacyL2WCT{ salt: salt }();
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy{ salt: salt }({
        _logic: address(impl),
        initialOwner: address(initialOwner),
        _data: abi.encodeCall(LegacyL2WCT.initialize, init)
    });

    return L2WCT(address(proxy));
}

function newWalletConnectConfig(
    address initialOwner,
    WalletConnectConfig.Init memory init
)
    returns (WalletConnectConfig)
{
    bytes32 salt = keccak256(abi.encodePacked("walletconnect.config"));

    WalletConnectConfig impl = new WalletConnectConfig{ salt: salt }();
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy{ salt: salt }({
        _logic: address(impl),
        initialOwner: address(initialOwner),
        _data: abi.encodeCall(WalletConnectConfig.initialize, init)
    });

    return WalletConnectConfig(address(proxy));
}

function newPauser(address initialOwner, Pauser.Init memory init) returns (Pauser) {
    bytes32 salt = keccak256(abi.encodePacked("walletconnect.pauser"));

    Pauser impl = new Pauser{ salt: salt }();
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy{ salt: salt }({
        _logic: address(impl),
        initialOwner: address(initialOwner),
        _data: abi.encodeCall(Pauser.initialize, init)
    });

    return Pauser(address(proxy));
}

function newRewardManager(address initialOwner, RewardManager.Init memory init) returns (RewardManager) {
    bytes32 salt = keccak256(abi.encodePacked("walletconnect.rewardmanager"));

    RewardManager impl = new RewardManager{ salt: salt }();
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy{ salt: salt }({
        _logic: address(impl),
        initialOwner: address(initialOwner),
        _data: abi.encodeCall(RewardManager.initialize, init)
    });

    return RewardManager(address(proxy));
}

function newStaking(address initialOwner, Staking.Init memory init) returns (Staking) {
    bytes32 salt = keccak256(abi.encodePacked("walletconnect.staking"));

    Staking impl = new Staking{ salt: salt }();
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy{ salt: salt }({
        _logic: address(impl),
        initialOwner: address(initialOwner),
        _data: abi.encodeCall(Staking.initialize, init)
    });

    return Staking(address(proxy));
}

function newStakingRewardDistributor(
    address initialOwner,
    StakingRewardDistributor.Init memory init
)
    returns (StakingRewardDistributor)
{
    bytes32 salt = keccak256(abi.encodePacked("walletconnect.stakingrewarddistributor"));

    StakingRewardDistributor impl = new StakingRewardDistributor{ salt: salt }();
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy{ salt: salt }({
        _logic: address(impl),
        initialOwner: address(initialOwner),
        _data: abi.encodeCall(StakingRewardDistributor.initialize, init)
    });

    return StakingRewardDistributor(address(proxy));
}

function newStakeWeight(address initialOwner, StakeWeight.Init memory init) returns (StakeWeight) {
    bytes32 salt = keccak256(abi.encodePacked("walletconnect.stakeweight"));

    StakeWeight impl = new StakeWeight{ salt: salt }();
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy{ salt: salt }({
        _logic: address(impl),
        initialOwner: address(initialOwner),
        _data: abi.encodeCall(StakeWeight.initialize, init)
    });

    return StakeWeight(address(proxy));
}

function newMockERC20(address initialOwner) returns (MockERC20) {
    bytes32 salt = keccak256(abi.encodePacked("walletconnect.mockerc20"));

    MockERC20 impl = new MockERC20{ salt: salt }();
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy{ salt: salt }({
        _logic: address(impl),
        initialOwner: address(initialOwner),
        _data: abi.encodeCall(MockERC20.initialize, ())
    });

    return MockERC20(address(proxy));
}
