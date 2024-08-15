# L2BRR

[Git Source](https://github.com/dwacfn/contracts/blob/67de895b15d7488b46908a69f0cb045943c5c770/src/L2BRR.sol)

**Inherits:** [IOptimismMintableERC20](/src/interfaces/IOptimismMintableERC20.sol/interface.IOptimismMintableERC20.md),
[ILegacyMintableERC20](/src/interfaces/IOptimismMintableERC20.sol/interface.ILegacyMintableERC20.md), ERC20Permit,
ERC20Votes, Ownable, [ISemver](/src/interfaces/ISemver.sol/interface.ISemver.md)

## State Variables

### transferRestrictionsDisabledAfter

The timestamp after which transfer restrictions are disabled

```solidity
uint256 public transferRestrictionsDisabledAfter;
```

### allowedFrom

Mapping of addresses that are allowed to transfer tokens to any address

```solidity
mapping(address account => bool isAllowed) public allowedFrom;
```

### allowedTo

Mapping of addresses that are allowed to receive tokens from any address

```solidity
mapping(address account => bool isAllowed) public allowedTo;
```

### REMOTE_TOKEN

Address of the corresponding version of this token on the remote chain

```solidity
address public immutable REMOTE_TOKEN;
```

### BRIDGE

Address of the StandardBridge on this network

```solidity
address public immutable BRIDGE;
```

### version

Semantic version

```solidity
string public constant version = "1.0.0";
```

## Functions

### onlyBridge

A modifier that only allows the bridge to call

```solidity
modifier onlyBridge();
```

### constructor

```solidity
constructor(
    address initialOwner,
    address _bridge,
    address _remoteToken
)
    ERC20("Brownie", "BRR")
    ERC20Permit("Brownie")
    Ownable(initialOwner);
```

**Parameters**

| Name           | Type      | Description                                  |
| -------------- | --------- | -------------------------------------------- |
| `initialOwner` | `address` | Address of the initial owner of the contract |
| `_bridge`      | `address` | Address of the L2 standard bridge            |
| `_remoteToken` | `address` | Address of the corresponding L1 token        |

### l1Token

Legacy getter for the remote token. Use REMOTE_TOKEN going forward

```solidity
function l1Token() public view returns (address);
```

### l2Bridge

Legacy getter for the bridge. Use BRIDGE going forward

```solidity
function l2Bridge() public view returns (address);
```

### remoteToken

Legacy getter for REMOTE_TOKEN

```solidity
function remoteToken() public view returns (address);
```

### bridge

Legacy getter for BRIDGE

```solidity
function bridge() public view returns (address);
```

### supportsInterface

ERC165 interface check function

```solidity
function supportsInterface(bytes4 interfaceId) external pure override returns (bool);
```

**Parameters**

| Name          | Type     | Description           |
| ------------- | -------- | --------------------- |
| `interfaceId` | `bytes4` | Interface ID to check |

**Returns**

| Name     | Type   | Description                                                |
| -------- | ------ | ---------------------------------------------------------- |
| `<none>` | `bool` | Whether or not the interface is supported by this contract |

### mint

Allows the StandardBridge on this network to mint tokens

```solidity
function mint(
    address _to,
    uint256 _amount
)
    external
    virtual
    override(IOptimismMintableERC20, ILegacyMintableERC20)
    onlyBridge;
```

**Parameters**

| Name      | Type      | Description               |
| --------- | --------- | ------------------------- |
| `_to`     | `address` | Address to mint tokens to |
| `_amount` | `uint256` | Amount of tokens to mint  |

### burn

Allows the StandardBridge on this network to burn tokens

```solidity
function burn(
    address _from,
    uint256 _amount
)
    external
    virtual
    override(IOptimismMintableERC20, ILegacyMintableERC20)
    onlyBridge;
```

**Parameters**

| Name      | Type      | Description                 |
| --------- | --------- | --------------------------- |
| `_from`   | `address` | Address to burn tokens from |
| `_amount` | `uint256` | Amount of tokens to burn    |

### setAllowedFrom

This function allows the owner to set the allowedFrom status of an address

```solidity
function setAllowedFrom(address from, bool isAllowedFrom) external onlyOwner;
```

**Parameters**

| Name            | Type      | Description                                       |
| --------------- | --------- | ------------------------------------------------- |
| `from`          | `address` | The address whose allowedFrom status is being set |
| `isAllowedFrom` | `bool`    | The new allowedFrom status                        |

### setAllowedTo

This function allows the owner to set the allowedTo status of an address

```solidity
function setAllowedTo(address to, bool isAllowedTo) external onlyOwner;
```

**Parameters**

| Name          | Type      | Description                                     |
| ------------- | --------- | ----------------------------------------------- |
| `to`          | `address` | The address whose allowedTo status is being set |
| `isAllowedTo` | `bool`    | The new allowedTo status                        |

### disableTransferRestrictions

Allows the owner to disable transfer restrictions

```solidity
function disableTransferRestrictions() external onlyOwner;
```

### clock

_Clock used for flagging checkpoints. Has been overridden to implement timestamp based checkpoints (and voting)_

```solidity
function clock() public view override returns (uint48);
```

### CLOCK_MODE

_Machine-readable description of the clock as specified in EIP-6372. Has been overridden to inform callers that this
contract uses timestamps instead of block numbers, to match `clock()`_

```solidity
function CLOCK_MODE() public pure override returns (string memory);
```

### \_setAllowedFrom

```solidity
function _setAllowedFrom(address from, bool isAllowedFrom) internal;
```

### \_setAllowedTo

```solidity
function _setAllowedTo(address to, bool isAllowedTo) internal;
```

### \_update

Overrides the update function to enforce transfer restrictions

```solidity
function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes);
```

**Parameters**

| Name    | Type      | Description                                   |
| ------- | --------- | --------------------------------------------- |
| `from`  | `address` | The address tokens are being transferred from |
| `to`    | `address` | The address tokens are being transferred to   |
| `value` | `uint256` | The amount of tokens being transferred        |

### nonces

```solidity
function nonces(address nonceOwner) public view override(ERC20Permit, Nonces) returns (uint256);
```

## Events

### SetAllowedFrom

Emitted when the allowedFrom status of an address is set

```solidity
event SetAllowedFrom(address indexed from, bool isAllowedFrom);
```

### SetAllowedTo

Emitted when the allowedTo status of an address is set

```solidity
event SetAllowedTo(address indexed to, bool isAllowedTo);
```

### TransferRestrictionsDisabled

Emitted when the transfer restrictions are disabled

```solidity
event TransferRestrictionsDisabled();
```

### Mint

Emitted whenever tokens are minted for an account

```solidity
event Mint(address indexed account, uint256 amount);
```

**Parameters**

| Name      | Type      | Description                                        |
| --------- | --------- | -------------------------------------------------- |
| `account` | `address` | Address of the account tokens are being minted for |
| `amount`  | `uint256` | Amount of tokens minted                            |

### Burn

Emitted whenever tokens are burned from an account

```solidity
event Burn(address indexed account, uint256 amount);
```

**Parameters**

| Name      | Type      | Description                                         |
| --------- | --------- | --------------------------------------------------- |
| `account` | `address` | Address of the account tokens are being burned from |
| `amount`  | `uint256` | Amount of tokens burned                             |

## Errors

### OnlyBridge

Custom errors

```solidity
error OnlyBridge();
```

### TransferRestrictionsAlreadyDisabled

```solidity
error TransferRestrictionsAlreadyDisabled();
```

### TransferRestricted

```solidity
error TransferRestricted();
```
