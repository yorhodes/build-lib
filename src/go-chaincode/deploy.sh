#!/usr/bin/env bash

# Go chaincode specific deploy script

source "${SCRIPT_DIR}/common/env.sh"
source "${SCRIPT_DIR}/common/utils.sh"
source "${SCRIPT_DIR}/common/blockchain.sh"

if [[ ! -f $CONFIG_PATH ]]; then
  echo "No deploy configuration at specified path: ${CONFIG_PATH}"
  exit 1
fi

install_jq
setup_service_constants
provision_blockchain
parse_fabric_config $CONFIG_PATH
