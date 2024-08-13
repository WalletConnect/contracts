# ILegacyMintableERC20
[Git Source](https://github.com/WalletConnect/contracts/blob/67de895b15d7488b46908a69f0cb045943c5c770/src/interfaces/IOptimismMintableERC20.sol)

**Inherits:**
IERC165

This interface was available on the legacy L2StandardERC20 contract.
It remains available on the OptimismMintableERC20 contract for
backwards compatibility.


## Functions
### l1Token


```solidity
function l1Token() external view returns (address);
```

### mint


```solidity
function mint(address _to, uint256 _amount) external;
```

### burn


```solidity
function burn(address _from, uint256 _amount) external;
```

