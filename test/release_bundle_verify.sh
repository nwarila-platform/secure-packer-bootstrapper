#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=./testlib.sh
. "$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/testlib.sh"

bundle_path="${TEST_ROOT}/dist/secure-packer-bootstrapper.sh"
[[ -f ${bundle_path} ]] || fail "expected release bundle to exist: ${bundle_path}"
# shellcheck disable=SC2016
assert_file_not_contains "${bundle_path}" 'if [[ -z ${_SPB_BUNDLE_MODE:-} ]]; then'
assert_file_not_contains "${bundle_path}" '# shellcheck source=../'
assert_file_not_contains "${bundle_path}" '_spb_generate_password_dir='

temp_dir=$(make_temp_dir)
trap 'rm -rf "${temp_dir}"' EXIT

run_capture bash "${bundle_path}" --output-dir "${temp_dir}/artifacts"
assert_status 0
assert_stdout_contains 'export SPB_DEPLOY_USER_PASSWORD='
assert_stdout_contains 'export SPB_DEPLOY_USER_PASSWORD_HASH='
assert_stdout_contains 'export SPB_SSH_KEY_PASSPHRASE='
assert_stdout_contains 'export SPB_SSH_PRIVATE_KEY_FILE='
assert_stdout_contains 'export SPB_SSH_PUBLIC_KEY_FILE='
eval "${RUN_STDOUT}"
assert_file_exists "${SPB_SSH_PRIVATE_KEY_FILE}"
assert_file_exists "${SPB_SSH_PUBLIC_KEY_FILE}"
assert_not_exists "${temp_dir}/artifacts/bootstrap.env"
assert_not_exists "${temp_dir}/artifacts/packer.auto.pkrvars.json"
assert_not_exists "${temp_dir}/artifacts/manifest.json"
assert_not_exists "${temp_dir}/artifacts/secrets"
assert_not_exists "${temp_dir}/artifacts/.tmp"
unset SPB_DEPLOY_USER_PASSWORD
unset SPB_DEPLOY_USER_PASSWORD_HASH
unset SPB_SSH_KEY_PASSPHRASE
unset SPB_SSH_PRIVATE_KEY_FILE
unset SPB_SSH_PUBLIC_KEY_FILE

run_capture bash "${bundle_path}" --output-dir "${temp_dir}/removed-flags" --github-actions
assert_status 2
assert_stderr_contains "unknown option '--github-actions'"

run_capture bash "${bundle_path}" --output-dir "${temp_dir}/removed-flags" --skip-agent
assert_status 2
assert_stderr_contains "unknown option '--skip-agent'"

run_capture bash "${bundle_path}" --output-dir "${temp_dir}/removed-flags" --deploy-user builder
assert_status 2
assert_stderr_contains "unknown option '--deploy-user'"

printf 'PASS: release_bundle_verify\n'
