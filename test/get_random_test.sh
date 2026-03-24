#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=./testlib.sh
. "$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/testlib.sh"
# shellcheck source=../src/get_random/get_random.sh
. "${TEST_ROOT}/src/get_random/get_random.sh"

run_capture get_random 1
assert_status 0
assert_stdout_matches '^[0-9]+$'
(( RUN_STDOUT >= 0 && RUN_STDOUT < 256 )) || fail "random byte out of range: ${RUN_STDOUT}"

run_capture get_random 32 10 20
assert_status 0
while IFS= read -r line; do
  (( line >= 10 && line < 20 )) || fail "ranged value out of bounds: ${line}"
done <<< "${RUN_STDOUT}"

run_capture get_random 64 0 512
assert_status 0
line_count=0
while IFS= read -r line; do
  (( line >= 0 && line < 512 )) || fail "extended-range value out of bounds: ${line}"
  (( line_count += 1 ))
done <<< "${RUN_STDOUT}"
assert_equals 64 "${line_count}"

declare -a bucket_counts=()
for ((bucket = 0; bucket < 10; bucket++)); do
  bucket_counts[bucket]=0
done

run_capture get_random 900 0 10
assert_status 0
line_count=0
while IFS= read -r line; do
  [[ ${line} =~ ^[0-9]+$ ]] || fail "distribution sample was not numeric: ${line}"
  (( line >= 0 && line < 10 )) || fail "distribution sample out of bounds: ${line}"
  bucket_counts[line]=$(( bucket_counts[line] + 1 ))
  (( line_count += 1 ))
done <<< "${RUN_STDOUT}"
assert_equals 900 "${line_count}"
for ((bucket = 0; bucket < 10; bucket++)); do
  count=${bucket_counts[bucket]}
  (( count >= 45 && count <= 135 )) \
    || fail "bucket ${bucket} count ${count} was outside the expected smoke-test bounds"
done

run_capture get_random 0
assert_status 2
assert_stderr_contains 'COUNT'

temp_dir=$(make_temp_dir)
trap 'rm -rf "${temp_dir}"' EXIT

GET_RANDOM_OD_BIN=${temp_dir}/missing-od run_capture get_random 1
assert_status 127
assert_stderr_contains 'requires od'

fake_od="${temp_dir}/od"
cat >"${fake_od}" <<'EOF'
#!/usr/bin/env bash
printf '12 13\n'
EOF
chmod +x "${fake_od}"
printf 'abc' > "${temp_dir}/entropy"
GET_RANDOM_OD_BIN=${fake_od} GET_RANDOM_URANDOM_PATH=${temp_dir}/entropy run_capture get_random 10
assert_status 1
assert_stderr_contains 'short read'

printf 'PASS: get_random_test\n'
