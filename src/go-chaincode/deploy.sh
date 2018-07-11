#!/usr/bin/env bash

# Go chaincode specific deploy script

set -ex

source "${SCRIPT_DIR}/common/env.sh"
source "${SCRIPT_DIR}/common/utils.sh"
source "${SCRIPT_DIR}/common/blockchain.sh"

function parse_config {
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

            CC_ID="id_placeholder"
            CC_VERSION="version_placeholder"

            if [ $CC_INSTALL ]
            then
                install_fabric_chaincode $CC_ID $CC_VERSION $CC_FILE
            fi

            if [ $CC_INSTANTIATE ]
            then
                for channel in $CC_CHANNELS
                do
                    instantiate_fabric_chaincode $CC_ID $CC_VERSION $channel $CC_INIT_ARGS
                done  
            fi
            cc_index=$((cc_index + 1))
        done
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
    if ! OUTPUT
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

    while ! OUTPUT
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

install_jq
provision_blockchain
parse_config ${CONFIG_PATH}
