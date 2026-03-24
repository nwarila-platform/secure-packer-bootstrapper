get_random() (
  set +x
  set -f
  export LC_ALL=C

  local argc=$#
  local count_s
  local min_s=0
  local max_s=256
  local od_bin
  local urandom_path=${GET_RANDOM_URANDOM_PATH:-/dev/urandom}
  local -i count min max span acceptance_limit max_chunk_size produced remaining current_chunk_size scanned
  local -i word_bytes modulus current_word bytes_in_word
  local -a output=()
  local byte_dump byte
  local IFS=$' \t\n'

  # Phase 1: parse and validate the public function arguments.
  if (( argc != 1 && argc != 3 )); then
    printf 'error: get_random takes 1 or 3 arguments (got %d)\n' "${argc}" >&2
    return 2
  fi

  count_s=${1}
  if (( argc == 3 )); then
    min_s=${2}
    max_s=${3}
  fi

  if [[ ! ${count_s} =~ ^[1-9][0-9]{0,2}$ ]]; then
    printf "error: COUNT must be a valid integer between 1 and 999 (got '%s')\n" "${count_s}" >&2
    return 2
  fi

  if [[ ! ${min_s} =~ ^(0|[1-9][0-9]*)$ ]]; then
    printf "error: MIN must be a valid integer (got '%s')\n" "${min_s}" >&2
    return 2
  fi

  if [[ ! ${max_s} =~ ^(0|[1-9][0-9]*)$ ]]; then
    printf "error: MAX must be a valid integer (got '%s')\n" "${max_s}" >&2
    return 2
  fi

  count=$((10#${count_s}))
  min=$((10#${min_s}))
  max=$((10#${max_s}))

  if (( min < 0 || min > 16777215 )); then
    printf 'error: MIN must be between 0 and 16777215 (got %d)\n' "${min}" >&2
    return 2
  fi

  if (( max < 1 || max > 16777216 )); then
    printf 'error: MAX must be between 1 and 16777216 (got %d)\n' "${max}" >&2
    return 2
  fi

  if (( min >= max )); then
    printf 'error: MIN must be less than MAX (got MIN=%d MAX=%d)\n' "${min}" "${max}" >&2
    return 2
  fi

  # Phase 2: resolve external dependencies before we begin reading entropy.
  od_bin=${GET_RANDOM_OD_BIN:-}
  if [[ -z ${od_bin} ]]; then
    od_bin=$(type -P od 2>/dev/null) || {
      printf 'error: get_random requires od but it is not available\n' >&2
      return 127
    }
  elif [[ ! -x ${od_bin} ]]; then
    printf 'error: get_random requires od but it is not available\n' >&2
    return 127
  fi

  if [[ ! -r ${urandom_path} ]]; then
    printf 'error: get_random: %s is not readable\n' "${urandom_path}" >&2
    return 1
  fi

  # Phase 3: compute the rejection-sampling boundary.
  # Each output value is derived from a uniformly random 1-, 2-, or 3-byte word.
  # Words greater than or equal to acceptance_limit are discarded so every
  # in-range result is represented equally often.
  span=$((max - min))
  if (( span <= 256 )); then
    word_bytes=1
    modulus=256
  elif (( span <= 65536 )); then
    word_bytes=2
    modulus=65536
  else
    word_bytes=3
    modulus=16777216
  fi
  acceptance_limit=$((modulus - (modulus % span)))
  max_chunk_size=4096
  produced=0

  # Phase 4: keep reading raw bytes until we have accepted COUNT values.
  while (( produced < count )); do
    remaining=$((count - produced))

    if (( span == modulus )); then
      current_chunk_size=$((remaining * word_bytes))
      (( current_chunk_size > max_chunk_size )) && current_chunk_size=${max_chunk_size}
    else
      # For rejection-sampled ranges we over-read so rejected values do not
      # force lots of tiny `od` calls.
      if (( remaining > 64 )); then
        current_chunk_size=${max_chunk_size}
      else
        current_chunk_size=$((remaining * word_bytes * 4))
        (( current_chunk_size < word_bytes * 64 )) && current_chunk_size=$((word_bytes * 64))
        (( current_chunk_size > max_chunk_size )) && current_chunk_size=${max_chunk_size}
      fi
    fi
    current_chunk_size=$((current_chunk_size / word_bytes * word_bytes))
    (( current_chunk_size < word_bytes )) && current_chunk_size=${word_bytes}

    byte_dump=$("${od_bin}" -An -v -N "${current_chunk_size}" -t u1 "${urandom_path}" 2>/dev/null) || {
      printf 'error: get_random: od failed while reading entropy\n' >&2
      return 1
    }

    scanned=0
    current_word=0
    bytes_in_word=0
    for byte in ${byte_dump}; do
      [[ ${byte} =~ ^[0-9]+$ ]] || continue
      (( scanned++ ))

      if (( byte < 0 || byte > 255 )); then
        printf 'error: get_random: unexpected byte value from od: %s\n' "${byte}" >&2
        return 1
      fi

      if (( produced >= count )); then
        continue
      fi

      current_word=$((current_word * 256 + byte))
      (( bytes_in_word++ ))
      if (( bytes_in_word < word_bytes )); then
        continue
      fi

      if (( span == modulus || current_word < acceptance_limit )); then
        output[produced]=$((min + (current_word % span)))
        (( produced++ ))
      fi
      current_word=0
      bytes_in_word=0
    done

    if (( scanned != current_chunk_size )); then
      printf 'error: get_random: short read from od (requested %d bytes, got %d)\n' "${current_chunk_size}" "${scanned}" >&2
      return 1
    fi

    if (( bytes_in_word != 0 )); then
      printf 'error: get_random: partial random word while parsing entropy\n' >&2
      return 1
    fi
  done

  printf '%s\n' "${output[@]}" || {
    printf 'error: get_random: failed to write output\n' >&2
    return 1
  }
)
