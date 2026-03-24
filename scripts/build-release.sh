#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
dist_dir="${repo_root}/dist"
output_file="${dist_dir}/secure-packer-bootstrapper.sh"

append_bundle_module() {
  local module_path=${1}

  awk '
    NR == 1 && $0 == "if [[ -z ${_SPB_BUNDLE_MODE:-} ]]; then" {
      skipping = 1
      next
    }
    skipping {
      if ($0 == "fi") {
        skipping = 0
      }
      next
    }
    { print }
  ' "${module_path}" >> "${output_file}"
}

mkdir -p "${dist_dir}"

cat > "${output_file}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
readonly _SPB_BUNDLE_MODE=1
EOF

append_bundle_module "${repo_root}/src/lib/common.sh"
append_bundle_module "${repo_root}/src/get_random/get_random.sh"
append_bundle_module "${repo_root}/src/fisher_yates_shuffle/fisher_yates_shuffle.sh"
append_bundle_module "${repo_root}/src/enforce_max_consecutive/enforce_max_consecutive.sh"
append_bundle_module "${repo_root}/src/generate_password/generate_password.sh"
append_bundle_module "${repo_root}/src/generate_password_hash/generate_password_hash.sh"
append_bundle_module "${repo_root}/src/generate_ssh_keypair/generate_ssh_keypair.sh"
append_bundle_module "${repo_root}/src/bootstrap_credentials/bootstrap_credentials.sh"

cat >> "${output_file}" <<'EOF'

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  bootstrap_credentials "$@"
fi
EOF

chmod +x "${output_file}"
printf 'Built %s\n' "${output_file}"
