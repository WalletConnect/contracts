import fs from "fs";

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
  explorerUrl: string;
  deploymentFile: string;
}

const CHAINS: ChainConfig[] = [
  {
    id: 1,
    name: "Ethereum Mainnet",
    explorerUrl: "https://etherscan.io",
    deploymentFile: "evm/deployments/1.json",
  },
  {
    id: 10,
    name: "Optimism",
    explorerUrl: "https://optimistic.etherscan.io",
    deploymentFile: "evm/deployments/10.json",
  },
  {
    id: 8453,
    name: "Base",
    explorerUrl: "https://basescan.org",
    deploymentFile: "evm/deployments/8453.json",
  },
];

// Special handling for contracts that need custom names or ordering
const CONTRACT_DISPLAY_NAMES: Record<string, string> = {
  WCT: "WCT Token",
  L2WCT: "L2WCT Token",
  AdminTimelock: "Admin Timelock",
  ManagerTimelock: "Manager Timelock",
  NttManager: "NTT Manager",
  NttTransceiver: "NTT Transceiver",
};

// Contract ordering for better documentation structure
const CONTRACT_ORDER = [
  "WCT",
  "L2WCT",
  "Timelock",
  "AdminTimelock",
  "ManagerTimelock",
  "NttManager",
  "NttTransceiver",
  "WalletConnectConfig",
  "Pauser",
  "StakeWeight",
  "StakingRewardDistributor",
  "StakingRewardCalculator",
  "Airdrop",
  "MerkleVester Reown",
  "LockedTokenStaker Reown",
  "MerkleVester WalletConnect",
  "LockedTokenStaker WalletConnect",
  "MerkleVester Backers",
  "LockedTokenStaker Backers",
];

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

function formatAddress(address: string, explorerUrl: string): string {
  return `[\`${address}\`](${explorerUrl}/address/${address})`;
}

function sortContracts(contracts: [string, DeploymentEntry][]): [string, DeploymentEntry][] {
  return contracts.sort(([a], [b]) => {
    const aIndex = CONTRACT_ORDER.indexOf(a);
    const bIndex = CONTRACT_ORDER.indexOf(b);

    // If both are in the order list, sort by their position
    if (aIndex !== -1 && bIndex !== -1) {
      return aIndex - bIndex;
    }

    // If only one is in the order list, prioritize it
    if (aIndex !== -1) return -1;
    if (bIndex !== -1) return 1;

    // If neither is in the order list, sort alphabetically
    return a.localeCompare(b);
  });
}

async function generateMarkdown(): Promise<string> {
  let markdown = "# Deployment Addresses\n\n";
  markdown += "⚠️ **This file is auto-generated from deployment JSON files. Do not edit manually.**\n\n";

  for (const chain of CHAINS) {
    console.log(`📋 Processing ${chain.name}...`);

    const deploymentData = await loadDeploymentData(chain.deploymentFile);
    if (!deploymentData) {
      console.warn(`⚠️  Skipping ${chain.name} - no deployment data`);
      continue;
    }

    markdown += `## ${chain.name} (Chain ID: ${chain.id})\n\n`;
    markdown += "| Contract | Address | ProxyAdmin/Owner (if Proxy contract) |\n";
    markdown += "| -------- | ------- | ------------------------------------ |\n";

    const contracts = Object.entries(deploymentData).filter(([name]) => name !== "chainId");
    const sortedContracts = sortContracts(contracts);

    for (const [contractName, deployment] of sortedContracts) {
      const displayName = getContractDisplayName(contractName);
      const addressLink = formatAddress(deployment.address, chain.explorerUrl);

      let proxyInfo = "-";
      if (deployment.proxy?.admin) {
        proxyInfo = formatAddress(deployment.proxy.admin, chain.explorerUrl) + " (ProxyAdmin)";
      } else if (deployment.proxy?.owner) {
        proxyInfo = formatAddress(deployment.proxy.owner, chain.explorerUrl) + " (Owner)";
      } else if (deployment.proxy?.implementation) {
        proxyInfo = `_${deployment.proxy.type?.toUpperCase() || "UNKNOWN"} Proxy_`;
      }

      markdown += `| ${displayName} | ${addressLink} | ${proxyInfo} |\n`;
    }

    markdown += "\n";
  }

  // Add Solana section (static for now, could be made dynamic later)
  markdown += "## Solana\n\n";
  markdown += "| Contract | Address |\n";
  markdown += "| -------- | ------- |\n";
  markdown +=
    "| WCT Token | [`WCTk5xWdn5SYg56twGj32sUF3W4WFQ48ogezLBuYTBY`](https://explorer.solana.com/address/WCTk5xWdn5SYg56twGj32sUF3W4WFQ48ogezLBuYTBY) |\n";
  markdown +=
    "| NTT Manager | [`nttLq3ZsKu9uAFWuBGksdZTPAjkMRyPkxp61CJPsntA`](https://explorer.solana.com/address/nttLq3ZsKu9uAFWuBGksdZTPAjkMRyPkxp61CJPsntA) |\n";
  markdown +=
    "| NTT Transceiver | [`5FksLs44iw5TPZ1yngyxKxZyvBXeUCgQM7VQfiRZVK45`](https://explorer.solana.com/address/5FksLs44iw5TPZ1yngyxKxZyvBXeUCgQM7VQfiRZVK45) |\n\n";

  // Move explanatory content to the end
  markdown += "---\n\n";
  markdown += "## 🔄 How to Update This Documentation\n\n";
  markdown += "After any deployment changes, run:\n";
  markdown += "```bash\n";
  markdown += "pnpm run sync:deployments\n";
  markdown += "```\n\n";
  markdown += "This command will:\n";
  markdown += "1. **Enhance** - Scan blockchain for proxy configurations and update JSON files\n";
  markdown += "2. **Generate** - Auto-generate this documentation from enhanced JSON files\n";
  markdown += "3. **Verify** - Cross-check all addresses and proxy configurations\n\n";
  markdown += "💡 **Source of Truth**: `evm/deployments/{chainId}.json` files contain all deployment data.\n\n";

  markdown += "## 📝 Notes\n\n";
  markdown += "- All addresses are verified on their respective block explorers\n";
  markdown +=
    "- **NTT contracts** = [Wormhole Native Token Transfers](https://docs.wormhole.com/wormhole/native-token-transfers/overview) for cross-chain bridging\n";
  markdown += "- Click any address to view it on the blockchain explorer\n";
  markdown += "- The WCT token has a total supply of 1,000,000,000 tokens (1e27 in wei)\n";

  return markdown;
}

async function enhanceWithProxyData(): Promise<void> {
  console.log("🔍 Enhancing deployment data with proxy information...");

  // This would call our existing discovery scripts to get proxy admin/owner info
  // and update the JSON files with this information for future runs

  // For now, we'll just log that this step exists
  console.log("💡 Future enhancement: Auto-discover and store proxy admin/owner addresses");
}

async function main() {
  console.log("📚 Generating deployment documentation...\n");

  try {
    // Step 1: Enhance deployment data with proxy information
    await enhanceWithProxyData();

    // Step 2: Generate markdown documentation
    const markdown = await generateMarkdown();

    // Step 3: Write to file
    const outputPath = "DEPLOYMENT_ADDRESSES.md";
    fs.writeFileSync(outputPath, markdown);

    console.log(`✅ Documentation generated successfully!`);
    console.log(`📄 Output: ${outputPath}`);
    console.log(`\n💡 To keep this up to date:`);
    console.log(`   1. Run deployment scripts (make json-mainnet, make json-optimism)`);
    console.log(`   2. Run this generator: pnpm run generate:docs`);
  } catch (error) {
    console.error("❌ Error generating documentation:", error);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

export { generateMarkdown, loadDeploymentData };
