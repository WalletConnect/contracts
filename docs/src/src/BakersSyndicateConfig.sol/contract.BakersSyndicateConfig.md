# BakersSyndicateConfig

[Git Source](https://github.com/dwacfn/contracts/blob/67de895b15d7488b46908a69f0cb045943c5c770/src/BakersSyndicateConfig.sol)

**Inherits:** Initializable, AccessControlUpgradeable

**Author:** BakersSyndicate

Configuration contract for the BakersSyndicate system

## State Variables

### ADMIN_ROLE

Role for administrative actions

```solidity
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
```

### \_accountsMap

```solidity
mapping(bytes32 => address) private _accountsMap;
```

### \_contractsMap

```solidity
mapping(bytes32 => address) private _contractsMap;
```

### BAKERSSYNDICATE_REWARDS_VAULT

```solidity
bytes32 public constant BAKERSSYNDICATE_REWARDS_VAULT = keccak256("BAKERSSYNDICATE_REWARDS_VAULT");
```

### BRR_TOKEN

```solidity
bytes32 public constant BRR_TOKEN = keccak256("BRR_TOKEN");
```

### L2BRR_TOKEN

```solidity
bytes32 public constant L2BRR_TOKEN = keccak256("L2BRR_TOKEN");
```

### PERMISSIONED_NODE_REGISTRY

```solidity
bytes32 public constant PERMISSIONED_NODE_REGISTRY = keccak256("PERMISSIONED_NODE_REGISTRY");
```

### REWARD_MANAGER

```solidity
bytes32 public constant REWARD_MANAGER = keccak256("REWARD_MANAGER");
```

### STAKING

```solidity
bytes32 public constant STAKING = keccak256("STAKING");
```

### PAUSER

```solidity
bytes32 public constant PAUSER = keccak256("PAUSER");
```

## Functions

### initialize

Initializes the contract

_MUST be called during the contract upgrade to set up the proxies state_

```solidity
function initialize(Init memory init) public initializer;
```

**Parameters**

| Name   | Type   | Description               |
| ------ | ------ | ------------------------- |
| `init` | `Init` | Initialization parameters |

### getBrr

Gets the BRR token address

```solidity
function getBrr() external view returns (address);
```

**Returns**

| Name     | Type      | Description                           |
| -------- | --------- | ------------------------------------- |
| `<none>` | `address` | The address of the BRR token contract |

### getL2brr

Gets the L2BRR token address

```solidity
function getL2brr() external view returns (address);
```

**Returns**

| Name     | Type      | Description                             |
| -------- | --------- | --------------------------------------- |
| `<none>` | `address` | The address of the L2BRR token contract |

### getPauser

Gets the Pauser address

```solidity
function getPauser() external view returns (address);
```

**Returns**

| Name     | Type      | Description                        |
| -------- | --------- | ---------------------------------- |
| `<none>` | `address` | The address of the Pauser contract |

### getPermissionedNodeRegistry

Gets the Permissioned Node Registry address

```solidity
function getPermissionedNodeRegistry() external view returns (address);
```

**Returns**

| Name     | Type      | Description                                            |
| -------- | --------- | ------------------------------------------------------ |
| `<none>` | `address` | The address of the Permissioned Node Registry contract |

### getRewardManager

Gets the Reward Manager address

```solidity
function getRewardManager() external view returns (address);
```

**Returns**

| Name     | Type      | Description                                |
| -------- | --------- | ------------------------------------------ |
| `<none>` | `address` | The address of the Reward Manager contract |

### getStaking

Gets the Staking address

```solidity
function getStaking() external view returns (address);
```

**Returns**

| Name     | Type      | Description                         |
| -------- | --------- | ----------------------------------- |
| `<none>` | `address` | The address of the Staking contract |

### getBakersSyndicateRewardsVault

Gets the BakersSyndicate Rewards Vault address

```solidity
function getBakersSyndicateRewardsVault() external view returns (address);
```

**Returns**

| Name     | Type      | Description                                      |
| -------- | --------- | ------------------------------------------------ |
| `<none>` | `address` | The address of the BakersSyndicate Rewards Vault |

### updateBrr

Updates the BRR token address

```solidity
function updateBrr(address brr) external onlyRole(ADMIN_ROLE);
```

**Parameters**

| Name  | Type      | Description               |
| ----- | --------- | ------------------------- |
| `brr` | `address` | The new BRR token address |

### updateL2brr

Updates the L2BRR token address

```solidity
function updateL2brr(address l2brr) external onlyRole(ADMIN_ROLE);
```

**Parameters**

| Name    | Type      | Description                 |
| ------- | --------- | --------------------------- |
| `l2brr` | `address` | The new L2BRR token address |

### updatePauser

Updates the Pauser address

```solidity
function updatePauser(address pauser) external onlyRole(ADMIN_ROLE);
```

**Parameters**

| Name     | Type      | Description            |
| -------- | --------- | ---------------------- |
| `pauser` | `address` | The new Pauser address |

### updatePermissionedNodeRegistry

Updates the Permissioned Node Registry address

```solidity
function updatePermissionedNodeRegistry(address permissionedNodeRegistry) external onlyRole(ADMIN_ROLE);
```

**Parameters**

| Name                       | Type      | Description                                |
| -------------------------- | --------- | ------------------------------------------ |
| `permissionedNodeRegistry` | `address` | The new Permissioned Node Registry address |

### updateRewardManager

Updates the Reward Manager address

```solidity
function updateRewardManager(address rewardManager) external onlyRole(ADMIN_ROLE);
```

**Parameters**

| Name            | Type      | Description                    |
| --------------- | --------- | ------------------------------ |
| `rewardManager` | `address` | The new Reward Manager address |

### updateStaking

Updates the Staking address

```solidity
function updateStaking(address staking) external onlyRole(ADMIN_ROLE);
```

**Parameters**

| Name      | Type      | Description             |
| --------- | --------- | ----------------------- |
| `staking` | `address` | The new Staking address |

### updateBakersSyndicateRewardsVault

Updates the BakersSyndicate Rewards Vault address

```solidity
function updateBakersSyndicateRewardsVault(address bakersSyndicateRewardsVault) external onlyRole(ADMIN_ROLE);
```

**Parameters**

| Name                          | Type      | Description                                   |
| ----------------------------- | --------- | --------------------------------------------- |
| `bakersSyndicateRewardsVault` | `address` | The new BakersSyndicate Rewards Vault address |

### isBakersSyndicateContract

Checks if the given address is a recognized BakersSyndicate contract

```solidity
function isBakersSyndicateContract(address addr, bytes32 contractName) external view returns (bool);
```

**Parameters**

| Name           | Type      | Description                               |
| -------------- | --------- | ----------------------------------------- |
| `addr`         | `address` | The address to check                      |
| `contractName` | `bytes32` | The name of the contract to check against |

**Returns**

| Name     | Type   | Description                                                              |
| -------- | ------ | ------------------------------------------------------------------------ |
| `<none>` | `bool` | True if the address matches the stored contract address, false otherwise |

### \_setContract

_Sets a contract address_

```solidity
function _setContract(bytes32 key, address val) private;
```

**Parameters**

| Name  | Type      | Description                      |
| ----- | --------- | -------------------------------- |
| `key` | `bytes32` | The key identifying the contract |
| `val` | `address` | The new contract address         |

### \_setAccount

_Sets an account address_

```solidity
function _setAccount(bytes32 key, address val) private;
```

**Parameters**

| Name  | Type      | Description                     |
| ----- | --------- | ------------------------------- |
| `key` | `bytes32` | The key identifying the account |
| `val` | `address` | The new account address         |

## Events

### ContractSet

Emitted when a contract address is set

```solidity
event ContractSet(bytes32 indexed key, address val);
```

**Parameters**

| Name  | Type      | Description                      |
| ----- | --------- | -------------------------------- |
| `key` | `bytes32` | The key identifying the contract |
| `val` | `address` | The new contract address         |

### AccountSet

Emitted when an account address is set

```solidity
event AccountSet(bytes32 indexed key, address val);
```

**Parameters**

| Name  | Type      | Description                     |
| ----- | --------- | ------------------------------- |
| `key` | `bytes32` | The key identifying the account |
| `val` | `address` | The new account address         |

## Errors

### IdenticalValue

Error thrown when attempting to set an identical value

```solidity
error IdenticalValue();
```

### InvalidAddress

Error thrown when an invalid address is provided

```solidity
error InvalidAddress();
```

## Structs

### Init

Configuration for contract initialization

```solidity
struct Init {
    address admin;
}
```
