#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../bats-mock/stub.bash"
load ../test_helper

setup() {
    src_dir="${BATS_TEST_DIRNAME}/../../src"
    testcase_dirname="$(mktemp -d)"

    setup_script_dir "${src_dir}" "${testcase_dirname}"
}

@test "deploy.sh: should exist and be executable" {
    [ -x "${SCRIPT_DIR}/go-chaincode/deploy.sh" ]
}

@test "deploy.sh: should fail if deploy configuration does not exist" {
    export CONFIG_PATH="fakepath"

    run "${SCRIPT_DIR}/go-chaincode/deploy.sh"
    [ "$output" = "No deploy configuration at specified path: fakepath" ]
    [ $status -eq 1 ]
}

@test "deploy.sh: should succeed if deploy configuration exists" {
    export CONFIG_PATH=$(mktemp)
    
    stub install_jq "true"
    stub setup_service_constants "true"
    stub provision_blockchain "true"
    stub parse_fabric_config "true"

    run "${SCRIPT_DIR}/go-chaincode/deploy.sh"
    [ $status -eq 0 ]

    unstub install_jq
    unstub setup_service_constants
    unstub provision_blockchain
    unstub parse_fabric_config
}
