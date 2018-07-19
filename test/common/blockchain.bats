#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../bats-mock/stub.bash"
load ../test_helper

setup() {
    src_dir="${BATS_TEST_DIRNAME}/../../src"
    testcase_dirname="$(mktemp -d)"

    setup_script_dir "${src_dir}" "${testcase_dirname}"
	source "${SCRIPT_DIR}/common/blockain.sh"
}

@test "blockchain.sh: authenticate_org should grab the specified org's information" {
	pushd "${SCRIPT_DIR}"
  
  "org1": {
    "key": "key1",
    "secret": "secret1",
    "url": "url1",
    "network_id": "networkid1"
  },
  "org2": {
    "key": "key2",
    "secret": "secret2",
    "url": "url2",
    "network_id": "networkid2"
  }
}
EOF

	run authenticate_org "org1"

	rm blockchain.json
	popd

	echo $BLOCKCHAIN_NETWORK_ID
}
