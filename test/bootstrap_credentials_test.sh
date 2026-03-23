#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=./testlib.sh
. "$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/testlib.sh"
# shellcheck source=../src/bootstrap_credentials/bootstrap_credentials.sh
. "${TEST_ROOT}/src/bootstrap_credentials/bootstrap_credentials.sh"

command -v openssl >/dev/null 2>&1 || skip_test 'openssl is required for bootstrap_credentials_test'
command -v ssh-keygen >/dev/null 2>&1 || skip_test 'ssh-keygen is required for bootstrap_credentials_test'

temp_dir=$(make_temp_dir)
trap 'rm -rf "${temp_dir}"' EXIT

run_capture bootstrap_credentials --output-dir "${temp_dir}/artifacts" --skip-agent
assert_status 0
manifest_path=${RUN_STDOUT}
assert_file_exists "${manifest_path}"
assert_file_exists "${temp_dir}/artifacts/bootstrap.env"
assert_file_exists "${temp_dir}/artifacts/packer.auto.pkrvars.json"
assert_file_exists "${temp_dir}/artifacts/secrets/deploy_user_password.sha512crypt"
assert_file_exists "${temp_dir}/artifacts/ssh/id_packer_builder"

run_capture bootstrap_credentials --output-dir "${temp_dir}/require-fips" --skip-agent --require-fips
assert_status 1
assert_stderr_contains 'FIPS mode is not enabled'

printf 'PASS: bootstrap_credentials_test\n'
