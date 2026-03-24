#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=./testlib.sh
. "$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/testlib.sh"
# shellcheck source=../src/fisher_yates_shuffle/fisher_yates_shuffle.sh
. "${TEST_ROOT}/src/fisher_yates_shuffle/fisher_yates_shuffle.sh"

run_capture fisher_yates_shuffle
assert_status 2
assert_stderr_contains 'requires an array name'

sample=(A B C D E F)
original_sorted=$(printf '%s\n' "${sample[@]}" | sort | tr '\n' ' ')
run_capture fisher_yates_shuffle sample
assert_status 0
shuffled_sorted=$(printf '%s\n' "${sample[@]}" | sort | tr '\n' ' ')
assert_equals "${original_sorted}" "${shuffled_sorted}"

large=()
for ((i = 0; i < 300; i++)); do
  large+=("${i}")
done
large_sorted_before=$(printf '%s\n' "${large[@]}" | sort -n | tr '\n' ' ')
run_capture fisher_yates_shuffle large
assert_status 0
large_sorted_after=$(printf '%s\n' "${large[@]}" | sort -n | tr '\n' ' ')
assert_equals "${large_sorted_before}" "${large_sorted_after}"

single=(only)
run_capture fisher_yates_shuffle single
assert_status 0
assert_equals 'only' "${single[0]}"

order_ab=0
order_ba=0
for ((run = 0; run < 400; run++)); do
  pair=(A B)
  run_capture fisher_yates_shuffle pair
  assert_status 0
  case "${pair[*]}" in
    'A B') (( order_ab += 1 )) ;;
    'B A') (( order_ba += 1 )) ;;
    *) fail "unexpected two-element ordering: ${pair[*]}" ;;
  esac
done
(( order_ab >= 120 && order_ab <= 280 )) \
  || fail "ordering 'A B' appeared ${order_ab} times, outside expected smoke-test bounds"
(( order_ba >= 120 && order_ba <= 280 )) \
  || fail "ordering 'B A' appeared ${order_ba} times, outside expected smoke-test bounds"

temp_dir=$(make_temp_dir)
trap 'rm -rf "${temp_dir}"' EXIT

# shellcheck disable=SC2034
problem=(1 2 3)
GET_RANDOM_OD_BIN=${temp_dir}/missing-od run_capture fisher_yates_shuffle problem
assert_status 127
assert_stderr_contains 'requires od'

printf 'PASS: fisher_yates_shuffle_test\n'
