#!/usr/bin/env bash

# Common IBM blockchain platform functions, e.g. to provision a blockchain service

source "${SCRIPT_DIR}/common/utils.sh"

function setup_service_constants {
    region_instance=$(echo $REGION_ID | cut -d : -f 2)
    if [ "${region_instance}" = "ys1" ]; then
        export BLOCKCHAIN_SERVICE_NAME=ibm-blockchain-5-staging
        export BLOCKCHAIN_SERVICE_PLAN=ibm-blockchain-plan-v1-ga1-starter-staging
    else
        export BLOCKCHAIN_SERVICE_NAME=ibm-blockchain-5-prod
        export BLOCKCHAIN_SERVICE_PLAN=ibm-blockchain-plan-v1-ga1-starter-prod
    fi

    export BLOCKCHAIN_SERVICE_KEY=Credentials-1
}

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

function install_fabric_chaincode {
    CC_ID=$1
    CC_VERSION=$2
    CC_FILE=$3

    request_url="${BLOCKCHAIN_URL}/api/v1/networks/${BLOCKCHAIN_NETWORK_ID}/chaincode/install"

    OUTPUT=$(do_curl \
        -X POST \
        -u ${BLOCKCHAIN_KEY}:${BLOCKCHAIN_SECRET} \
        -F files[]=@${CC_FILE} -F chaincode_id=${CC_ID} -F chaincode_version=${CC_VERSION} \
        ${request_url})
    if ! ${OUTPUT}
    then
        if [[ "${OUTPUT}" != *"chaincode code"*"exists"* ]]
        then
            echo failed to install fabric contract
            exit 1
        fi
    fi
}

function instantiate_fabric_chaincode {
    CC_ID=$1
    CC_VERSION=$2
    CHANNEL=$3
    INIT_ARGS=$4

    cat << EOF > request.json
{
    "chaincode_id": "${CC_ID}",
    "chaincode_version": "${CC_VERSION}",
    "chaincode_arguments": "[${INIT_ARGS}]"
}
EOF

    request_url="${BLOCKCHAIN_URL}/api/v1/networks/${BLOCKCHAIN_NETWORK_ID}/channels/${CHANNEL}/chaincode/instantiate"

    OUTPUT=$(do_curl \
        -X POST \
        -H 'Content-Type: application/json' \
        -u ${BLOCKCHAIN_KEY}:${BLOCKCHAIN_SECRET} \
        --data-binary @request.json \
        ${request_url})

    while ! ${OUTPUT}
    do
        if [[ "${OUTPUT}" = *"Failed to establish a backside connection"* ]]
        then
            sleep 30
        elif [[ "${OUTPUT}" = *"premature execution"* ]]
        then
            sleep 30
        elif [[ "${OUTPUT}" = *"version already exists for chaincode"* ]]
        then
            break
        else
            echo failed to start fabric contract
            exit 1
        fi
    done
    rm -f request.json
}


function parse_fabric_config {
    NET_CONFIG_FILE=$1

    for org in $(jq -r "to_entries[] | .key" $NET_CONFIG_FILE)
    do
        authenticate_org $org

        cc_index=0
        jq -r ".${org}.chaincode[].path" $NET_CONFIG_FILE | while read CC_PATH
        do
            CC_NAME=$(jq -r ".${org}.chaincode[$index].name" $NET_CONFIG_FILE)
            CC_FILE="${CC_PATH}/${CC_NAME}.go"
            CC_INSTALL=$(jq -r ".${org}.chaincode[$index].install" $NET_CONFIG_FILE)
            CC_INSTANTIATE=$(jq -r ".${org}.chaincode[$index].instantiate" $NET_CONFIG_FILE)
            CC_CHANNELS=$(jq -r ".${org}.chaincode[$index].channels[]" $NET_CONFIG_FILE)
            CC_INIT_ARGS=$(jq ".${org}.chaincode[$index].init_args[]" $NET_CONFIG_FILE)

            # TODO: Integrate with configuration
            CC_ID="id_placeholder"
            CC_VERSION=$(date +%Y%m%d)-${BUILD_NUMBER}

            if [ $CC_INSTALL ]
            then
                install_fabric_chaincode $CC_ID $CC_VERSION $CC_FILE
            fi

            if [ $CC_INSTANTIATE ]
            then
                for channel in $CC_CHANNELS
                do
                    echo CHANNEL: $channel
                    instantiate_fabric_chaincode $CC_ID $CC_VERSION $channel $CC_INIT_ARGS
                done  
            fi
            cc_index=$((cc_index + 1))
        done
    done
}
