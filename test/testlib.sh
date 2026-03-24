#!/usr/bin/env bash
set -euo pipefail

TEST_ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
RUN_STDOUT=''
RUN_STDERR=''
RUN_STATUS=0

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

skip_test() {
  printf 'SKIP: %s\n' "$*"
  exit 0
}

run_capture() {
  local stdout_file
  local stderr_file

  stdout_file=$(mktemp)
  stderr_file=$(mktemp)

  if "$@" >"${stdout_file}" 2>"${stderr_file}"; then
    RUN_STATUS=0
  else
    RUN_STATUS=$?
  fi

  RUN_STDOUT=$(cat "${stdout_file}")
  RUN_STDERR=$(cat "${stderr_file}")
  rm -f "${stdout_file}" "${stderr_file}"
}

assert_status() {
  local expected=${1}
  [[ ${RUN_STATUS} -eq ${expected} ]] || fail "expected status ${expected}, got ${RUN_STATUS}; stderr=${RUN_STDERR}"
}

assert_stdout_matches() {
  local pattern=${1}
  [[ ${RUN_STDOUT} =~ ${pattern} ]] || fail "stdout did not match ${pattern}: ${RUN_STDOUT}"
}

assert_stdout_contains() {
  local needle=${1}
  [[ ${RUN_STDOUT} == *"${needle}"* ]] || fail "stdout did not contain ${needle}: ${RUN_STDOUT}"
}

assert_stderr_contains() {
  local needle=${1}
  [[ ${RUN_STDERR} == *"${needle}"* ]] || fail "stderr did not contain ${needle}: ${RUN_STDERR}"
}

assert_equals() {
  local expected=${1}
  local actual=${2}
  [[ ${expected} == "${actual}" ]] || fail "expected '${expected}', got '${actual}'"
}

assert_file_exists() {
  [[ -f ${1} ]] || fail "expected file to exist: ${1}"
}

assert_file_contains() {
  local path=${1}
  local needle=${2}

  grep -F -- "${needle}" "${path}" >/dev/null 2>&1 || fail "expected file ${path} to contain ${needle}"
}

assert_file_not_contains() {
  local path=${1}
  local needle=${2}

  if grep -F -- "${needle}" "${path}" >/dev/null 2>&1; then
    fail "expected file ${path} not to contain ${needle}"
  fi

  return 0
}

assert_not_exists() {
  [[ ! -e ${1} ]] || fail "expected path not to exist: ${1}"
}

assert_file_mode() {
  local path=${1}
  local expected=${2}
  local actual

  if actual=$(stat -c '%a' "${path}" 2>/dev/null); then
    :
  elif actual=$(stat -f '%Lp' "${path}" 2>/dev/null); then
    :
  else
    fail "could not read file mode for ${path}"
  fi

  [[ ${actual} == "${expected}" ]] || fail "expected mode ${expected} for ${path}, got ${actual}"
}

assert_dir_exists() {
  [[ -d ${1} ]] || fail "expected directory to exist: ${1}"
}

make_temp_dir() {
  mktemp -d "${TMPDIR:-/tmp}/spb-test.XXXXXX"
}

count_class() {
  local value=${1}
  local wanted_class=${2}
  local -i index count=0
  local char
  local class_name

  for ((index = 0; index < ${#value}; index++)); do
    char=${value:index:1}
    class_name=$(spb_classify_char "${char}")
    if [[ ${class_name} == "${wanted_class}" ]]; then
      (( count++ ))
    fi
  done

  printf '%d' "${count}"
}

max_class_run() {
  local value=${1}
  local prev=''
  local current=''
  local -i index run=0 max_run=0

  for ((index = 0; index < ${#value}; index++)); do
    current=$(spb_classify_char "${value:index:1}")
    if [[ ${current} == "${prev}" ]]; then
      (( run++ ))
    else
      run=1
      prev=${current}
    fi
    (( run > max_run )) && max_run=${run}
  done

  printf '%d' "${max_run}"
}
