#!/usr/bin/env bash
set -euo pipefail

test_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(CDPATH= cd -- "${test_root}/.." && pwd -P)
status=0

while IFS= read -r test_file; do
  printf 'Running %s\n' "${test_file#${repo_root}/}"
  if ! bash "${test_file}"; then
    status=1
  fi
done < <(find "${test_root}" -maxdepth 1 -name '*_test.sh' | sort)

exit "${status}"
