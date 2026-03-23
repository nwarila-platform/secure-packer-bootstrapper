#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=./testlib.sh
. "$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/testlib.sh"
# shellcheck source=../src/generate_password_hash/generate_password_hash.sh
. "${TEST_ROOT}/src/generate_password_hash/generate_password_hash.sh"

command -v openssl >/dev/null 2>&1 || skip_test 'openssl is required for generate_password_hash_test'

run_capture generate_password_hash --password 'Sup3r!Secret'
assert_status 0
assert_stdout_contains '$6$'

run_capture generate_password_hash --password 'Sup3r!Secret' --salt-length 4
assert_status 2
assert_stderr_contains '--salt-length'

printf 'PASS: generate_password_hash_test\n'
