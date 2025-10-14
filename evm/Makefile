# Makefile for deploying contracts

# Common variables
FORGE_CMD = forge script
VERBOSITY = -vvvv

# Deploy scripts
ETHEREUM_DEPLOY = script/deploy/EthereumDeploy.s.sol:EthereumDeploy
OPTIMISM_DEPLOY = script/deploy/OptimismDeploy.s.sol:OptimismDeploy
ANVIL_DEPLOY = script/deploy/AnvilDeploy.s.sol:AnvilDeploy
P3_UPGRADE = script/deploy/P3Upgrade.s.sol:P3Upgrade

# Default RPC URL for Anvil
DEFAULT_ANVIL_RPC = http://localhost:8545

# Set BROADCAST_FLAGS based on the BROADCAST variable
ifdef BROADCAST
    BROADCAST_FLAGS = --broadcast
else
    BROADCAST_FLAGS =
endif

# Network-specific targets
.PHONY: deploy-mainnet deploy-sepolia deploy-optimism deploy-optimism-sepolia deploy-anvil log-mainnet log-sepolia log-optimism log-optimism-sepolia log-anvil fund-deployer json-mainnet json-sepolia json-optimism json-optimism-sepolia json-anvil p3-upgrade-optimism p3-calldata-optimism

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

# P3 Upgrade targets
p3-upgrade-optimism:
	$(broadcast_info)
	@echo "Deploying P3 Upgrade to Optimism Mainnet"
	@$(MAKE) _p3_deploy ENV_FILE=.optimism.env SCRIPT=$(P3_UPGRADE) LEDGER=true

p3-calldata-optimism:
	@echo "Generating P3 Upgrade timelock calldata for Optimism Mainnet"
	@$(MAKE) _p3_calldata ENV_FILE=.optimism.env CHAIN_ID=10

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

json-mainnet:
	@echo "Generating JSON deployments for Ethereum Mainnet"
	@$(MAKE) _json_deployments ENV_FILE=.mainnet.env SCRIPT=$(ETHEREUM_DEPLOY) CHAIN_ID=1 IS_ANVIL=

json-sepolia:
	@echo "Generating JSON deployments for Sepolia testnet"
	@$(MAKE) _json_deployments ENV_FILE=.sepolia.env SCRIPT=$(ETHEREUM_DEPLOY) CHAIN_ID=11155111 IS_ANVIL=

json-optimism:
	@echo "Generating JSON deployments for Optimism Mainnet"
	@$(MAKE) _json_deployments ENV_FILE=.optimism.env SCRIPT=$(OPTIMISM_DEPLOY) CHAIN_ID=10 IS_ANVIL=

json-optimism-sepolia:
	@echo "Generating JSON deployments for Optimism Sepolia testnet"
	@$(MAKE) _json_deployments ENV_FILE=.optimism-sepolia.env SCRIPT=$(OPTIMISM_DEPLOY) CHAIN_ID=11155420 IS_ANVIL=

json-anvil:
	@echo "Generating JSON deployments for Anvil local network"
	@$(MAKE) _json_deployments ENV_FILE=.anvil.env SCRIPT=$(ANVIL_DEPLOY) CHAIN_ID=31337 IS_ANVIL=true

fund-deployer:
	@echo "Funding deployer account on Anvil"
	$(eval include .anvil.env)
	@cast rpc anvil_setBalance $(ETH_FROM) $(shell cast --to-wei 10)
	@cast rpc anvil_setBalance $(TREASURY_ADDRESS) $(shell cast --to-wei 10)

# Internal deploy function
_deploy:
	$(eval include .common.env)
	$(eval include $(ENV_FILE))
	$(eval ETHSCAN_KEY = $(if $(findstring optimism,$(ENV_FILE)),${API_KEY_OPTIMISTIC_ETHERSCAN},${API_KEY_ETHERSCAN}))

ifeq ($(IS_ANVIL),)
	$(eval RPC_URL = https://${CHAIN_NAME}.infura.io/v3/${API_KEY_INFURA})
	$(eval BROADCAST_FLAGS += --verify --etherscan-api-key ${ETHSCAN_KEY})
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
			$(BROADCAST_FLAGS); \
	else \
		$(FORGE_CMD) $(SCRIPT) \
			$(VERBOSITY) \
			--rpc-url $(RPC_URL) \
			--sender ${ETH_FROM} \
			--account ${KEYSTORE_ACCOUNT} \
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

# New function for generating JSON deployments
_json_deployments:
	$(eval include .common.env)
	$(eval include $(ENV_FILE))

ifeq ($(IS_ANVIL),)
	$(eval RPC_URL = https://${CHAIN_NAME}.infura.io/v3/${API_KEY_INFURA})
else
	$(eval RPC_URL = $(DEFAULT_ANVIL_RPC))
endif

	@mkdir -p logs
	@WRITE_JSON=true $(FORGE_CMD) $(SCRIPT) \
		$(VERBOSITY) \
		-s "logDeployments()" \
		--rpc-url $(RPC_URL) \
		--sender ${ETH_FROM}
	@echo "JSON deployment file generated at deployments/$(CHAIN_ID).json"

# Internal P3 deploy function (with --force for OpenZeppelin plugin)
_p3_deploy:
	$(eval include .common.env)
	$(eval include $(ENV_FILE))
	$(eval ETHSCAN_KEY = $(if $(findstring optimism,$(ENV_FILE)),${API_KEY_OPTIMISTIC_ETHERSCAN},${API_KEY_ETHERSCAN}))

ifeq ($(IS_ANVIL),)
	$(eval RPC_URL = https://${CHAIN_NAME}.infura.io/v3/${API_KEY_INFURA})
	$(eval BROADCAST_FLAGS += --verify --etherscan-api-key ${ETHSCAN_KEY})
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

# Generate P3 upgrade timelock calldata
_p3_calldata:
	$(eval include .common.env)
	$(eval include $(ENV_FILE))
	$(eval RPC_URL = https://${CHAIN_NAME}.infura.io/v3/${API_KEY_INFURA})
	$(eval DEPLOYMENT_JSON = deployments/$(CHAIN_ID)-p3-upgrade.json)
	@if [ ! -f "$(DEPLOYMENT_JSON)" ]; then \
		echo "Error: $(DEPLOYMENT_JSON) not found. Run p3-upgrade-optimism* first."; \
		exit 1; \
	fi
	$(eval PAUSER_IMPL = $(shell cat $(DEPLOYMENT_JSON) | jq -r '.NewImplementations.Pauser'))
	$(eval STAKEWEIGHT_IMPL = $(shell cat $(DEPLOYMENT_JSON) | jq -r '.NewImplementations.StakeWeight'))
	$(eval SRD_IMPL = $(shell cat $(DEPLOYMENT_JSON) | jq -r '.NewImplementations.StakingRewardDistributor'))
	@echo "Loading implementation addresses from $(DEPLOYMENT_JSON):"
	@echo "  Pauser:                    $(PAUSER_IMPL)"
	@echo "  StakeWeight:               $(STAKEWEIGHT_IMPL)"
	@echo "  StakingRewardDistributor:  $(SRD_IMPL)"
	@echo ""
	$(FORGE_CMD) $(P3_UPGRADE) \
		$(VERBOSITY) \
		-s "logTimelockCalldata(address,address,address)" \
		$(PAUSER_IMPL) $(STAKEWEIGHT_IMPL) $(SRD_IMPL) \
		--rpc-url $(RPC_URL)

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
	@echo "  json-mainnet              - Generate JSON deployments for Ethereum Mainnet"
	@echo "  json-sepolia              - Generate JSON deployments for Sepolia testnet"
	@echo "  json-optimism             - Generate JSON deployments for Optimism Mainnet"
	@echo "  json-optimism-sepolia     - Generate JSON deployments for Optimism Sepolia testnet"
	@echo "  json-anvil                - Generate JSON deployments for Anvil local network"
	@echo "  fund-anvil                - Fund admin/treasury account on Anvil"
	@echo ""
	@echo "P3 Upgrade targets:"
	@echo "  p3-upgrade-optimism       - Deploy P3 upgrade to Optimism Mainnet"
	@echo "  p3-calldata-optimism      - Generate timelock calldata for Optimism Mainnet"
	@echo ""
	@echo "  help                      - Show this help message"
	@echo ""
	@echo "Flags:"
	@echo "  BROADCAST=true            - When used, enables contract verification and broadcasting"
	@echo "                              (e.g., BROADCAST=true make deploy-mainnet)"
