#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=./testlib.sh
. "$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/testlib.sh"

temp_dir=$(make_temp_dir)
trap 'rm -rf "${temp_dir}"' EXIT

sample_file=${temp_dir}/sample.txt
printf 'hello world\n' > "${sample_file}"
chmod 600 "${sample_file}"

assert_file_exists "${sample_file}"
assert_file_contains "${sample_file}" 'hello'
assert_file_not_contains "${sample_file}" 'goodbye'
if [[ $(uname -s) == Linux* ]]; then
  assert_file_mode "${sample_file}" 600
fi
assert_not_exists "${temp_dir}/missing.txt"

run_capture bash -lc "printf 'ok'"
assert_status 0
assert_equals 'ok' "${RUN_STDOUT}"

printf 'PASS: testlib_test\n'
