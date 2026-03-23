#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=./testlib.sh
. "$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/testlib.sh"
# shellcheck source=../src/fisher_yates_shuffle/fisher_yates_shuffle.sh
. "${TEST_ROOT}/src/fisher_yates_shuffle/fisher_yates_shuffle.sh"

run_capture fisher_yates_shuffle
assert_status 2
assert_stderr_contains 'requires an array name'

sample=(A B C D E F)
original_sorted=$(printf '%s\n' "${sample[@]}" | sort | tr '\n' ' ')
fisher_yates_shuffle sample
shuffled_sorted=$(printf '%s\n' "${sample[@]}" | sort | tr '\n' ' ')
assert_equals "${original_sorted}" "${shuffled_sorted}"

single=(only)
fisher_yates_shuffle single
assert_equals 'only' "${single[0]}"

get_random() { return 1; }
problem=(1 2 3)
run_capture fisher_yates_shuffle problem
assert_status 1
assert_stderr_contains 'get_random failed'

printf 'PASS: fisher_yates_shuffle_test\n'
