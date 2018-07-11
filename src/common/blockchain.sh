#!/usr/bin/env bash

# Common IBM blockchain platform functions, e.g. to provision a blockchain service

set -ex

source "${SCRIPT_DIR}/common/utils.sh"

region_instance=$(echo $REGION_ID | cut -d : -f 2)
if [ "${region_instance}" = "ys1" ]; then
    export BLOCKCHAIN_SERVICE_NAME=ibm-blockchain-5-staging
    export BLOCKCHAIN_SERVICE_PLAN=ibm-blockchain-plan-v1-ga1-starter-staging
else
    export BLOCKCHAIN_SERVICE_NAME=ibm-blockchain-5-prod
    export BLOCKCHAIN_SERVICE_PLAN=ibm-blockchain-plan-v1-ga1-starter-prod
fi

export BLOCKCHAIN_SERVICE_KEY=Credentials-1
export BLOCKCHAIN_NETWORK_CARD=admin@blockchain-network

function authenticate_org {
    org=$1

    # TODO: Debug JQ with underscore keys
    #BLOCKCHAIN_NETWORK_ID=$(jq --raw-output "${org}[\"network_id\"]" blockchain.json)
    BLOCKCHAIN_NETWORK_ID="n117bbfce3f624d549568b99fbbb62d74"
    BLOCKCHAIN_KEY=$(jq --raw-output ".${org}.key" blockchain.json)
    BLOCKCHAIN_SECRET=$(jq --raw-output ".${org}.secret" blockchain.json)
    BLOCKCHAIN_URL=$(jq --raw-output ".${org}.url" blockchain.json)
}

function provision_blockchain {
    if ! cf service ${BLOCKCHAIN_SERVICE_INSTANCE} > /dev/null 2>&1
    then
        cf create-service ${BLOCKCHAIN_SERVICE_NAME} ${BLOCKCHAIN_SERVICE_PLAN} ${BLOCKCHAIN_SERVICE_INSTANCE}
    fi
    if ! cf service-key ${BLOCKCHAIN_SERVICE_INSTANCE} ${BLOCKCHAIN_SERVICE_KEY} > /dev/null 2>&1
    then
        cf create-service-key ${BLOCKCHAIN_SERVICE_INSTANCE} ${BLOCKCHAIN_SERVICE_KEY}
    fi
    cf service-key ${BLOCKCHAIN_SERVICE_INSTANCE} ${BLOCKCHAIN_SERVICE_KEY} | tail -n +2 > blockchain.json
    
    # TODO: Integrate with configuration
    authenticate_org "org1"
}

function get_blockchain_connection_profile_inner {
    do_curl \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json' \
        -u ${BLOCKCHAIN_KEY}:${BLOCKCHAIN_SECRET} \
        ${BLOCKCHAIN_URL}/api/v1/networks/${BLOCKCHAIN_NETWORK_ID}/connection_profile > blockchain-connection-profile.json
}

function get_blockchain_connection_profile {
    get_blockchain_connection_profile_inner
    while ! jq -e ".channels.defaultchannel" blockchain-connection-profile.json
    do
        sleep 10
        get_blockchain_connection_profile_inner
    done
}
