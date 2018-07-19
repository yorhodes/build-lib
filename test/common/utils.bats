#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../bats-mock/stub.bash"
load ../test_helper

setup() {
  src_dir="${BATS_TEST_DIRNAME}/../../src"
  testcase_dirname="$(mktemp -d)"

  setup_script_dir "${src_dir}" "${testcase_dirname}"

  source "${SCRIPT_DIR}/common/utils.sh"
}

@test "utils.sh: should exist and be executable" {
  [ -x "${SCRIPT_DIR}/common/utils.sh" ]
}

@test "utils.sh: should return proper values in do_curl" {
  stub cat \
      "true" \
      "true" \
      "true"
  stub curl \
      "echo 100" \
      "echo 250" \
      "echo 300"

  run do_curl
  [ $status -eq 1 ]

  run do_curl
  [ $status -eq 0 ]

  run do_curl
  [ $status -eq 1 ]

  unstub cat
  unstub curl
}
