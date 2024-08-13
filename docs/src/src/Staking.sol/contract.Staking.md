# Staking
[Git Source](https://github.com/WalletConnect/contracts/blob/67de895b15d7488b46908a69f0cb045943c5c770/src/Staking.sol)

**Inherits:**
Initializable, OwnableUpgradeable


## State Variables
### isStakingAllowlist
The staking allowlist flag which, when enabled, allows staking only for addresses in allowlist.


```solidity
bool public isStakingAllowlist;
```


### minStakeAmount
The minimum staking amount for each node.


```solidity
uint256 public minStakeAmount;
```


### pendingRewards
The accrued rewards for each node.


```solidity
mapping(address staker => uint256 pendingRewards) public pendingRewards;
```


### stakes
Stake amount for each node.


```solidity
mapping(address staker => uint256 amount) public stakes;
```


### bakersSyndicateConfig

```solidity
BakersSyndicateConfig public bakersSyndicateConfig;
```


## Functions
### initialize

Initializes the contract.

*MUST be called during the contract upgrade to set up the proxies state.*


```solidity
function initialize(Init memory init) external initializer;
```

### stake

Interface for nodes to stake their BRR with the protocol. Note: when allowlist is enabled, only nodes
with the allowlist can stake.


```solidity
function stake(uint256 amount) external;
```

### unstake

Interface for users to unstake their BRR from the protocol.


```solidity
function unstake(uint256 amount) external;
```

### setStakingAllowlist

Sets the staking allowlist flag.


```solidity
function setStakingAllowlist(bool isStakingAllowlist_) external onlyOwner;
```

### updateMinStakeAmount

Updates the minimum staking amount.


```solidity
function updateMinStakeAmount(uint256 minStakeAmount_) external onlyOwner;
```

### updateRewards

Function for the reward manager to add rewards to a node's pending rewards balance.


```solidity
function updateRewards(address node, uint256 amount, uint256 reportingEpoch) external;
```

### claimRewards


```solidity
function claimRewards() external;
```

## Events
### Staked

```solidity
event Staked(address indexed node, uint256 amount);
```

### Unstaked

```solidity
event Unstaked(address indexed node, uint256 amount);
```

### RewardsClaimed

```solidity
event RewardsClaimed(address indexed node, uint256 rewardsClaimed);
```

### RewardsUpdated

```solidity
event RewardsUpdated(address indexed node, uint256 indexed reportingEpoch, uint256 newRewards);
```

### StakingAllowlistSet

```solidity
event StakingAllowlistSet(bool isStakingAllowlist);
```

### MinStakeAmountUpdated

```solidity
event MinStakeAmountUpdated(uint256 oldMinStakeAmount, uint256 newMinStakeAmount);
```

## Errors
### Paused

```solidity
error Paused();
```

### InsufficientStake

```solidity
error InsufficientStake(address staker, uint256 currentStake, uint256 amount);
```

### StakingBelowMinimum

```solidity
error StakingBelowMinimum(uint256 minStakeAmount, uint256 stakingAmount);
```

### UnstakingBelowMinimum

```solidity
error UnstakingBelowMinimum(uint256 minStakeAmount, uint256 currentStake, uint256 amount);
```

### NotWhitelisted

```solidity
error NotWhitelisted();
```

### UnchangedState

```solidity
error UnchangedState();
```

### InvalidInput

```solidity
error InvalidInput();
```

### NoRewards

```solidity
error NoRewards(address node);
```

## Structs
### Init
Configuration for contract initialization.


```solidity
struct Init {
    address owner;
    uint256 minStakeAmount;
    bool isStakingAllowlist;
    BakersSyndicateConfig bakersSyndicateConfig;
}
```

