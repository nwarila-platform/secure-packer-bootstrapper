if [[ -z ${_SPB_BUNDLE_MODE:-} ]]; then
  _spb_fisher_yates_shuffle_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || return 1
  # shellcheck source=../lib/common.sh
  . "${_spb_fisher_yates_shuffle_dir}/../lib/common.sh"
  # shellcheck source=../get_random/get_random.sh
  . "${_spb_fisher_yates_shuffle_dir}/../get_random/get_random.sh"
  unset _spb_fisher_yates_shuffle_dir
fi

fisher_yates_shuffle() {
  set +x
  set -f

  local array_name
  local od_bin
  local urandom_path=${GET_RANDOM_URANDOM_PATH:-/dev/urandom}
  local byte_dump byte
  local -i index item_count span acceptance_limit
  local -i word_bytes modulus chunk_bytes scanned buffered_bytes buffer_index random_word offset
  local -i random_index
  local swap_value
  local -a byte_buffer=()
  local IFS=$' \t\n'

  # Phase 1: validate the public contract and required dependency.
  if (( $# != 1 )); then
    if (( $# == 0 )); then
      printf 'error: fisher_yates_shuffle requires an array name argument\n' >&2
    else
      printf 'error: fisher_yates_shuffle takes exactly 1 argument (got %d)\n' "$#" >&2
    fi
    return 2
  fi

  array_name=${1}
  if ! spb_is_indexed_array "${array_name}"; then
    if declare -p "${array_name}" >/dev/null 2>&1; then
      printf "error: variable '%s' is not an indexed array\n" "${array_name}" >&2
    else
      printf "error: variable '%s' is not set\n" "${array_name}" >&2
    fi
    return 2
  fi

  local -n array_ref=${array_name}
  item_count=${#array_ref[@]}

  # Arrays of length 0 or 1 are already "shuffled".
  if (( item_count <= 1 )); then
    return 0
  fi

  # Phase 2: resolve entropy dependencies once so the whole shuffle can draw
  # from a buffered random-byte stream instead of spawning one command per swap.
  od_bin=${GET_RANDOM_OD_BIN:-}
  if [[ -z ${od_bin} ]]; then
    od_bin=$(type -P od 2>/dev/null) || {
      printf 'error: fisher_yates_shuffle requires od but it is not available\n' >&2
      return 127
    }
  elif [[ ! -x ${od_bin} ]]; then
    printf 'error: fisher_yates_shuffle requires od but it is not available\n' >&2
    return 127
  fi

  if [[ ! -r ${urandom_path} ]]; then
    printf 'error: fisher_yates_shuffle: %s is not readable\n' "${urandom_path}" >&2
    return 1
  fi

  if (( item_count <= 256 )); then
    word_bytes=1
    modulus=256
  elif (( item_count <= 65536 )); then
    word_bytes=2
    modulus=65536
  else
    word_bytes=3
    modulus=16777216
  fi
  buffered_bytes=0
  buffer_index=0

  # Durstenfeld's in-place Fisher-Yates shuffle:
  # walk backward through the array and swap each slot with a random earlier
  # slot, including itself.
  for ((index = item_count - 1; index > 0; index--)); do
    span=$((index + 1))
    acceptance_limit=$((modulus - (modulus % span)))

    while :; do
      if (( buffered_bytes - buffer_index < word_bytes )); then
        chunk_bytes=$((span * word_bytes * 2))
        (( chunk_bytes < word_bytes * 128 )) && chunk_bytes=$((word_bytes * 128))
        (( chunk_bytes > 4096 )) && chunk_bytes=4096
        chunk_bytes=$((chunk_bytes / word_bytes * word_bytes))

        byte_dump=$("${od_bin}" -An -v -N "${chunk_bytes}" -t u1 "${urandom_path}" 2>/dev/null) || {
          printf 'error: fisher_yates_shuffle: od failed while reading entropy\n' >&2
          return 1
        }

        buffer_index=0
        buffered_bytes=0
        scanned=0
        for byte in ${byte_dump}; do
          [[ ${byte} =~ ^[0-9]+$ ]] || continue
          if (( byte < 0 || byte > 255 )); then
            printf 'error: fisher_yates_shuffle: unexpected byte value from od: %s\n' "${byte}" >&2
            return 1
          fi
          byte_buffer[buffered_bytes]=${byte}
          (( buffered_bytes++ ))
          (( scanned++ ))
        done

        if (( scanned != chunk_bytes )); then
          printf 'error: fisher_yates_shuffle: short read from od (requested %d bytes, got %d)\n' "${chunk_bytes}" "${scanned}" >&2
          return 1
        fi
      fi

      random_word=0
      for ((offset = 0; offset < word_bytes; offset++)); do
        random_word=$((random_word * 256 + byte_buffer[buffer_index + offset]))
      done
      buffer_index=$((buffer_index + word_bytes))

      if (( random_word < acceptance_limit )); then
        random_index=$((random_word % span))
        break
      fi
    done

    swap_value=${array_ref[index]}
    array_ref[index]=${array_ref[random_index]}
    array_ref[random_index]=${swap_value}
  done
}
