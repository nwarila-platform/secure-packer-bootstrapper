if [[ -z ${_SPB_BUNDLE_MODE:-} ]]; then
  _spb_generate_password_hash_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || return 1
  # shellcheck source=../lib/common.sh
  . "${_spb_generate_password_hash_dir}/../lib/common.sh"
  # shellcheck source=../get_random/get_random.sh
  . "${_spb_generate_password_hash_dir}/../get_random/get_random.sh"
  unset _spb_generate_password_hash_dir
fi

generate_password_hash() (
  set +x
  set -f
  export LC_ALL=C

  local password=''
  local salt_length_s=16
  local rounds=10000
  local option
  local openssl_bin=${GENERATE_PASSWORD_HASH_OPENSSL_BIN:-openssl}
  local salt_alphabet='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789./'
  local salt=''
  local salt_spec=''
  local hash_output
  local draw_output
  local draw_index
  local line
  local -a salt_chars=()
  local -i salt_length

  while (( $# > 0 )); do
    option=${1}
    case "${option}" in
      --password)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        password=${2}
        shift 2
        ;;
      --password=*)
        password=${option#*=}
        shift
        ;;
      --salt-length)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        salt_length_s=${2}
        shift 2
        ;;
      --salt-length=*)
        salt_length_s=${option#*=}
        shift
        ;;
      *)
        printf "error: unknown option '%s'\n" "${option}" >&2
        return 2
        ;;
    esac
  done

  if [[ -z ${password} ]]; then
    if [[ -t 0 ]]; then
      printf 'error: --password is required when stdin is a terminal\n' >&2
      return 2
    fi
    IFS= read -r password || {
      printf 'error: failed to read password from stdin\n' >&2
      return 1
    }
  fi

  if ! spb_is_uint_literal "${salt_length_s}"; then
    printf "error: --salt-length must be a valid integer (got '%s')\n" "${salt_length_s}" >&2
    return 2
  fi

  salt_length=$((10#${salt_length_s}))
  if (( salt_length < 8 || salt_length > 16 )); then
    printf 'error: --salt-length must be between 8 and 16 (got %d)\n' "${salt_length}" >&2
    return 2
  fi

  spb_require_function get_random generate_password_hash || return $?
  spb_require_command "${openssl_bin}" generate_password_hash || return $?

  spb_string_to_array "${salt_alphabet}" salt_chars
  draw_output=$(get_random "${salt_length}" 0 "${#salt_chars[@]}") || return $?
  while IFS= read -r line; do
    draw_index=$((10#${line}))
    salt+="${salt_chars[draw_index]}"
  done <<< "${draw_output}"

  # OpenSSL's `passwd` command accepts SHA-512 rounds through the salt setting.
  salt_spec="rounds=${rounds}\$${salt}"
  hash_output=$(printf '%s\n' "${password}" | "${openssl_bin}" passwd -6 -stdin -salt "${salt_spec}" 2>/dev/null) || {
    printf 'error: generate_password_hash: openssl passwd failed\n' >&2
    return 1
  }

  printf '%s\n' "${hash_output}" || {
    printf 'error: generate_password_hash: failed to emit hash\n' >&2
    return 1
  }
)
