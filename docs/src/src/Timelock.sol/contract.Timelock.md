# Timelock

[Git Source](https://github.com/dwacfn/contracts/blob/67de895b15d7488b46908a69f0cb045943c5c770/src/Timelock.sol)

**Inherits:** TimelockController

**Author:** BakersSyndicate

A timelock contract with an immutable min delay

## Functions

### constructor

Initializes the Timelock contract

_Sets up the timelock with a specified delay and initial roles_

```solidity
constructor(
    uint256 delay,
    address[] memory proposers,
    address[] memory executors,
    address canceller
)
    TimelockController(delay, proposers, executors, address(0));
```

**Parameters**

| Name        | Type        | Description                                             |
| ----------- | ----------- | ------------------------------------------------------- |
| `delay`     | `uint256`   | The timelock delay in seconds (must be at least 3 days) |
| `proposers` | `address[]` | Array of addresses that can propose new operations      |
| `executors` | `address[]` | Array of addresses that can execute operations          |
| `canceller` | `address`   | Address of the canceller role                           |

## Errors

### InvalidDelay

Thrown when an invalid delay is provided in the constructor

```solidity
error InvalidDelay();
```

### InvalidCanceller

Thrown when an invalid canceller is provided in the constructor

```solidity
error InvalidCanceller();
```

### InvalidProposer

Thrown when an invalid proposer is provided in the constructor

```solidity
error InvalidProposer();
```

### InvalidExecutor

Thrown when an invalid executor is provided in the constructor

```solidity
error InvalidExecutor();
```
