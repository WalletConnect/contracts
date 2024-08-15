# PermissionedNodeRegistry

[Git Source](https://github.com/dwacfn/contracts/blob/67de895b15d7488b46908a69f0cb045943c5c770/src/PermissionedNodeRegistry.sol)

**Inherits:** AccessControl

**Author:** BakersSyndicate

Contract for managing a whitelist of permissioned nodes

## State Variables

### ADMIN_ROLE

Role for administrative actions

```solidity
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
```

### maxNodes

Maximum number of nodes allowed in the whitelist

```solidity
uint8 public maxNodes;
```

### \_stakingAllowlist

Set of whitelisted node addresses

```solidity
EnumerableSet.AddressSet private _stakingAllowlist;
```

## Functions

### constructor

Initializes the contract

```solidity
constructor(address initialAdmin, uint8 maxNodes_);
```

**Parameters**

| Name           | Type      | Description                         |
| -------------- | --------- | ----------------------------------- |
| `initialAdmin` | `address` | The address of the initial admin    |
| `maxNodes_`    | `uint8`   | The initial maximum number of nodes |

### whitelistNode

Whitelists a node

```solidity
function whitelistNode(address node) external onlyRole(ADMIN_ROLE);
```

**Parameters**

| Name   | Type      | Description                          |
| ------ | --------- | ------------------------------------ |
| `node` | `address` | The address of the node to whitelist |

### removeNodeFromWhitelist

Removes a node from the whitelist

```solidity
function removeNodeFromWhitelist(address node) external onlyRole(ADMIN_ROLE);
```

**Parameters**

| Name   | Type      | Description                       |
| ------ | --------- | --------------------------------- |
| `node` | `address` | The address of the node to remove |

### isNodeWhitelisted

Checks if a node is whitelisted

```solidity
function isNodeWhitelisted(address node) external view returns (bool);
```

**Parameters**

| Name   | Type      | Description                      |
| ------ | --------- | -------------------------------- |
| `node` | `address` | The address of the node to check |

**Returns**

| Name     | Type   | Description                                      |
| -------- | ------ | ------------------------------------------------ |
| `<none>` | `bool` | True if the node is whitelisted, false otherwise |

### getWhitelistedNodes

Gets all whitelisted nodes

```solidity
function getWhitelistedNodes() external view returns (address[] memory);
```

**Returns**

| Name     | Type        | Description                            |
| -------- | ----------- | -------------------------------------- |
| `<none>` | `address[]` | An array of whitelisted node addresses |

### getWhitelistedNodesCount

Gets the count of whitelisted nodes

```solidity
function getWhitelistedNodesCount() external view returns (uint256);
```

**Returns**

| Name     | Type      | Description                     |
| -------- | --------- | ------------------------------- |
| `<none>` | `uint256` | The number of whitelisted nodes |

### getWhitelistedNodeAtIndex

Gets a whitelisted node at a specific index

```solidity
function getWhitelistedNodeAtIndex(uint256 index) external view returns (address);
```

**Parameters**

| Name    | Type      | Description                            |
| ------- | --------- | -------------------------------------- |
| `index` | `uint256` | The index of the node in the whitelist |

**Returns**

| Name     | Type      | Description                                |
| -------- | --------- | ------------------------------------------ |
| `<none>` | `address` | The address of the node at the given index |

### setMaxNodes

Sets the maximum number of nodes allowed in the whitelist

```solidity
function setMaxNodes(uint8 maxNodes_) external onlyRole(ADMIN_ROLE);
```

**Parameters**

| Name        | Type    | Description                     |
| ----------- | ------- | ------------------------------- |
| `maxNodes_` | `uint8` | The new maximum number of nodes |

## Events

### NodeWhitelisted

Emitted when a node is whitelisted

```solidity
event NodeWhitelisted(address indexed node);
```

**Parameters**

| Name   | Type      | Description                         |
| ------ | --------- | ----------------------------------- |
| `node` | `address` | The address of the whitelisted node |

### NodeRemovedFromWhitelist

Emitted when a node is removed from the whitelist

```solidity
event NodeRemovedFromWhitelist(address indexed node);
```

**Parameters**

| Name   | Type      | Description                     |
| ------ | --------- | ------------------------------- |
| `node` | `address` | The address of the removed node |

### MaxNodesSet

Emitted when the maximum number of nodes is set

```solidity
event MaxNodesSet(uint8 maxNodes);
```

**Parameters**

| Name       | Type    | Description                     |
| ---------- | ------- | ------------------------------- |
| `maxNodes` | `uint8` | The new maximum number of nodes |

## Errors

### NodeNotWhitelisted

Error thrown when attempting to interact with a non-whitelisted node

```solidity
error NodeNotWhitelisted(address node);
```

### NodeAlreadyWhitelisted

Error thrown when attempting to whitelist an already whitelisted node

```solidity
error NodeAlreadyWhitelisted(address node);
```

### WhitelistFull

Error thrown when the whitelist is full

```solidity
error WhitelistFull();
```

### UnchangedState

Error thrown when attempting to set an unchanged state

```solidity
error UnchangedState();
```
