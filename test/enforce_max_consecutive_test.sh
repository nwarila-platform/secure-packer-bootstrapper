#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=./testlib.sh
. "$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/testlib.sh"
# shellcheck source=../src/enforce_max_consecutive/enforce_max_consecutive.sh
. "${TEST_ROOT}/src/enforce_max_consecutive/enforce_max_consecutive.sh"

# shellcheck disable=SC2034
input=(A A b c)
result=()
set +e
enforce_max_consecutive input result 3 0
status=$?
set -e
[[ ${status} -eq 0 ]] || fail "expected enforce_max_consecutive to succeed with max=0, got ${status}"
assert_equals 'AAb' "$(printf '%s' "${result[@]}")"

# shellcheck disable=SC2034
input=(A A b c)
result=()
set +e
enforce_max_consecutive input result 3 1
status=$?
set -e
[[ ${status} -eq 0 ]] || fail "expected enforce_max_consecutive to succeed with max=1, got ${status}"
assert_equals 3 "${#result[@]}"
if (( $(max_class_run "$(printf '%s' "${result[@]}")") > 1 )); then
  fail "expected max class run <= 1"
fi

# shellcheck disable=SC2034
input=(A A A A)
result=()
run_capture enforce_max_consecutive input result 3 1
assert_status 1
assert_stderr_contains 'reserve exhausted'

run_capture enforce_max_consecutive input result nope 1
assert_status 2
assert_stderr_contains 'TARGET_LENGTH'

printf 'PASS: enforce_max_consecutive_test\n'
