#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)

mapfile -t shell_files < <(find "${repo_root}/bin" "${repo_root}/scripts" "${repo_root}/src" "${repo_root}/test" -type f \( -name '*.sh' -o -name 'secure-packer-bootstrapper' \) | sort)

bash -n "${shell_files[@]}"

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x -s bash "${shell_files[@]}"
else
  printf 'shellcheck not installed; skipped shellcheck\n'
fi
