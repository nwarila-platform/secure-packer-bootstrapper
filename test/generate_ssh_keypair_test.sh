#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=./testlib.sh
. "$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/testlib.sh"
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
if [[ $(uname -s) == Linux* ]]; then
  assert_file_mode "${private_key}" 600
  assert_file_mode "${public_key}" 644
fi

run_capture generate_ssh_keypair --output-dir "${temp_dir}" --name id_test --passphrase 'Sup3r!Secret'
assert_status 2
assert_stderr_contains 'already exist'

run_capture generate_ssh_keypair --output-dir "${temp_dir}" --name id_test --passphrase 'Sup3r!Secret' --force
assert_status 0

run_capture generate_ssh_keypair --output-dir "${temp_dir}" --name invalid_type --passphrase 'Sup3r!Secret' --type ed25519
assert_status 2
assert_stderr_contains "--type must be either 'rsa' or 'ecdsa'"

run_capture generate_ssh_keypair --output-dir "${temp_dir}" --name invalid_bits --passphrase 'Sup3r!Secret' --type ecdsa --bits 123
assert_status 2
assert_stderr_contains 'ECDSA --bits must be 256, 384, or 521'

GENERATE_SSH_KEYPAIR_SSH_KEYGEN_BIN='definitely-missing-ssh-keygen-bin' run_capture generate_ssh_keypair --output-dir "${temp_dir}" --name missing_bin --passphrase 'Sup3r!Secret'
assert_status 127
assert_stderr_contains 'requires definitely-missing-ssh-keygen-bin'

fake_ssh_keygen=${temp_dir}/fake-ssh-keygen.sh
printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "${fake_ssh_keygen}"
chmod 700 "${fake_ssh_keygen}"
GENERATE_SSH_KEYPAIR_SSH_KEYGEN_BIN="${fake_ssh_keygen}" run_capture generate_ssh_keypair --output-dir "${temp_dir}" --name failing_keygen --passphrase 'Sup3r!Secret'
assert_status 1
assert_stderr_contains 'ssh-keygen failed'
assert_not_exists "${temp_dir}/failing_keygen.tmp.$$"
assert_not_exists "${temp_dir}/failing_keygen.tmp.$$.pub"

printf 'PASS: generate_ssh_keypair_test\n'
