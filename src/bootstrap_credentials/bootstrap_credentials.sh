if [[ -z ${_SPB_BUNDLE_MODE:-} ]]; then
  _spb_bootstrap_credentials_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || return 1
  # shellcheck source=../lib/common.sh
  . "${_spb_bootstrap_credentials_dir}/../lib/common.sh"
  # shellcheck source=../generate_password/generate_password.sh
  . "${_spb_bootstrap_credentials_dir}/../generate_password/generate_password.sh"
  # shellcheck source=../generate_password_hash/generate_password_hash.sh
  . "${_spb_bootstrap_credentials_dir}/../generate_password_hash/generate_password_hash.sh"
  # shellcheck source=../generate_ssh_keypair/generate_ssh_keypair.sh
  . "${_spb_bootstrap_credentials_dir}/../generate_ssh_keypair/generate_ssh_keypair.sh"
  unset _spb_bootstrap_credentials_dir
fi

spb_bootstrap_write_file() {
  local path=${1}
  local mode=${2}
  local content=${3-}

  printf '%s' "${content}" > "${path}" || return 1
  chmod "${mode}" "${path}" || true
}

spb_bootstrap_detect_fips() {
  local fips_enabled='0'
  local crypto_policy='unavailable'
  local fips_check='unavailable'

  if [[ -r /proc/sys/crypto/fips_enabled ]]; then
    IFS= read -r fips_enabled < /proc/sys/crypto/fips_enabled || fips_enabled='0'
  fi

  if command -v update-crypto-policies >/dev/null 2>&1; then
    crypto_policy=$(update-crypto-policies --show 2>/dev/null || printf 'unavailable')
  fi

  if command -v fips-mode-setup >/dev/null 2>&1; then
    fips_check=$(fips-mode-setup --check 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]\+$//')
  fi

  printf '%s\n%s\n%s\n' "${fips_enabled}" "${crypto_policy}" "${fips_check}"
}

spb_bootstrap_add_key_to_agent() {
  local private_key_path=${1}
  local passphrase=${2}
  local working_dir=${3}
  local ssh_agent_output
  local ssh_auth_sock=${SSH_AUTH_SOCK:-}
  local ssh_agent_pid=${SSH_AGENT_PID:-}
  local askpass_script
  local started_agent=0
  local line
  local ssh_add_bin=${BOOTSTRAP_CREDENTIALS_SSH_ADD_BIN:-ssh-add}
  local ssh_agent_bin=${BOOTSTRAP_CREDENTIALS_SSH_AGENT_BIN:-ssh-agent}

  spb_require_command "${ssh_add_bin}" bootstrap_credentials || return $?
  spb_require_command "${ssh_agent_bin}" bootstrap_credentials || return $?
  spb_require_command setsid bootstrap_credentials || return $?

  if [[ -n ${ssh_auth_sock} ]] && "${ssh_add_bin}" -l >/dev/null 2>&1; then
    printf '%s\n%s\n%d\n' "${ssh_auth_sock}" "${ssh_agent_pid}" "${started_agent}"
    return 0
  fi

  ssh_agent_output=$("${ssh_agent_bin}" -s) || {
    printf 'error: bootstrap_credentials: failed to start ssh-agent\n' >&2
    return 1
  }

  while IFS= read -r line; do
    if [[ ${line} =~ ^SSH_AUTH_SOCK=([^;]+)\; ]]; then
      ssh_auth_sock=${BASH_REMATCH[1]}
    elif [[ ${line} =~ ^SSH_AGENT_PID=([0-9]+)\; ]]; then
      ssh_agent_pid=${BASH_REMATCH[1]}
    fi
  done <<< "${ssh_agent_output}"

  if [[ -z ${ssh_auth_sock} || -z ${ssh_agent_pid} ]]; then
    printf 'error: bootstrap_credentials: failed to parse ssh-agent environment\n' >&2
    return 1
  fi

  askpass_script=${working_dir%/}/ssh-askpass.sh
  spb_bootstrap_write_file "${askpass_script}" 700 "#!/usr/bin/env bash
printf '%s\n' $(spb_shell_quote "${passphrase}")
" || {
    printf 'error: bootstrap_credentials: failed to write SSH_ASKPASS helper\n' >&2
    return 1
  }

  DISPLAY=bootstrap-askpass \
  SSH_AUTH_SOCK="${ssh_auth_sock}" \
  SSH_AGENT_PID="${ssh_agent_pid}" \
  SSH_ASKPASS="${askpass_script}" \
  SSH_ASKPASS_REQUIRE=force \
  setsid "${ssh_add_bin}" "${private_key_path}" </dev/null >/dev/null 2>&1 || {
    rm -f "${askpass_script}"
    printf 'error: bootstrap_credentials: failed to add key to ssh-agent\n' >&2
    return 1
  }

  rm -f "${askpass_script}"
  started_agent=1
  printf '%s\n%s\n%d\n' "${ssh_auth_sock}" "${ssh_agent_pid}" "${started_agent}"
}

bootstrap_credentials() (
  set +x
  set -f
  export LC_ALL=C

  local deploy_user='builder'
  local output_dir='artifacts/bootstrap'
  local password_length_s=32
  local passphrase_length_s=48
  local ssh_key_type='rsa'
  local ssh_key_bits_s=''
  local ssh_key_name='id_packer_builder'
  local ssh_key_comment=''
  local require_fips=0
  local skip_agent=0
  local option
  local generated_password
  local password_hash
  local generated_passphrase
  local key_paths
  local private_key_path
  local public_key_path
  local public_key_contents
  local fips_status
  local fips_enabled='0'
  local crypto_policy='unavailable'
  local fips_check='unavailable'
  local agent_status=''
  local ssh_auth_sock=''
  local ssh_agent_pid=''
  local agent_started=0
  local manifest_path
  local env_path
  local packer_vars_path
  local password_path
  local password_hash_path
  local passphrase_path
  local working_dir
  local timestamp_utc
  local line
  local -a fips_lines=()
  local -a agent_lines=()
  local -a keygen_args=()
  local -i password_length passphrase_length

  while (( $# > 0 )); do
    option=${1}
    case "${option}" in
      --deploy-user)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        deploy_user=${2}
        shift 2
        ;;
      --deploy-user=*)
        deploy_user=${option#*=}
        shift
        ;;
      --output-dir)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        output_dir=${2}
        shift 2
        ;;
      --output-dir=*)
        output_dir=${option#*=}
        shift
        ;;
      --password-length)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        password_length_s=${2}
        shift 2
        ;;
      --password-length=*)
        password_length_s=${option#*=}
        shift
        ;;
      --passphrase-length)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        passphrase_length_s=${2}
        shift 2
        ;;
      --passphrase-length=*)
        passphrase_length_s=${option#*=}
        shift
        ;;
      --ssh-key-type)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        ssh_key_type=${2}
        shift 2
        ;;
      --ssh-key-type=*)
        ssh_key_type=${option#*=}
        shift
        ;;
      --ssh-key-bits)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        ssh_key_bits_s=${2}
        shift 2
        ;;
      --ssh-key-bits=*)
        ssh_key_bits_s=${option#*=}
        shift
        ;;
      --ssh-key-name)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        ssh_key_name=${2}
        shift 2
        ;;
      --ssh-key-name=*)
        ssh_key_name=${option#*=}
        shift
        ;;
      --ssh-key-comment)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        ssh_key_comment=${2}
        shift 2
        ;;
      --ssh-key-comment=*)
        ssh_key_comment=${option#*=}
        shift
        ;;
      --require-fips)
        require_fips=1
        shift
        ;;
      --skip-agent)
        skip_agent=1
        shift
        ;;
      *)
        printf "error: unknown option '%s'\n" "${option}" >&2
        return 2
        ;;
    esac
  done

  if ! spb_is_uint_literal "${password_length_s}"; then
    printf "error: --password-length must be a valid integer (got '%s')\n" "${password_length_s}" >&2
    return 2
  fi
  if ! spb_is_uint_literal "${passphrase_length_s}"; then
    printf "error: --passphrase-length must be a valid integer (got '%s')\n" "${passphrase_length_s}" >&2
    return 2
  fi

  password_length=$((10#${password_length_s}))
  passphrase_length=$((10#${passphrase_length_s}))

  if (( password_length < 16 || password_length > 256 )); then
    printf 'error: --password-length must be between 16 and 256 (got %d)\n' "${password_length}" >&2
    return 2
  fi
  if (( passphrase_length < 24 || passphrase_length > 256 )); then
    printf 'error: --passphrase-length must be between 24 and 256 (got %d)\n' "${passphrase_length}" >&2
    return 2
  fi

  if [[ -z ${ssh_key_comment} ]]; then
    ssh_key_comment="${deploy_user}@secure-packer-bootstrapper"
  fi

  spb_require_function generate_password bootstrap_credentials || return $?
  spb_require_function generate_password_hash bootstrap_credentials || return $?
  spb_require_function generate_ssh_keypair bootstrap_credentials || return $?
  spb_require_command mkdir bootstrap_credentials || return $?
  spb_require_command chmod bootstrap_credentials || return $?
  spb_require_command cat bootstrap_credentials || return $?
  spb_require_command date bootstrap_credentials || return $?
  spb_require_command rm bootstrap_credentials || return $?
  spb_require_command sed bootstrap_credentials || return $?

  fips_status=$(spb_bootstrap_detect_fips)
  mapfile -t fips_lines <<< "${fips_status}"
  fips_enabled=${fips_lines[0]:-0}
  crypto_policy=${fips_lines[1]:-unavailable}
  fips_check=${fips_lines[2]:-unavailable}

  if (( require_fips )) && [[ ${fips_enabled} != 1* ]]; then
    printf 'error: bootstrap_credentials: FIPS mode is not enabled on this host\n' >&2
    return 1
  fi

  umask 077
  mkdir -p "${output_dir}" "${output_dir}/secrets" "${output_dir}/ssh" || {
    printf 'error: bootstrap_credentials: failed to create output directory %s\n' "${output_dir}" >&2
    return 1
  }

  generated_password=$(generate_password --length "${password_length}") || return $?
  password_hash=$(generate_password_hash --password "${generated_password}") || return $?
  generated_passphrase=$(generate_password --length "${passphrase_length}" --max-consecutive 2) || return $?

  keygen_args=(
    --output-dir "${output_dir}/ssh"
    --name "${ssh_key_name}"
    --passphrase "${generated_passphrase}"
    --comment "${ssh_key_comment}"
    --type "${ssh_key_type}"
  )
  if [[ -n ${ssh_key_bits_s} ]]; then
    keygen_args+=(--bits "${ssh_key_bits_s}")
  fi
  key_paths=$(generate_ssh_keypair "${keygen_args[@]}") || return $?

  private_key_path=$(printf '%s\n' "${key_paths}" | sed -n '1p')
  public_key_path=$(printf '%s\n' "${key_paths}" | sed -n '2p')
  public_key_contents=$(cat "${public_key_path}") || {
    printf 'error: bootstrap_credentials: failed to read generated public key\n' >&2
    return 1
  }

  password_path=${output_dir%/}/secrets/deploy_user_password.txt
  password_hash_path=${output_dir%/}/secrets/deploy_user_password.sha512crypt
  passphrase_path=${output_dir%/}/secrets/ssh_key_passphrase.txt
  packer_vars_path=${output_dir%/}/packer.auto.pkrvars.json
  env_path=${output_dir%/}/bootstrap.env
  manifest_path=${output_dir%/}/manifest.json
  working_dir=${output_dir%/}/.tmp
  timestamp_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  mkdir -p "${working_dir}" || {
    printf 'error: bootstrap_credentials: failed to create working directory\n' >&2
    return 1
  }

  spb_bootstrap_write_file "${password_path}" 600 "${generated_password}" || return 1
  spb_bootstrap_write_file "${password_hash_path}" 600 "${password_hash}" || return 1
  spb_bootstrap_write_file "${passphrase_path}" 600 "${generated_passphrase}" || return 1

  if (( ! skip_agent )); then
    agent_status=$(spb_bootstrap_add_key_to_agent "${private_key_path}" "${generated_passphrase}" "${working_dir}") || return $?
    mapfile -t agent_lines <<< "${agent_status}"
    ssh_auth_sock=${agent_lines[0]:-}
    ssh_agent_pid=${agent_lines[1]:-}
    agent_started=${agent_lines[2]:-0}
  fi

  spb_bootstrap_write_file "${packer_vars_path}" 600 "{
  \"deploy_user_name\": \"$(spb_json_escape "${deploy_user}")\",
  \"deploy_user_password\": \"$(spb_json_escape "${generated_password}")\",
  \"deploy_user_public_key\": \"$(spb_json_escape "${public_key_contents}")\"
}
" || return 1

  spb_bootstrap_write_file "${env_path}" 600 "export PKR_VAR_deploy_user_name=$(spb_shell_quote "${deploy_user}")
export PKR_VAR_deploy_user_password=$(spb_shell_quote "${generated_password}")
export PKR_VAR_deploy_user_public_key=$(spb_shell_quote "${public_key_contents}")
export SPB_DEPLOY_USER_PASSWORD_HASH=$(spb_shell_quote "${password_hash}")
export SPB_SSH_KEY_PASSPHRASE=$(spb_shell_quote "${generated_passphrase}")
export SPB_SSH_PRIVATE_KEY_FILE=$(spb_shell_quote "${private_key_path}")
export SPB_SSH_PUBLIC_KEY_FILE=$(spb_shell_quote "${public_key_path}")
$( [[ -n ${ssh_auth_sock} ]] && printf 'export SSH_AUTH_SOCK=%s\n' "$(spb_shell_quote "${ssh_auth_sock}")" )
$( [[ -n ${ssh_agent_pid} ]] && printf 'export SSH_AGENT_PID=%s\n' "$(spb_shell_quote "${ssh_agent_pid}")" )
" || return 1

  spb_bootstrap_write_file "${manifest_path}" 600 "{
  \"generated_at_utc\": \"$(spb_json_escape "${timestamp_utc}")\",
  \"deploy_user\": \"$(spb_json_escape "${deploy_user}")\",
  \"password_file\": \"$(spb_json_escape "${password_path}")\",
  \"password_hash_file\": \"$(spb_json_escape "${password_hash_path}")\",
  \"ssh_key_passphrase_file\": \"$(spb_json_escape "${passphrase_path}")\",
  \"private_key_file\": \"$(spb_json_escape "${private_key_path}")\",
  \"public_key_file\": \"$(spb_json_escape "${public_key_path}")\",
  \"packer_vars_file\": \"$(spb_json_escape "${packer_vars_path}")\",
  \"env_file\": \"$(spb_json_escape "${env_path}")\",
  \"ssh_key_type\": \"$(spb_json_escape "${ssh_key_type}")\",
  \"ssh_key_bits\": \"$(spb_json_escape "${ssh_key_bits_s:-default}")\",
  \"ssh_agent_started\": ${agent_started},
  \"ssh_auth_sock\": \"$(spb_json_escape "${ssh_auth_sock}")\",
  \"ssh_agent_pid\": \"$(spb_json_escape "${ssh_agent_pid}")\",
  \"fips_enabled\": \"$(spb_json_escape "${fips_enabled}")\",
  \"crypto_policy\": \"$(spb_json_escape "${crypto_policy}")\",
  \"fips_check\": \"$(spb_json_escape "${fips_check}")\"
}
" || return 1

  rm -rf "${working_dir}"
  printf '%s\n' "${manifest_path}"
)

bootstrap_credentials_cli() {
  bootstrap_credentials "$@"
}
