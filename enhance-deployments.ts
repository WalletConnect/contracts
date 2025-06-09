import fs from "fs";
import { createPublicClient, http, getAddress } from "viem";
import { mainnet, optimism } from "viem/chains";

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
  [contractName: string]: DeploymentEntry | number; // Allow chainId as number
}

interface ChainConfig {
  id: number;
  name: string;
  client: any;
  deploymentFile: string;
  nttChainName?: string; // For matching with NTT config
}

interface NTTConfig {
  network: string;
  chains: {
    [chainName: string]: {
      version: string;
      mode: string;
      paused: boolean;
      owner: string;
      manager: string;
      token: string;
      transceivers: {
        threshold: number;
        wormhole: {
          address: string;
          pauser?: string;
        };
      };
      limits: {
        outbound: string;
        inbound: Record<string, string>;
      };
      pauser?: string;
    };
  };
}

const CHAINS: ChainConfig[] = [
  {
    id: 1,
    name: "Ethereum",
    client: createPublicClient({ chain: mainnet, transport: http() }),
    deploymentFile: "evm/deployments/1.json",
    nttChainName: "Ethereum",
  },
  {
    id: 10,
    name: "OP Mainnet",
    client: createPublicClient({ chain: optimism, transport: http() }),
    deploymentFile: "evm/deployments/10.json",
    nttChainName: "Optimism",
  },
];

const NTT_CONFIG_FILE = "ntt/mainnet_deployment.json";

// EIP-1967 storage slots
const EIP1967_IMPLEMENTATION_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";
const EIP1967_ADMIN_SLOT = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103";

async function loadNTTConfig(): Promise<NTTConfig | null> {
  try {
    if (!fs.existsSync(NTT_CONFIG_FILE)) {
      console.warn(`⚠️  NTT config file not found: ${NTT_CONFIG_FILE}`);
      return null;
    }

    const data = fs.readFileSync(NTT_CONFIG_FILE, "utf8");
    return JSON.parse(data);
  } catch (error) {
    console.error(`❌ Error reading NTT config:`, error);
    return null;
  }
}

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

async function getOwner(client: any, address: string): Promise<string | null> {
  try {
    const result = await client.readContract({
      address: address as `0x${string}`,
      abi: [{ inputs: [], name: "owner", outputs: [{ type: "address" }], stateMutability: "view", type: "function" }],
      functionName: "owner",
    });

    return result as string;
  } catch (error) {
    // Many contracts don't have owner() function
    return null;
  }
}

async function enhanceContractWithProxyData(client: any, address: string): Promise<any> {
  console.log(`🔍 Analyzing ${address}...`);

  const proxyData: any = {};

  // Check for EIP-1967 implementation slot
  const implementation = await getStorageSlot(client, address, EIP1967_IMPLEMENTATION_SLOT);
  if (implementation) {
    proxyData.implementation = implementation;
    console.log(`   💎 Implementation: ${implementation}`);

    // Check for admin (Transparent proxy)
    const admin = await getStorageSlot(client, address, EIP1967_ADMIN_SLOT);
    if (admin) {
      proxyData.admin = admin;
      proxyData.type = "transparent";
      console.log(`   👑 ProxyAdmin: ${admin}`);
    } else {
      // Check for owner (UUPS proxy)
      const owner = await getOwner(client, address);
      if (owner) {
        proxyData.owner = owner;
        proxyData.type = "uups";
        console.log(`   👑 Owner: ${owner}`);
      }
    }
  } else {
    console.log(`   ✅ Non-proxy contract`);
    return null;
  }

  return proxyData;
}

async function syncNTTContracts(
  chainConfig: ChainConfig,
  deploymentData: DeploymentData,
  nttConfig: NTTConfig | null,
): Promise<boolean> {
  if (!nttConfig || !chainConfig.nttChainName) {
    return false;
  }

  const nttChainData = nttConfig.chains[chainConfig.nttChainName];
  if (!nttChainData) {
    console.warn(`⚠️  No NTT data found for ${chainConfig.nttChainName}`);
    return false;
  }

  let updated = false;

  // Sync NTT Manager
  const expectedManager = nttChainData.manager;
  const currentManager = deploymentData.NttManager;
  if (!currentManager || typeof currentManager === "number" || currentManager.address !== expectedManager) {
    console.log(`🔄 Syncing NTT Manager: ${expectedManager}`);
    const proxyData = await enhanceContractWithProxyData(chainConfig.client, expectedManager);

    deploymentData.NttManager = {
      name: "NTT Manager",
      address: expectedManager,
      ...(proxyData && { proxy: proxyData }),
    };
    updated = true;
  }

  // Sync NTT Transceiver
  const expectedTransceiver = nttChainData.transceivers.wormhole.address;
  const currentTransceiver = deploymentData.NttTransceiver;
  if (
    !currentTransceiver ||
    typeof currentTransceiver === "number" ||
    currentTransceiver.address !== expectedTransceiver
  ) {
    console.log(`🔄 Syncing NTT Transceiver: ${expectedTransceiver}`);
    const proxyData = await enhanceContractWithProxyData(chainConfig.client, expectedTransceiver);

    deploymentData.NttTransceiver = {
      name: "NTT Transceiver",
      address: expectedTransceiver,
      ...(proxyData && { proxy: proxyData }),
    };
    updated = true;
  }

  if (updated) {
    console.log(`✅ ${chainConfig.name} NTT contracts synced with official config`);
  }

  return updated;
}

async function enhanceChainDeployments(chainConfig: ChainConfig): Promise<void> {
  console.log(`\n🌐 === Enhancing ${chainConfig.name} Deployments ===`);

  // Load existing deployment data
  let deploymentData = await loadDeploymentData(chainConfig.deploymentFile);
  if (!deploymentData) {
    console.log(`📁 Creating new deployment file for ${chainConfig.name}`);
    deploymentData = { chainId: chainConfig.id };
  }

  // Load NTT config and sync NTT contracts first
  const nttConfig = await loadNTTConfig();
  const nttUpdated = await syncNTTContracts(chainConfig, deploymentData!, nttConfig);

  let hasUpdates = nttUpdated;

  // Enhance existing contracts with proxy data
  const contracts = Object.entries(deploymentData).filter(([name]) => name !== "chainId");

  for (const [contractName, deployment] of contracts) {
    // Skip chainId and non-deployment entries
    if (typeof deployment === "number") {
      continue;
    }

    // Skip if already has proxy data
    if (deployment.proxy) {
      console.log(`⏭️  ${contractName} already has proxy data, skipping`);
      continue;
    }

    const proxyData = await enhanceContractWithProxyData(chainConfig.client, deployment.address);
    if (proxyData) {
      deployment.proxy = proxyData;
      hasUpdates = true;
      console.log(`✅ Enhanced ${contractName} with proxy data`);
    }
  }

  // Save updates if any
  if (hasUpdates) {
    fs.writeFileSync(chainConfig.deploymentFile, JSON.stringify(deploymentData, null, 2) + "\n");
    console.log(`💾 Updated ${chainConfig.deploymentFile}`);
  } else {
    console.log(`✅ No updates needed for ${chainConfig.name}`);
  }
}

async function main() {
  console.log("🚀 Enhancing deployment files with blockchain proxy data...");
  console.log("📋 This will:");
  console.log("   • Sync NTT contracts with official ntt/mainnet_deployment.json");
  console.log("   • Scan blockchain for proxy configurations");
  console.log("   • Update JSON files with enhanced metadata\n");

  try {
    for (const chainConfig of CHAINS) {
      await enhanceChainDeployments(chainConfig);
    }

    console.log("\n🎉 All deployment files enhanced successfully!");
    console.log("\n💡 Next steps:");
    console.log("   1. Run 'pnpm run generate:docs' to update documentation");
    console.log("   2. Run 'pnpm run verify:deployments' to validate everything");
    console.log("   3. Or just run 'pnpm run sync:deployments' to do all steps");
  } catch (error) {
    console.error("💥 Error enhancing deployments:", error);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

export { enhanceChainDeployments, loadNTTConfig, loadDeploymentData };
