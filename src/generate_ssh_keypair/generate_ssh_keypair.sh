if [[ -z ${_SPB_BUNDLE_MODE:-} ]]; then
  _spb_generate_ssh_keypair_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || return 1
  # shellcheck source=../lib/common.sh
  . "${_spb_generate_ssh_keypair_dir}/../lib/common.sh"
  unset _spb_generate_ssh_keypair_dir
fi

generate_ssh_keypair() (
  set +x
  set -f
  export LC_ALL=C

  local output_dir=''
  local key_name='id_builder'
  local passphrase=''
  local comment='builder@secure-packer-bootstrapper'
  local key_type='rsa'
  local bits_s=''
  local force=0
  local option
  local ssh_keygen_bin=${GENERATE_SSH_KEYPAIR_SSH_KEYGEN_BIN:-ssh-keygen}
  local private_tmp=''
  local private_final=''
  local public_final=''
  local -i key_bits

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
      --name)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        key_name=${2}
        shift 2
        ;;
      --name=*)
        key_name=${option#*=}
        shift
        ;;
      --passphrase)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        passphrase=${2}
        shift 2
        ;;
      --passphrase=*)
        passphrase=${option#*=}
        shift
        ;;
      --comment)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        comment=${2}
        shift 2
        ;;
      --comment=*)
        comment=${option#*=}
        shift
        ;;
      --type)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        key_type=${2}
        shift 2
        ;;
      --type=*)
        key_type=${option#*=}
        shift
        ;;
      --bits)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        bits_s=${2}
        shift 2
        ;;
      --bits=*)
        bits_s=${option#*=}
        shift
        ;;
      --force)
        force=1
        shift
        ;;
      *)
        printf "error: unknown option '%s'\n" "${option}" >&2
        return 2
        ;;
    esac
  done

  if [[ -z ${output_dir} ]]; then
    printf 'error: --output-dir is required\n' >&2
    return 2
  fi

  if [[ -z ${passphrase} ]]; then
    printf 'error: --passphrase is required\n' >&2
    return 2
  fi

  case "${key_type}" in
    rsa)
      bits_s=${bits_s:-4096}
      ;;
    ecdsa)
      bits_s=${bits_s:-384}
      ;;
    *)
      printf "error: --type must be either 'rsa' or 'ecdsa' (got '%s')\n" "${key_type}" >&2
      return 2
      ;;
  esac

  if ! spb_is_uint_literal "${bits_s}"; then
    printf "error: --bits must be a valid integer (got '%s')\n" "${bits_s}" >&2
    return 2
  fi

  key_bits=$((10#${bits_s}))
  if [[ ${key_type} == rsa ]] && (( key_bits < 3072 || key_bits > 8192 )); then
    printf 'error: RSA --bits must be between 3072 and 8192 (got %d)\n' "${key_bits}" >&2
    return 2
  fi
  if [[ ${key_type} == ecdsa ]] && (( key_bits != 256 && key_bits != 384 && key_bits != 521 )); then
    printf 'error: ECDSA --bits must be 256, 384, or 521 (got %d)\n' "${key_bits}" >&2
    return 2
  fi

  spb_require_command "${ssh_keygen_bin}" generate_ssh_keypair || return $?
  spb_require_command mkdir generate_ssh_keypair || return $?
  spb_require_command mv generate_ssh_keypair || return $?

  umask 077
  mkdir -p "${output_dir}" || {
    printf 'error: generate_ssh_keypair: failed to create output directory %s\n' "${output_dir}" >&2
    return 1
  }

  private_final=${output_dir%/}/${key_name}
  public_final=${private_final}.pub
  if (( ! force )) && [[ -e ${private_final} || -e ${public_final} ]]; then
    printf 'error: generate_ssh_keypair: output files already exist for %s\n' "${private_final}" >&2
    return 2
  fi

  private_tmp=${private_final}.tmp.$$
  rm -f "${private_tmp}" "${private_tmp}.pub"

  "${ssh_keygen_bin}" -q -o -a 100 -t "${key_type}" -b "${key_bits}" \
    -N "${passphrase}" -C "${comment}" -f "${private_tmp}" >/dev/null 2>&1 || {
    rm -f "${private_tmp}" "${private_tmp}.pub"
    printf 'error: generate_ssh_keypair: ssh-keygen failed\n' >&2
    return 1
  }

  mv -f "${private_tmp}" "${private_final}" || {
    rm -f "${private_tmp}" "${private_tmp}.pub"
    printf 'error: generate_ssh_keypair: failed to install private key\n' >&2
    return 1
  }
  mv -f "${private_tmp}.pub" "${public_final}" || {
    rm -f "${private_final}" "${private_tmp}.pub"
    printf 'error: generate_ssh_keypair: failed to install public key\n' >&2
    return 1
  }

  chmod 600 "${private_final}" || true
  chmod 644 "${public_final}" || true

  printf '%s\n%s\n' "${private_final}" "${public_final}" || {
    printf 'error: generate_ssh_keypair: failed to emit output paths\n' >&2
    return 1
  }
)
