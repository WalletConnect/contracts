# RewardManager
[Git Source](https://github.com/WalletConnect/contracts/blob/67de895b15d7488b46908a69f0cb045943c5c770/src/RewardManager.sol)

**Inherits:**
Initializable, OwnableUpgradeable


## State Variables
### bakersSyndicateConfig

```solidity
BakersSyndicateConfig public bakersSyndicateConfig;
```


### maxRewardsPerEpoch

```solidity
uint256 public maxRewardsPerEpoch;
```


### lastUpdatedEpoch

```solidity
uint256 public lastUpdatedEpoch;
```


### performance

```solidity
mapping(address => uint256) public performance;
```


## Functions
### initialize

Initializes the contract.

*MUST be called during the contract upgrade to set up the proxies state.*


```solidity
function initialize(Init memory init) external initializer;
```

### postPerformanceRecords


```solidity
function postPerformanceRecords(PerformanceData calldata data) external onlyOwner;
```

## Events
### PerformanceUpdated

```solidity
event PerformanceUpdated(uint256 reportingEpoch, uint256 rewardsPerEpoch);
```

## Errors
### PerformanceDataAlreadyUpdated

```solidity
error PerformanceDataAlreadyUpdated();
```

### MismatchedDataLengths

```solidity
error MismatchedDataLengths();
```

### TotalPerformanceZero

```solidity
error TotalPerformanceZero();
```

## Structs
### PerformanceData

```solidity
struct PerformanceData {
    address[] nodes;
    uint256[] performance;
    uint256 reportingEpoch;
}
```

### Init
Configuration for contract initialization.


```solidity
struct Init {
    address owner;
    uint256 maxRewardsPerEpoch;
    BakersSyndicateConfig bakersSyndicateConfig;
}
```

