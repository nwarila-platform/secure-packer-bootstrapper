#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
dist_dir="${repo_root}/dist"
output_file="${dist_dir}/secure-packer-bootstrapper.sh"

mkdir -p "${dist_dir}"

cat > "${output_file}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
readonly _SPB_BUNDLE_MODE=1
EOF

cat \
  "${repo_root}/src/lib/common.sh" \
  "${repo_root}/src/get_random/get_random.sh" \
  "${repo_root}/src/fisher_yates_shuffle/fisher_yates_shuffle.sh" \
  "${repo_root}/src/enforce_max_consecutive/enforce_max_consecutive.sh" \
  "${repo_root}/src/generate_password/generate_password.sh" \
  "${repo_root}/src/generate_password_hash/generate_password_hash.sh" \
  "${repo_root}/src/generate_ssh_keypair/generate_ssh_keypair.sh" \
  "${repo_root}/src/bootstrap_credentials/bootstrap_credentials.sh" >> "${output_file}"

cat >> "${output_file}" <<'EOF'

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  bootstrap_credentials_cli "$@"
fi
EOF

chmod +x "${output_file}"
printf 'Built %s\n' "${output_file}"
