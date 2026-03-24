if [[ -z ${_SPB_BUNDLE_MODE:-} ]]; then
  _spb_bootstrap_credentials_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || return 1
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

spb_bootstrap_emit_shell_exports() {
  local generated_password=${1}
  local password_hash=${2}
  local generated_passphrase=${3}
  local private_key_path=${4}
  local public_key_path=${5}

  printf 'export SPB_DEPLOY_USER_PASSWORD=%s\n' "$(spb_shell_quote "${generated_password}")" || return 1
  printf 'export SPB_DEPLOY_USER_PASSWORD_HASH=%s\n' "$(spb_shell_quote "${password_hash}")" || return 1
  printf 'export SPB_SSH_KEY_PASSPHRASE=%s\n' "$(spb_shell_quote "${generated_passphrase}")" || return 1
  printf 'export SPB_SSH_PRIVATE_KEY_FILE=%s\n' "$(spb_shell_quote "${private_key_path}")" || return 1
  printf 'export SPB_SSH_PUBLIC_KEY_FILE=%s\n' "$(spb_shell_quote "${public_key_path}")" || return 1
}

bootstrap_credentials() (
  set +x
  set -f
  export LC_ALL=C

  local output_dir='artifacts/bootstrap'
  local password_length_s=32
  local passphrase_length_s=48
  local ssh_key_type='rsa'
  local ssh_key_bits_s=''
  local ssh_key_name='id_packer_builder'
  local ssh_key_comment=''
  local option
  local generated_password
  local password_hash
  local generated_passphrase
  local key_paths
  local private_key_path
  local public_key_path
  local -a keygen_args=()
  local -a key_lines=()
  local -i password_length passphrase_length

  while (( $# > 0 )); do
    option=${1}
    case "${option}" in
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
    ssh_key_comment='builder@secure-packer-bootstrapper'
  fi

  spb_require_function generate_password bootstrap_credentials || return $?
  spb_require_function generate_password_hash bootstrap_credentials || return $?
  spb_require_function generate_ssh_keypair bootstrap_credentials || return $?
  spb_require_command mkdir bootstrap_credentials || return $?
  spb_require_command chmod bootstrap_credentials || return $?

  umask 077
  mkdir -p "${output_dir}" "${output_dir}/ssh" || {
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
  mapfile -t key_lines <<< "${key_paths}"
  private_key_path=${key_lines[0]:-}
  public_key_path=${key_lines[1]:-}
  if [[ -z ${private_key_path} || -z ${public_key_path} ]]; then
    printf 'error: bootstrap_credentials: failed to parse generated key paths\n' >&2
    return 1
  fi

  spb_bootstrap_emit_shell_exports \
    "${generated_password}" \
    "${password_hash}" \
    "${generated_passphrase}" \
    "${private_key_path}" \
    "${public_key_path}" || return 1
)
