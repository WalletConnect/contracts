# MintManager
[Git Source](https://github.com/WalletConnect/contracts/blob/67de895b15d7488b46908a69f0cb045943c5c770/src/MintManager.sol)

**Inherits:**
Ownable

Set as `owner` of the BRR L1 token and responsible for the token inflation schedule.
Contract acts as the token "mint manager" with permission to the `mint` function only.
Currently permitted to mint once per year of up to 2% of the total token supply.
Upgradable to allow changes in the inflation schedule.


## State Variables
### governanceToken
The BRR token that the MintManager can mint tokens


```solidity
BRR public immutable governanceToken;
```


### MINT_CAP
The amount of tokens that can be minted per year. The value is a fixed
point number with 4 decimals.


```solidity
uint256 public constant MINT_CAP = 20;
```


### DENOMINATOR
The number of decimals for the MINT_CAP.


```solidity
uint256 public constant DENOMINATOR = 1000;
```


### MINT_PERIOD
The amount of time that must pass before the MINT_CAP number of tokens can
be minted again.


```solidity
uint256 public constant MINT_PERIOD = 365 days;
```


### mintPermittedAfter
Tracks the time of last mint


```solidity
uint256 public mintPermittedAfter;
```


## Functions
### constructor


```solidity
constructor(address initialOwner, address _governanceToken) Ownable(initialOwner);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`initialOwner`|`address`|The owner of this contract|
|`_governanceToken`|`address`|The governance token this contract can mint tokens of|


### mint

Only the token owner is allowed to mint a certain amount of BRR per year.


```solidity
function mint(address account, uint256 amount) public onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to mint new tokens to.|
|`amount`|`uint256`|Amount of tokens to be minted.|


### upgrade

Upgrade the owner of the governance token to a new MintManager.


```solidity
function upgrade(address newMintManager) public onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMintManager`|`address`|The MintManager to upgrade to|


## Events
### TokensMinted
Emitted when tokens are minted


```solidity
event TokensMinted(address indexed account, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address that received the minted tokens|
|`amount`|`uint256`|The amount of tokens minted|

## Errors
### MintingNotPermittedYet
Error thrown when minting is attempted before the permitted time


```solidity
error MintingNotPermittedYet(uint256 timestamp, uint256 mintPermittedAfter);
```

### MintAmountExceedsCap
Error thrown when the mint amount exceeds the cap


```solidity
error MintAmountExceedsCap(uint256 mintAmount, uint256 maxMintAmount);
```

### MintManagerCannotBeEmpty
Error thrown when trying to upgrade to an empty address


```solidity
error MintManagerCannotBeEmpty();
```

