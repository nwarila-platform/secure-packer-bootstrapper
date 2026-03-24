#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)

bash "${repo_root}/scripts/lint.sh"
bash "${repo_root}/scripts/test.sh"
bash "${repo_root}/scripts/build-release.sh"
bash -n "${repo_root}/dist/secure-packer-bootstrapper.sh"
bash "${repo_root}/test/release_bundle_verify.sh"
