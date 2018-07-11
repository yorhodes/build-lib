#!/usr/bin/env bash

# Common utility functions, e.g. to make curl requests

function install_jq {
    curl -o jq -L https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
    chmod +x jq
    export PATH=${PATH}:${PWD}
}

function do_curl {
    HTTP_RESPONSE=$(mktemp)
    HTTP_STATUS=$(curl -w '%{http_code}' -o ${HTTP_RESPONSE} "$@")
    cat ${HTTP_RESPONSE}
    rm -f ${HTTP_RESPONSE}
    if [[ ${HTTP_STATUS} -ge 200 && ${HTTP_STATUS} -lt 300 ]]
    then
        return 0
    else
        return ${HTTP_STATUS}
    fi
}
