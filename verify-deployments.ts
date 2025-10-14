import fs from "fs";
import { createPublicClient, http, getAddress, isAddress } from "viem";
import { mainnet, optimism, base } from "viem/chains";

interface DeploymentEntry {
  name: string;
  address: string;
  args?: any[];
  proxy?: {
    admin?: string;
    implementation?: string;
    owner?: string;
    type?: "transparent" | "uups" | "custom";
  };
}

interface DeploymentData {
  [contractName: string]: DeploymentEntry;
}

interface ChainConfig {
  id: number;
  name: string;
  client: any;
  deploymentFile: string;
}

const CHAINS: ChainConfig[] = [
  {
    id: 1,
    name: "Ethereum",
    client: createPublicClient({ chain: mainnet, transport: http() }),
    deploymentFile: "evm/deployments/1.json",
  },
  {
    id: 10,
    name: "OP Mainnet",
    client: createPublicClient({ chain: optimism, transport: http() }),
    deploymentFile: "evm/deployments/10.json",
  },
  {
    id: 8453,
    name: "Base",
    client: createPublicClient({ chain: base, transport: http() }),
    deploymentFile: "evm/deployments/8453.json",
  },
];

// Contract display names (consistent with generate-deployment-docs.ts)
const CONTRACT_DISPLAY_NAMES: Record<string, string> = {
  WCT: "WCT Token",
  L2WCT: "L2WCT Token",
  AdminTimelock: "Admin Timelock",
  ManagerTimelock: "Manager Timelock",
  NttManager: "NTT Manager",
  NttTransceiver: "NTT Transceiver",
  LockedTokenStakerBackers: "LockedTokenStaker Backers",
  LockedTokenStakerReown: "LockedTokenStaker Reown",
  LockedTokenStakerWalletConnect: "LockedTokenStaker WalletConnect",
  MerkleVesterBackers: "MerkleVester Backers",
  MerkleVesterReown: "MerkleVester Reown",
  MerkleVesterWalletConnect: "MerkleVester WalletConnect",
  StakingRewardsCalculator: "StakingRewardCalculator",
};

// EIP-1967 storage slots
const EIP1967_IMPLEMENTATION_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";
const EIP1967_ADMIN_SLOT = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103";

async function loadDeploymentData(filePath: string): Promise<DeploymentData | null> {
  try {
    if (!fs.existsSync(filePath)) {
      console.warn(`⚠️  Deployment file not found: ${filePath}`);
      return null;
    }

    const data = fs.readFileSync(filePath, "utf8");
    return JSON.parse(data);
  } catch (error) {
    console.error(`❌ Error reading ${filePath}:`, error);
    return null;
  }
}

function getContractDisplayName(contractName: string): string {
  return CONTRACT_DISPLAY_NAMES[contractName] || contractName;
}

async function getStorageSlot(client: any, address: string, slot: string): Promise<string | null> {
  try {
    const result = await client.getStorageAt({
      address: address as `0x${string}`,
      slot: slot as `0x${string}`,
    });

    if (!result || result === "0x0000000000000000000000000000000000000000000000000000000000000000") {
      return null;
    }

    // Extract address from storage slot (last 20 bytes)
    const addressHex = result.slice(-40);
    return getAddress(`0x${addressHex}`);
  } catch (error) {
    console.error(`Error reading storage slot for ${address}:`, error);
    return null;
  }
}

async function verifyContract(client: any, chainName: string, contractName: string, deployment: DeploymentEntry) {
  const displayName = getContractDisplayName(contractName);
  console.log(`\n🔍 Verifying ${displayName} on ${chainName}...`);

  if (!isAddress(deployment.address)) {
    console.error(`❌ Invalid address format: ${deployment.address}`);
    return false;
  }

  // Check if contract exists
  try {
    const code = await client.getBytecode({ address: deployment.address });
    if (!code || code === "0x") {
      console.error(`❌ No contract code found at ${deployment.address}`);
      return false;
    }
    console.log(`✅ Contract exists at ${deployment.address}`);
  } catch (error) {
    console.error(`❌ Error checking contract existence:`, error);
    return false;
  }

  // Check proxy configuration if proxy metadata exists
  if (deployment.proxy) {
    console.log(`🔧 Checking proxy configuration...`);

    // Get implementation address
    const implementation = await getStorageSlot(client, deployment.address, EIP1967_IMPLEMENTATION_SLOT);
    if (!implementation) {
      console.error(`❌ No implementation found in EIP-1967 slot`);
      return false;
    }
    console.log(`✅ Implementation: ${implementation}`);

    // Verify implementation matches
    if (
      deployment.proxy.implementation &&
      implementation.toLowerCase() !== deployment.proxy.implementation.toLowerCase()
    ) {
      console.error(`❌ Implementation mismatch!`);
      console.error(`   Expected: ${deployment.proxy.implementation}`);
      console.error(`   Actual:   ${implementation}`);
      return false;
    }

    // Check admin for transparent proxies
    if (deployment.proxy.admin) {
      const admin = await getStorageSlot(client, deployment.address, EIP1967_ADMIN_SLOT);
      if (!admin) {
        console.error(`❌ No admin found in EIP-1967 slot`);
        return false;
      }

      if (admin.toLowerCase() !== deployment.proxy.admin.toLowerCase()) {
        console.error(`❌ ProxyAdmin mismatch!`);
        console.error(`   Expected: ${deployment.proxy.admin}`);
        console.error(`   Actual:   ${admin}`);
        return false;
      }
      console.log(`✅ ProxyAdmin verified: ${admin}`);
    }

    // Check owner for UUPS proxies
    if (deployment.proxy.owner) {
      try {
        const result = await client.readContract({
          address: deployment.address as `0x${string}`,
          abi: [
            { inputs: [], name: "owner", outputs: [{ type: "address" }], stateMutability: "view", type: "function" },
          ],
          functionName: "owner",
        });

        const owner = result as string;
        if (owner.toLowerCase() !== deployment.proxy.owner.toLowerCase()) {
          console.error(`❌ Owner mismatch!`);
          console.error(`   Expected: ${deployment.proxy.owner}`);
          console.error(`   Actual:   ${owner}`);
          return false;
        }
        console.log(`✅ Owner verified: ${owner}`);
      } catch (error) {
        console.error(`❌ Error reading owner():`, error);
        return false;
      }
    }
  } else {
    // For non-proxy contracts, check that they don't have proxy storage
    const implementation = await getStorageSlot(client, deployment.address, EIP1967_IMPLEMENTATION_SLOT);
    if (implementation) {
      console.warn(`⚠️  Contract appears to be a proxy but is marked as non-proxy`);
      console.warn(`   Implementation found: ${implementation}`);
    } else {
      console.log(`✅ Confirmed non-proxy contract`);
    }
  }

  return true;
}

async function verifyChain(chainConfig: ChainConfig) {
  console.log(`\n🌐 === Verifying ${chainConfig.name} (Chain ID: ${chainConfig.id}) ===`);

  const deploymentData = await loadDeploymentData(chainConfig.deploymentFile);
  if (!deploymentData) {
    console.error(`❌ Could not load deployment data for ${chainConfig.name}`);
    return false;
  }

  const results: { contractName: string; success: boolean }[] = [];

  // Filter out chainId and verify contracts
  const contracts = Object.entries(deploymentData).filter(([name]) => name !== "chainId");

  for (const [contractName, deployment] of contracts) {
    const success = await verifyContract(chainConfig.client, chainConfig.name, contractName, deployment);
    results.push({ contractName, success });
  }

  const successCount = results.filter((r) => r.success).length;
  const totalCount = results.length;

  console.log(`\n📊 ${chainConfig.name} Results: ${successCount}/${totalCount} contracts verified successfully`);

  if (successCount < totalCount) {
    console.log(`❌ Failed contracts:`);
    results
      .filter((r) => !r.success)
      .forEach((r) => {
        console.log(`   - ${getContractDisplayName(r.contractName)}`);
      });
  }

  return successCount === totalCount;
}

async function main() {
  console.log("🚀 Starting deployment verification...");
  console.log("📋 This script will verify:");
  console.log("   • Contract existence at documented addresses");
  console.log("   • Proxy admin addresses for proxy contracts");
  console.log("   • Implementation addresses for proxy contracts");

  try {
    const results: { chain: string; success: boolean }[] = [];

    for (const chainConfig of CHAINS) {
      const success = await verifyChain(chainConfig);
      results.push({ chain: chainConfig.name, success });
    }

    // Final summary
    console.log("\n🎯 === FINAL SUMMARY ===");
    for (const result of results) {
      console.log(`${result.chain}: ${result.success ? "✅ PASSED" : "❌ FAILED"}`);
    }

    const allPassed = results.every((r) => r.success);
    if (allPassed) {
      console.log("\n🎉 All deployments verified successfully!");
      process.exit(0);
    } else {
      console.log("\n💥 Some verifications failed. Please check the logs above.");
      process.exit(1);
    }
  } catch (error) {
    console.error("💥 Fatal error during verification:", error);
    process.exit(1);
  }
}

// Run the verification
main().catch(console.error);
