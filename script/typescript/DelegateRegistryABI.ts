const abi = [
  {
    type: "constructor",
    inputs: [
      { name: "name", type: "string", internalType: "string" },
      { name: "version", type: "string", internalType: "string" },
    ],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "clearDelegate",
    inputs: [{ name: "id", type: "bytes32", internalType: "bytes32" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "delegation",
    inputs: [
      { name: "", type: "address", internalType: "address" },
      { name: "", type: "bytes32", internalType: "bytes32" },
    ],
    outputs: [{ name: "", type: "address", internalType: "address" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "executeMetaTransaction",
    inputs: [
      { name: "userAddress", type: "address", internalType: "address" },
      { name: "functionSignature", type: "bytes", internalType: "bytes" },
      { name: "sigR", type: "bytes32", internalType: "bytes32" },
      { name: "sigS", type: "bytes32", internalType: "bytes32" },
      { name: "sigV", type: "uint8", internalType: "uint8" },
    ],
    outputs: [{ name: "", type: "bytes", internalType: "bytes" }],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "getNonce",
    inputs: [{ name: "user", type: "address", internalType: "address" }],
    outputs: [{ name: "nonce", type: "uint256", internalType: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "setDelegate",
    inputs: [
      { name: "id", type: "bytes32", internalType: "bytes32" },
      { name: "delegate", type: "address", internalType: "address" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "event",
    name: "ClearDelegate",
    inputs: [
      { name: "delegator", type: "address", indexed: true, internalType: "address" },
      { name: "id", type: "bytes32", indexed: true, internalType: "bytes32" },
      { name: "delegate", type: "address", indexed: true, internalType: "address" },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "MetaTransactionExecuted",
    inputs: [
      { name: "userAddress", type: "address", indexed: false, internalType: "address" },
      { name: "relayerAddress", type: "address", indexed: false, internalType: "address payable" },
      { name: "functionSignature", type: "bytes", indexed: false, internalType: "bytes" },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "SetDelegate",
    inputs: [
      { name: "delegator", type: "address", indexed: true, internalType: "address" },
      { name: "id", type: "bytes32", indexed: true, internalType: "bytes32" },
      { name: "delegate", type: "address", indexed: true, internalType: "address" },
    ],
    anonymous: false,
  },
] as const;

export default abi;
