import {
  createPublicClient,
  http,
  encodeAbiParameters,
  keccak256,
  Address,
  toBytes,
  Hash,
  createWalletClient,
  PublicClient,
  WalletClient,
  TypedDataDomain,
  HttpTransport,
} from "viem";
import { optimism } from "viem/chains";
import DELEGATE_REGISTRY_ABI from "./DelegateRegistryABI";
import { privateKeyToAccount } from "viem/accounts";

// Constants
const DELEGATOR_PK = "0xfbad6936745f0af56e4b5af9fd274b40c082e26dff7861ec008662f56ddd6c2c" as const;
const DELEGATE_PK = "0xe878749b43e7562007cea4133e0f4cd36f57ab1f38c452f90fca7a302f2a24f2" as const;
const DELEGATE_REGISTRY = "0x5F39D07aCb0B638DaE480D4d2F4823CE014dC3d5" as const;

// Types
type DelegateMessage = {
  domain: TypedDataDomain;
  types: {
    EIP712Domain: typeof EIP712_DOMAIN;
    MetaTransaction: typeof META_TRANSACTION_TYPE;
  };
  primaryType: "MetaTransaction";
  message: {
    nonce: bigint;
    from: Address;
    functionSignature: Hash;
  };
};

// EIP712 Types as constants
const EIP712_DOMAIN = [
  { name: "name", type: "string" },
  { name: "version", type: "string" },
  { name: "verifyingContract", type: "address" },
  { name: "chainId", type: "uint256" },
] as const;

const META_TRANSACTION_TYPE = [
  { name: "nonce", type: "uint256" },
  { name: "from", type: "address" },
  { name: "functionSignature", type: "bytes" },
] as const;

// Pure functions
const parseSignature = (signature: Hash) => ({
  r: signature.slice(0, 66) as Hash,
  s: ("0x" + signature.slice(66, 130)) as Hash,
  v: parseInt(signature.slice(130, 132), 16),
});

const generateDomainData = (contractAddress: Address, chainId: number): TypedDataDomain => ({
  name: "MetaTxDelegateRegistry",
  version: "1",
  verifyingContract: contractAddress,
  chainId,
});

// Add this helper function at the top with other pure functions
const bigIntReplacer = (_key: string, value: any) => (typeof value === "bigint" ? value.toString() : value);

// Message generator function
const generateDelegationMessage = async (
  client: PublicClient<HttpTransport, typeof optimism>,
  contractAddress: Address,
  delegator: Address,
  delegateId: string,
  delegateAddress: Address,
): Promise<DelegateMessage> => {
  if (!client.chain) {
    throw new Error("Chain must be defined");
  }

  const nonce = await client.readContract({
    address: contractAddress,
    abi: DELEGATE_REGISTRY_ABI,
    functionName: "getNonce",
    args: [delegator],
  });

  const functionSignature = encodeAbiParameters(
    [{ type: "bytes32" }, { type: "address" }],
    [keccak256(toBytes(delegateId)), delegateAddress],
  );

  return {
    domain: generateDomainData(contractAddress, client.chain.id),
    types: {
      EIP712Domain: EIP712_DOMAIN,
      MetaTransaction: META_TRANSACTION_TYPE,
    },
    primaryType: "MetaTransaction",
    message: {
      nonce,
      from: delegator,
      functionSignature,
    },
  };
};

// Client setup functions
const createClients = (): {
  publicClient: PublicClient<HttpTransport, typeof optimism>;
  delegatorWallet: WalletClient;
  delegateWallet: WalletClient;
} => {
  const publicClient = createPublicClient({
    chain: optimism,
    transport: http(),
  });

  const delegatorWallet = createWalletClient({
    account: privateKeyToAccount(DELEGATOR_PK),
    chain: optimism,
    transport: http(),
  });

  const delegateWallet = createWalletClient({
    account: privateKeyToAccount(DELEGATE_PK),
    chain: optimism,
    transport: http(),
  });

  return {
    publicClient,
    delegatorWallet,
    delegateWallet,
  };
};

// Example usage as an async function
const example = async () => {
  // Setup clients
  const { publicClient, delegatorWallet, delegateWallet } = createClients();

  if (!delegatorWallet.account) {
    throw new Error("Delegator wallet account is undefined");
  }

  if (!delegateWallet.account) {
    throw new Error("Delegate wallet account is undefined");
  }

  // Generate message
  const messageToSign = await generateDelegationMessage(
    publicClient,
    DELEGATE_REGISTRY,
    delegatorWallet.account.address,
    "my-delegation-id",
    delegateWallet.account.address,
  );

  console.log("Message for delegator to sign:", JSON.stringify(messageToSign, bigIntReplacer, 2));

  // Sign message
  const signedMessage = await delegatorWallet.signTypedData({
    types: messageToSign.types,
    primaryType: messageToSign.primaryType,
    message: messageToSign.message,
    domain: {
      name: "MetaTxDelegateRegistry",
      version: "1",
      verifyingContract: DELEGATE_REGISTRY,
      chainId: BigInt(publicClient.chain?.id),
    },
    account: delegatorWallet.account,
  });
  const { r, s, v } = parseSignature(signedMessage);

  console.log("Signed message:", signedMessage);

  console.log({ r, s, v });
};

// Run example
example().catch(console.error);
