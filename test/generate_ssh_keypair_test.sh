#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=./testlib.sh
. "$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/testlib.sh"
# shellcheck source=../src/generate_ssh_keypair/generate_ssh_keypair.sh
. "${TEST_ROOT}/src/generate_ssh_keypair/generate_ssh_keypair.sh"

command -v ssh-keygen >/dev/null 2>&1 || skip_test 'ssh-keygen is required for generate_ssh_keypair_test'

temp_dir=$(make_temp_dir)
trap 'rm -rf "${temp_dir}"' EXIT

run_capture generate_ssh_keypair --output-dir "${temp_dir}" --name id_test --passphrase 'Sup3r!Secret'
assert_status 0

private_key=$(printf '%s\n' "${RUN_STDOUT}" | sed -n '1p')
public_key=$(printf '%s\n' "${RUN_STDOUT}" | sed -n '2p')
assert_file_exists "${private_key}"
assert_file_exists "${public_key}"

run_capture generate_ssh_keypair --output-dir "${temp_dir}" --name id_test --passphrase 'Sup3r!Secret'
assert_status 2
assert_stderr_contains 'already exist'

printf 'PASS: generate_ssh_keypair_test\n'
