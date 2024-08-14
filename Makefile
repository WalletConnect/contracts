# Makefile for deploying contracts

# Common Forge command
FORGE_CMD = forge script

# Deploy scripts
ETHEREUM_DEPLOY = script/deploy/EthereumDeploy.s.sol:EthereumDeploy
OPTIMISM_DEPLOY = script/deploy/OptimismDeploy.s.sol:OptimismDeploy

# Set BROADCAST_FLAGS based on the BROADCAST variable
ifdef BROADCAST
    BROADCAST_FLAGS = --verify --etherscan-api-key ${API_KEY_ETHERSCAN} --broadcast
else
    BROADCAST_FLAGS =
endif

# Network-specific targets
.PHONY: deploy-mainnet deploy-sepolia deploy-optimism deploy-optimism-sepolia

deploy-mainnet:
	@echo "Deploying to Ethereum Mainnet"
	@$(MAKE) _deploy ENV_FILE=.mainnet.env SCRIPT=$(ETHEREUM_DEPLOY)

deploy-sepolia:
	@echo "Deploying to Sepolia testnet"
	@$(MAKE) _deploy ENV_FILE=.sepolia.env SCRIPT=$(ETHEREUM_DEPLOY)

deploy-optimism:
	@echo "Deploying to Optimism Mainnet"
	@$(MAKE) _deploy ENV_FILE=.optimism.env SCRIPT=$(OPTIMISM_DEPLOY)

deploy-optimism-sepolia:
	@echo "Deploying to Optimism Sepolia testnet"
	@$(MAKE) _deploy ENV_FILE=.optimism-sepolia.env SCRIPT=$(OPTIMISM_DEPLOY)

# Internal deploy function
_deploy:
	$(eval include .common.env)
	$(eval include $(ENV_FILE))
	$(FORGE_CMD) $(SCRIPT) \
		-vvvv \
		--rpc-url https://${CHAIN_NAME}.infura.io/v3/${API_KEY_INFURA} \
		--sender ${ETH_FROM} \
		--account ${KEYSTORE_ACCOUNT} \
		--force \
		$(BROADCAST_FLAGS)

# Help target
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  deploy-mainnet            - Deploy to Ethereum Mainnet"
	@echo "  deploy-sepolia            - Deploy to Sepolia testnet"
	@echo "  deploy-optimism           - Deploy to Optimism Mainnet"
	@echo "  deploy-optimism-sepolia   - Deploy to Optimism Sepolia testnet"
	@echo "  help                      - Show this help message"
	@echo ""
	@echo "Flags:"
	@echo "  BROADCAST=true            - When used, enables contract verification and broadcasting"
	@echo "                              (e.g., BROADCAST=true make deploy-mainnet)"
