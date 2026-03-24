#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=./testlib.sh
. "$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/testlib.sh"
# shellcheck source=../src/generate_password_hash/generate_password_hash.sh
. "${TEST_ROOT}/src/generate_password_hash/generate_password_hash.sh"

command -v openssl >/dev/null 2>&1 || skip_test 'openssl is required for generate_password_hash_test'

run_capture generate_password_hash --password 'Sup3r!Secret'
assert_status 0
assert_stdout_contains '$6$rounds=10000$'

run_capture bash -lc "set -euo pipefail; . '${TEST_ROOT}/src/generate_password_hash/generate_password_hash.sh'; printf '%s\n' 'Sup3r!Secret' | generate_password_hash"
assert_status 0
assert_stdout_contains '$6$rounds=10000$'

run_capture generate_password_hash --password 'Sup3r!Secret' --salt-length 4
assert_status 2
assert_stderr_contains '--salt-length'

failing_openssl=${TEST_ROOT}/test/.fake-openssl.sh
printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "${failing_openssl}"
chmod 700 "${failing_openssl}"
trap 'rm -f "${failing_openssl}"' EXIT

GENERATE_PASSWORD_HASH_OPENSSL_BIN="${failing_openssl}" run_capture generate_password_hash --password 'Sup3r!Secret'
assert_status 1
assert_stderr_contains 'openssl passwd failed'

GENERATE_PASSWORD_HASH_OPENSSL_BIN='definitely-missing-openssl-bin' run_capture generate_password_hash --password 'Sup3r!Secret'
assert_status 127
assert_stderr_contains 'requires definitely-missing-openssl-bin'

printf 'PASS: generate_password_hash_test\n'
