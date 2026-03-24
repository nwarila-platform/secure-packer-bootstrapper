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

declare -A seen_passwords=()
for ((run = 0; run < 2; run++)); do
  run_capture generate_password
  assert_status 0
  assert_equals 24 "${#RUN_STDOUT}"
  (( "$(count_class "${RUN_STDOUT}" upper)" >= 1 )) || fail 'expected at least one uppercase character during repeated-run test'
  (( "$(count_class "${RUN_STDOUT}" lower)" >= 1 )) || fail 'expected at least one lowercase character during repeated-run test'
  (( "$(count_class "${RUN_STDOUT}" digit)" >= 1 )) || fail 'expected at least one digit during repeated-run test'
  (( "$(count_class "${RUN_STDOUT}" special)" >= 1 )) || fail 'expected at least one special character during repeated-run test'
  seen_passwords["${RUN_STDOUT}"]=1
done
(( ${#seen_passwords[@]} >= 2 )) || fail 'expected repeated runs to produce varied passwords'

for ((run = 0; run < 2; run++)); do
  run_capture generate_password --length 16 --min-upper 3 --min-lower 3 --min-digit 3 --min-special 3
  assert_status 0
  (( "$(count_class "${RUN_STDOUT}" upper)" >= 3 )) || fail 'expected at least three uppercase characters'
  (( "$(count_class "${RUN_STDOUT}" lower)" >= 3 )) || fail 'expected at least three lowercase characters'
  (( "$(count_class "${RUN_STDOUT}" digit)" >= 3 )) || fail 'expected at least three digits'
  (( "$(count_class "${RUN_STDOUT}" special)" >= 3 )) || fail 'expected at least three special characters'
done

run_capture generate_password --max-consecutive 1 --length 32
assert_status 0
(( "$(max_class_run "${RUN_STDOUT}")" <= 1 )) || fail "expected max class run <= 1, got $(max_class_run "${RUN_STDOUT}")"

run_capture generate_password --length 256
assert_status 0
assert_equals 256 "${#RUN_STDOUT}"
(( "$(count_class "${RUN_STDOUT}" upper)" >= 1 )) || fail 'expected at least one uppercase character in length-256 password'
(( "$(count_class "${RUN_STDOUT}" lower)" >= 1 )) || fail 'expected at least one lowercase character in length-256 password'
(( "$(count_class "${RUN_STDOUT}" digit)" >= 1 )) || fail 'expected at least one digit in length-256 password'
(( "$(count_class "${RUN_STDOUT}" special)" >= 1 )) || fail 'expected at least one special character in length-256 password'

for ((run = 0; run < 2; run++)); do
  run_capture generate_password --max-consecutive 1 --length 16
  assert_status 0
  (( "$(max_class_run "${RUN_STDOUT}")" <= 1 )) || fail "expected max class run <= 1 during repeated-run test, got $(max_class_run "${RUN_STDOUT}")"
done

run_capture generate_password --exclude-chars '0O1lI'
assert_status 2
assert_stderr_contains "unknown option '--exclude-chars'"

run_capture generate_password --special '' --min-special 0 --length 20
assert_status 0
assert_equals 0 "$(count_class "${RUN_STDOUT}" special)"

run_capture generate_password --lower 'abc123'
assert_status 2
assert_stderr_contains '--lower contains characters not valid for that class'

run_capture generate_password --length 8 --upper 'ABCD' --lower '' --digit '' --special '' \
  --min-upper 8 --min-lower 0 --min-digit 0 --min-special 0 --max-consecutive 1
assert_status 1
assert_stderr_contains 'consecutive-class constraint unsatisfiable'

printf 'PASS: generate_password_test\n'
