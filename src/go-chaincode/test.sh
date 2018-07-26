#!/usr/bin/env bash

echo "######## Test chaincode ########"

# shellcheck source=src/common/env.sh
source "${SCRIPT_DIR}/common/env.sh"

$DEBUG && set -x

go get -u github.com/jstemmer/go-junit-report

go test -v chaincode 2>&1 | go-junit-report > report.xml