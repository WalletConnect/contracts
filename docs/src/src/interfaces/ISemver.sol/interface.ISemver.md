# ISemver

[Git Source](https://github.com/dwacfn/contracts/blob/67de895b15d7488b46908a69f0cb045943c5c770/src/interfaces/ISemver.sol)

ISemver is a simple contract for ensuring that contracts are versioned using semantic versioning.

## Functions

### version

Getter for the semantic version of the contract. This is not meant to be used onchain but instead meant to be used by
offchain tooling.

```solidity
function version() external view returns (string memory);
```

**Returns**

| Name     | Type     | Description                          |
| -------- | -------- | ------------------------------------ |
| `<none>` | `string` | Semver contract version as a string. |
