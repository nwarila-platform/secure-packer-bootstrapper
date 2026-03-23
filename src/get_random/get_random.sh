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
  local -i count min max span limit chunk_max produced remaining chunk scanned
  local -a output=()
  local dump byte
  local IFS=$' \t\n'

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

  if (( min < 0 || min > 254 )); then
    printf 'error: MIN must be between 0 and 254 (got %d)\n' "${min}" >&2
    return 2
  fi

  if (( max < 1 || max > 256 )); then
    printf 'error: MAX must be between 1 and 256 (got %d)\n' "${max}" >&2
    return 2
  fi

  if (( min >= max )); then
    printf 'error: MIN must be less than MAX (got MIN=%d MAX=%d)\n' "${min}" "${max}" >&2
    return 2
  fi

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

  span=$((max - min))
  limit=$((256 - (256 % span)))
  chunk_max=256
  produced=0

  while (( produced < count )); do
    remaining=$((count - produced))

    if (( span == 256 )); then
      chunk=${remaining}
      (( chunk > chunk_max )) && chunk=${chunk_max}
    else
      if (( remaining > 64 )); then
        chunk=${chunk_max}
      else
        chunk=$((remaining * 4))
        (( chunk < 64 )) && chunk=64
        (( chunk > chunk_max )) && chunk=${chunk_max}
      fi
    fi

    dump=$("${od_bin}" -An -v -N "${chunk}" -t u1 "${urandom_path}" 2>/dev/null) || {
      printf 'error: get_random: od failed while reading entropy\n' >&2
      return 1
    }

    scanned=0
    for byte in ${dump}; do
      [[ ${byte} =~ ^[0-9]+$ ]] || continue
      (( scanned++ ))

      if (( byte < 0 || byte > 255 )); then
        printf 'error: get_random: unexpected byte value from od: %s\n' "${byte}" >&2
        return 1
      fi

      if (( produced >= count )); then
        continue
      fi

      if (( span == 256 )); then
        output[produced]=${byte}
        (( produced++ ))
      elif (( byte < limit )); then
        output[produced]=$((min + (byte % span)))
        (( produced++ ))
      fi
    done

    if (( scanned != chunk )); then
      printf 'error: get_random: short read from od (requested %d bytes, got %d)\n' "${chunk}" "${scanned}" >&2
      return 1
    fi
  done

  printf '%s\n' "${output[@]}" || {
    printf 'error: get_random: failed to write output\n' >&2
    return 1
  }
)
