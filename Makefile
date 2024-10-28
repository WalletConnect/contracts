# Makefile for deploying contracts

# Common variables
FORGE_CMD = forge script
VERBOSITY = -vvvv

# Deploy scripts
ETHEREUM_DEPLOY = script/deploy/EthereumDeploy.s.sol:EthereumDeploy
OPTIMISM_DEPLOY = script/deploy/OptimismDeploy.s.sol:OptimismDeploy
ANVIL_DEPLOY = script/deploy/AnvilDeploy.s.sol:AnvilDeploy

# Default RPC URL for Anvil
DEFAULT_ANVIL_RPC = http://localhost:8545

# Broadcasting configuration
ifdef BROADCAST
    # Export variables for sub-makes
    export BROADCAST_FLAGS = --broadcast
    export NETWORK_TYPE = $(findstring optimism,$(MAKECMDGOALS))

    ifeq ($(NETWORK_TYPE),optimism)
        export API_KEY_ETHERSCAN = ${API_KEY_OPTIMISTIC_ETHERSCAN}
    endif

    ifeq ($(IS_ANVIL),)
        BROADCAST_FLAGS += --verify --etherscan-api-key ${API_KEY_ETHERSCAN}
    endif

    define broadcast_info
        @if [ "$(findstring optimism,$@)" != "" ]; then \
            echo "Using Optimistic Etherscan API key"; \
        else \
            echo "Using Ethereum Etherscan API key"; \
        fi
    endef
else
    export BROADCAST_FLAGS =
    define broadcast_info
        @echo "Not broadcasting - dry run only"
    endef
endif


# Network-specific targets
.PHONY: deploy-mainnet deploy-sepolia deploy-optimism deploy-optimism-sepolia deploy-anvil log-mainnet log-sepolia log-optimism log-optimism-sepolia log-anvil fund-deployer

deploy-mainnet:
	$(broadcast_info)
	@echo "Deploying to Ethereum Mainnet"
	@$(MAKE) _deploy ENV_FILE=.mainnet.env SCRIPT=$(ETHEREUM_DEPLOY) LEDGER=true

deploy-sepolia:
	$(broadcast_info)
	@echo "Deploying to Sepolia testnet"
	@$(MAKE) _deploy ENV_FILE=.sepolia.env SCRIPT=$(ETHEREUM_DEPLOY)

deploy-optimism:
	$(broadcast_info)
	@echo "Deploying to Optimism Mainnet"
	@$(MAKE) _deploy ENV_FILE=.optimism.env SCRIPT=$(OPTIMISM_DEPLOY) LEDGER=true

deploy-optimism-sepolia:
	$(broadcast_info)
	@echo "Deploying to Optimism Sepolia testnet"
	@$(MAKE) _deploy ENV_FILE=.optimism-sepolia.env SCRIPT=$(OPTIMISM_DEPLOY)

deploy-anvil:
	$(broadcast_info)
	@echo "Deploying to Anvil local network"
	@$(MAKE) _deploy ENV_FILE=.anvil.env SCRIPT=$(ANVIL_DEPLOY) IS_ANVIL=true

log-mainnet:
	@echo "Logging deployments for Ethereum Mainnet"
	@$(MAKE) _log_deployments ENV_FILE=.mainnet.env SCRIPT=$(ETHEREUM_DEPLOY)

log-sepolia:
	@echo "Logging deployments for Sepolia testnet"
	@$(MAKE) _log_deployments ENV_FILE=.sepolia.env SCRIPT=$(ETHEREUM_DEPLOY)

log-optimism:
	@echo "Logging deployments for Optimism Mainnet"
	@$(MAKE) _log_deployments ENV_FILE=.optimism.env SCRIPT=$(OPTIMISM_DEPLOY)

log-optimism-sepolia:
	@echo "Logging deployments for Optimism Sepolia testnet"
	@$(MAKE) _log_deployments ENV_FILE=.optimism-sepolia.env SCRIPT=$(OPTIMISM_DEPLOY)

log-anvil:
	@echo "Logging deployments for Anvil local network"
	@$(MAKE) _log_deployments ENV_FILE=.anvil.env SCRIPT=$(ANVIL_DEPLOY) IS_ANVIL=true

fund-deployer:
	@echo "Funding deployer account on Anvil"
	$(eval include .anvil.env)
	@cast rpc anvil_setBalance $(ETH_FROM) $(shell cast --to-wei 10)

# Internal deploy function
_deploy:
	$(eval include .common.env)
	$(eval include $(ENV_FILE))

ifeq ($(IS_ANVIL),)
	$(eval RPC_URL = https://${CHAIN_NAME}.infura.io/v3/${API_KEY_INFURA})
else
	$(eval RPC_URL = $(DEFAULT_ANVIL_RPC))
endif

	@if [ "$(LEDGER)" = "true" ]; then \
		$(FORGE_CMD) $(SCRIPT) \
			$(VERBOSITY) \
			--rpc-url $(RPC_URL) \
			--sender ${ETH_FROM} \
			--mnemonic-indexes ${MNEMONIC_INDEX} \
			--ledger \
			--force \
			$(BROADCAST_FLAGS); \
	else \
		$(FORGE_CMD) $(SCRIPT) \
			$(VERBOSITY) \
			--rpc-url $(RPC_URL) \
			--sender ${ETH_FROM} \
			--account ${KEYSTORE_ACCOUNT} \
			--force \
			$(BROADCAST_FLAGS); \
	fi

# New function for logging deployments
_log_deployments:
	$(eval include .common.env)
	$(eval include $(ENV_FILE))

ifeq ($(IS_ANVIL),)
	$(eval RPC_URL = https://${CHAIN_NAME}.infura.io/v3/${API_KEY_INFURA})
else
	$(eval RPC_URL = $(DEFAULT_ANVIL_RPC))
endif

	$(FORGE_CMD) $(SCRIPT) \
		$(VERBOSITY) \
		-s "logDeployments()" \
		--rpc-url $(RPC_URL) \
		--sender ${ETH_FROM}

# Help target
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  deploy-anvil              - Deploy to Anvil local network"
	@echo "  deploy-mainnet            - Deploy to Ethereum Mainnet"
	@echo "  deploy-sepolia            - Deploy to Sepolia testnet"
	@echo "  deploy-optimism           - Deploy to Optimism Mainnet"
	@echo "  deploy-optimism-sepolia   - Deploy to Optimism Sepolia testnet"
	@echo "  log-mainnet               - Log deployments for Ethereum Mainnet"
	@echo "  log-sepolia               - Log deployments for Sepolia testnet"
	@echo "  log-optimism              - Log deployments for Optimism Mainnet"
	@echo "  log-optimism-sepolia      - Log deployments for Optimism Sepolia testnet"
	@echo "  log-anvil                 - Log deployments for Anvil local network"
	@echo "  fund-deployer             - Fund deployer account on Anvil"
	@echo "  help                      - Show this help message"
	@echo ""
	@echo "Flags:"
	@echo "  BROADCAST=true            - When used, enables contract verification and broadcasting"
	@echo "                              (e.g., BROADCAST=true make deploy-mainnet)"
