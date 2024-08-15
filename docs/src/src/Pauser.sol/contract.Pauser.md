# Pauser

[Git Source](https://github.com/dwacfn/contracts/blob/67de895b15d7488b46908a69f0cb045943c5c770/src/Pauser.sol)

**Inherits:** Initializable, AccessControlUpgradeable

**Author:** BakerSyndicate

Contract for managing pause states of various system functions

## State Variables

### PAUSER_ROLE

Role for pausing functions

```solidity
bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
```

### UNPAUSER_ROLE

Role for unpausing functions

```solidity
bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");
```

### isStakingPaused

Flag indicating if staking is paused

```solidity
bool public isStakingPaused;
```

### isSubmitOracleRecordsPaused

Flag indicating if submit oracle records is paused

```solidity
bool public isSubmitOracleRecordsPaused;
```

## Functions

### initialize

Initializes the contract

_MUST be called during the contract upgrade to set up the proxies state_

```solidity
function initialize(Init memory init) external initializer;
```

**Parameters**

| Name   | Type   | Description               |
| ------ | ------ | ------------------------- |
| `init` | `Init` | Initialization parameters |

### setIsStakingPaused

Pauses or unpauses staking

```solidity
function setIsStakingPaused(bool isPaused) external;
```

**Parameters**

| Name       | Type   | Description         |
| ---------- | ------ | ------------------- |
| `isPaused` | `bool` | The new pause state |

### setIsSubmitOracleRecordsPaused

Pauses or unpauses submit oracle records

```solidity
function setIsSubmitOracleRecordsPaused(bool isPaused) external;
```

**Parameters**

| Name       | Type   | Description         |
| ---------- | ------ | ------------------- |
| `isPaused` | `bool` | The new pause state |

### pauseAll

Pauses all actions

```solidity
function pauseAll() external onlyRole(PAUSER_ROLE);
```

### unpauseAll

Unpauses all actions

```solidity
function unpauseAll() external onlyRole(UNPAUSER_ROLE);
```

### \_setIsStakingPaused

_Sets the staking pause state_

```solidity
function _setIsStakingPaused(bool isPaused) private;
```

**Parameters**

| Name       | Type   | Description         |
| ---------- | ------ | ------------------- |
| `isPaused` | `bool` | The new pause state |

### \_setIsSubmitOracleRecordsPaused

_Sets the submit oracle records pause state_

```solidity
function _setIsSubmitOracleRecordsPaused(bool isPaused) private;
```

**Parameters**

| Name       | Type   | Description         |
| ---------- | ------ | ------------------- |
| `isPaused` | `bool` | The new pause state |

## Events

### FlagUpdated

Emitted when a flag has been updated

```solidity
event FlagUpdated(bytes4 indexed selector, bool indexed isPaused, string flagName);
```

**Parameters**

| Name       | Type     | Description                               |
| ---------- | -------- | ----------------------------------------- |
| `selector` | `bytes4` | The selector of the flag that was updated |
| `isPaused` | `bool`   | The new value of the flag                 |
| `flagName` | `string` | The name of the flag that was updated     |

## Structs

### Init

Configuration for contract initialization

```solidity
struct Init {
    address admin;
}
```
