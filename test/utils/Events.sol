// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25;

/// @notice Abstract contract containing all the events emitted.
abstract contract Events {
    /*//////////////////////////////////////////////////////////////////////////
                                      ERC-20
    //////////////////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Mint(address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);

    /*//////////////////////////////////////////////////////////////////////////
                            WALLETCONNECT-REWARD-MANAGER
    //////////////////////////////////////////////////////////////////////////*/
    event PerformanceUpdated(uint256 reportingEpoch, uint256 rewardsPerEpoch);
    event RewardsClaimed(address indexed node, uint256 reward);

    /*//////////////////////////////////////////////////////////////////////////
                        WALLETCONNECT-PERMISSIONED-NODE-REGISTRY
    //////////////////////////////////////////////////////////////////////////*/
    event NodeWhitelisted(address indexed node);
    event NodeRemovedFromWhitelist(address indexed node);
    event MaxNodesSet(uint8 maxNodes);

    /*//////////////////////////////////////////////////////////////////////////
                                WALLETCONNECT-STAKING
    //////////////////////////////////////////////////////////////////////////*/
    event Staked(address indexed node, uint256 amount);
    event Unstaked(address indexed node, uint256 amount);
    event RewardsUpdated(address indexed node, uint256 indexed reportingEpoch, uint256 newRewards);
    event StakingAllowlistSet(bool isStakingAllowlist);
    event MinStakeAmountUpdated(uint256 oldMinStakeAmount, uint256 newMinStakeAmount);

    /*//////////////////////////////////////////////////////////////////////////
                                WALLETCONNECT-MINT-MANAGER
    //////////////////////////////////////////////////////////////////////////*/
    event TokensMinted(address indexed account, uint256 amount);

    /*//////////////////////////////////////////////////////////////////////////
                                L2WCT
    //////////////////////////////////////////////////////////////////////////*/
    event SetAllowedFrom(address indexed account, bool allowed);
    event SetAllowedTo(address indexed account, bool allowed);
    event TransferRestrictionsDisabled();

    /*//////////////////////////////////////////////////////////////////////////
                                WALLETCONNECT-TIMELOCK
    //////////////////////////////////////////////////////////////////////////*/
    event MinDelayChange(uint256 oldMinDelay, uint256 newMinDelay);

    /*//////////////////////////////////////////////////////////////////////////
                                AIRDROP
    //////////////////////////////////////////////////////////////////////////*/
    event TokensClaimed(address indexed recipient, uint256 amount);

    /*//////////////////////////////////////////////////////////////////////////
                                STAKE-WEIGHT
    //////////////////////////////////////////////////////////////////////////*/
    event Deposit(
        address indexed provider,
        uint256 value,
        uint256 locktime,
        uint256 type_,
        uint256 transferredValue,
        uint256 timestamp
    );
    event Withdraw(address indexed provider, uint256 value, uint256 transferredValue, uint256 timestamp);
    event ForcedWithdraw(
        address indexed provider, uint256 value, uint256 transferredValue, uint256 timestamp, uint256 end
    );
    event Supply(uint256 previousSupply, uint256 newSupply);
    event MaxLockUpdated(uint256 previousMaxLock, uint256 newMaxLock);
    /*//////////////////////////////////////////////////////////////////////////
                                STAKING-REWARD-DISTRIBUTOR
    //////////////////////////////////////////////////////////////////////////*/
    event RecipientUpdated(address indexed _user, address indexed _oldRecipient, address indexed _newRecipient);
    event RewardsClaimed(
        address indexed _user, address indexed _recipient, uint256 _amount, uint256 _claimEpoch, uint256 _maxEpoch
    );
    event TokenCheckpointed(uint256 _timestamp, uint256 _tokens);
    event Fed(uint256 _amount);
    /*//////////////////////////////////////////////////////////////////////////
                                MOCK-BRIDGE
    //////////////////////////////////////////////////////////////////////////*/
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

    /*//////////////////////////////////////////////////////////////////////////
                                      GENERICS
    //////////////////////////////////////////////////////////////////////////*/

    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    event TransferAdmin(address indexed oldAdmin, address indexed newAdmin);
}
