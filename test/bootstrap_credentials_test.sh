#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=./testlib.sh
. "$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/testlib.sh"
# shellcheck source=../src/bootstrap_credentials/bootstrap_credentials.sh
. "${TEST_ROOT}/src/bootstrap_credentials/bootstrap_credentials.sh"

command -v openssl >/dev/null 2>&1 || skip_test 'openssl is required for bootstrap_credentials_test'
command -v ssh-keygen >/dev/null 2>&1 || skip_test 'ssh-keygen is required for bootstrap_credentials_test'

temp_dir=$(make_temp_dir)
trap 'rm -rf "${temp_dir}"' EXIT

run_capture bootstrap_credentials --output-dir "${temp_dir}/artifacts"
assert_status 0
assert_stdout_contains '::add-mask::'
assert_stdout_contains 'export SPB_DEPLOY_USER_PASSWORD='
assert_stdout_contains 'export SPB_DEPLOY_USER_PASSWORD_HASH='
assert_stdout_contains 'export SPB_SSH_KEY_PASSPHRASE='
assert_stdout_contains 'export SPB_SSH_PRIVATE_KEY_FILE='
assert_stdout_contains 'export SPB_SSH_PUBLIC_KEY_FILE='
assert_stdout_contains 'export PKR_VAR_deploy_user_password='
assert_stdout_contains 'export PKR_VAR_deploy_user_password_hash='
assert_stdout_contains 'export PKR_VAR_deploy_user_key='
eval "${RUN_STDOUT}" >/dev/null
assert_file_exists "${SPB_SSH_PRIVATE_KEY_FILE}"
assert_file_exists "${SPB_SSH_PUBLIC_KEY_FILE}"
assert_equals "${SPB_DEPLOY_USER_PASSWORD}" "${PKR_VAR_deploy_user_password}"
assert_equals "${SPB_DEPLOY_USER_PASSWORD_HASH}" "${PKR_VAR_deploy_user_password_hash}"
assert_equals "$(cat "${SPB_SSH_PUBLIC_KEY_FILE}")" "${PKR_VAR_deploy_user_key}"
assert_not_exists "${temp_dir}/artifacts/bootstrap.env"
assert_not_exists "${temp_dir}/artifacts/packer.auto.pkrvars.json"
assert_not_exists "${temp_dir}/artifacts/manifest.json"
assert_not_exists "${temp_dir}/artifacts/secrets"
assert_not_exists "${temp_dir}/artifacts/.tmp"
if [[ $(uname -s) == Linux* ]]; then
  assert_file_mode "${SPB_SSH_PRIVATE_KEY_FILE}" 600
  assert_file_mode "${SPB_SSH_PUBLIC_KEY_FILE}" 644
fi
unset SPB_DEPLOY_USER_PASSWORD
unset SPB_DEPLOY_USER_PASSWORD_HASH
unset SPB_SSH_KEY_PASSPHRASE
unset SPB_SSH_PRIVATE_KEY_FILE
unset SPB_SSH_PUBLIC_KEY_FILE
unset PKR_VAR_deploy_user_password
unset PKR_VAR_deploy_user_password_hash
unset PKR_VAR_deploy_user_key

printf '%s\n' "${RUN_STDOUT}" > "${temp_dir}/mask-snippet.sh"
run_capture env -u GITHUB_ACTIONS -u GITHUB_WORKFLOW -u GITHUB_ENV -u GITHUB_OUTPUT GITHUB_RUN_ID=123 bash -c '. "$1"' _ "${temp_dir}/mask-snippet.sh"
assert_status 0
assert_stdout_contains '::add-mask::'

mkdir -p "${temp_dir}/default-cwd"
pushd "${temp_dir}/default-cwd" >/dev/null || fail "failed to enter ${temp_dir}/default-cwd"
run_capture bootstrap_credentials
assert_status 0
assert_stdout_contains '::add-mask::'
eval "${RUN_STDOUT}" >/dev/null
assert_equals 'artifacts/bootstrap/ssh/id_packer_builder' "${SPB_SSH_PRIVATE_KEY_FILE}"
assert_equals 'artifacts/bootstrap/ssh/id_packer_builder.pub' "${SPB_SSH_PUBLIC_KEY_FILE}"
assert_file_exists "${SPB_SSH_PRIVATE_KEY_FILE}"
assert_file_exists "${SPB_SSH_PUBLIC_KEY_FILE}"
assert_equals "$(cat "${SPB_SSH_PUBLIC_KEY_FILE}")" "${PKR_VAR_deploy_user_key}"
unset SPB_DEPLOY_USER_PASSWORD
unset SPB_DEPLOY_USER_PASSWORD_HASH
unset SPB_SSH_KEY_PASSPHRASE
unset SPB_SSH_PRIVATE_KEY_FILE
unset SPB_SSH_PUBLIC_KEY_FILE
unset PKR_VAR_deploy_user_password
unset PKR_VAR_deploy_user_password_hash
unset PKR_VAR_deploy_user_key
popd >/dev/null || fail "failed to leave ${temp_dir}/default-cwd"

run_capture bootstrap_credentials --output-dir "${temp_dir}/removed-flags" --github-actions
assert_status 2
assert_stderr_contains "unknown option '--github-actions'"

run_capture bootstrap_credentials --output-dir "${temp_dir}/removed-flags" --skip-agent
assert_status 2
assert_stderr_contains "unknown option '--skip-agent'"

run_capture bootstrap_credentials --output-dir "${temp_dir}/removed-flags" --deploy-user builder
assert_status 2
assert_stderr_contains "unknown option '--deploy-user'"

run_capture bootstrap_credentials --output-dir "${temp_dir}/removed-flags" --require-fips
assert_status 2
assert_stderr_contains "unknown option '--require-fips'"

printf 'PASS: bootstrap_credentials_test\n'
