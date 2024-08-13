# UtilLib
[Git Source](https://github.com/WalletConnect/contracts/blob/67de895b15d7488b46908a69f0cb045943c5c770/src/library/UtilLib.sol)


## Functions
### checkNonZeroAddress

zero address check modifier


```solidity
function checkNonZeroAddress(address addr) internal pure;
```

### onlyBakersSyndicateContract


```solidity
function onlyBakersSyndicateContract(
    address addr,
    BakersSyndicateConfig bakersSyndicateConfig,
    bytes32 contractName
)
    internal
    view;
```

## Errors
### ZeroAddress

```solidity
error ZeroAddress();
```

### CallerNotBakersSyndicateContract

```solidity
error CallerNotBakersSyndicateContract();
```

