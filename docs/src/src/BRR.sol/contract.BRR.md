# BRR
[Git Source](https://github.com/WalletConnect/contracts/blob/67de895b15d7488b46908a69f0cb045943c5c770/src/BRR.sol)

**Inherits:**
ERC20VotesUpgradeable, ERC20PermitUpgradeable, ERC20BurnableUpgradeable, OwnableUpgradeable

**Author:**
BakersSyndicate

This contract implements the L1 BRR token with burn, permit, and voting functionality


## Functions
### initialize

Initializes the BRR token


```solidity
function initialize(Init calldata init) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`init`|`Init`|The initialization data for the contract|


### mint

Mints new tokens


```solidity
function mint(address account, uint256 amount) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address that will receive the minted tokens|
|`amount`|`uint256`|The amount of tokens to mint|


### clock

Returns the current timestamp as a uint48


```solidity
function clock() public view override returns (uint48);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint48`|The current block timestamp|


### CLOCK_MODE

Returns the clock mode


```solidity
function CLOCK_MODE() public pure override returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|A string indicating the clock mode|


### _update


```solidity
function _update(address from, address to, uint256 value) internal override(ERC20Upgradeable, ERC20VotesUpgradeable);
```

### nonces


```solidity
function nonces(address nonceOwner) public view override(ERC20PermitUpgradeable, NoncesUpgradeable) returns (uint256);
```

## Structs
### Init
Initialization data for the contract


```solidity
struct Init {
    address initialOwner;
}
```

