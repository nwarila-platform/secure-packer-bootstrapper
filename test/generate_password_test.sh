#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=./testlib.sh
. "$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/testlib.sh"
# shellcheck source=../src/generate_password/generate_password.sh
. "${TEST_ROOT}/src/generate_password/generate_password.sh"

run_capture generate_password
assert_status 0
assert_equals 24 "${#RUN_STDOUT}"
(( "$(count_class "${RUN_STDOUT}" upper)" >= 1 )) || fail 'expected at least one uppercase character'
(( "$(count_class "${RUN_STDOUT}" lower)" >= 1 )) || fail 'expected at least one lowercase character'
(( "$(count_class "${RUN_STDOUT}" digit)" >= 1 )) || fail 'expected at least one digit'
(( "$(count_class "${RUN_STDOUT}" special)" >= 1 )) || fail 'expected at least one special character'

run_capture generate_password --max-consecutive 1 --length 32
assert_status 0
(( "$(max_class_run "${RUN_STDOUT}")" <= 1 )) || fail "expected max class run <= 1, got $(max_class_run "${RUN_STDOUT}")"

run_capture generate_password --exclude-chars '0O1lI'
assert_status 0
[[ ${RUN_STDOUT} != *0* && ${RUN_STDOUT} != *O* && ${RUN_STDOUT} != *1* && ${RUN_STDOUT} != *l* && ${RUN_STDOUT} != *I* ]] \
  || fail "excluded characters were present: ${RUN_STDOUT}"

run_capture generate_password --special '' --min-special 0 --length 20
assert_status 0
assert_equals 0 "$(count_class "${RUN_STDOUT}" special)"

run_capture generate_password --lower 'abc123'
assert_status 2
assert_stderr_contains '--lower contains characters not valid for that class'

printf 'PASS: generate_password_test\n'
