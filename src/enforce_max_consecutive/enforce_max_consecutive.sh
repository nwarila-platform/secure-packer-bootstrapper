if [[ -z ${_SPB_BUNDLE_MODE:-} ]]; then
  _spb_enforce_max_consecutive_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || return 1
  # shellcheck source=../lib/common.sh
  . "${_spb_enforce_max_consecutive_dir}/../lib/common.sh"
  unset _spb_enforce_max_consecutive_dir
fi

enforce_max_consecutive() {
  set +x
  set -f
  export LC_ALL=C

  local input_name=${1:-}
  local result_name=${2:-}
  local target_length_s=${3:-}
  local max_consecutive_s=${4:-}
  local -i target_length max_consecutive queue_size attempt processed_candidates
  local prev_class=''
  local current_class=''
  local current_char=''
  local -i run_length=0
  local accepted=0

  if (( $# != 4 )); then
    printf 'error: enforce_max_consecutive takes exactly 4 arguments (got %d)\n' "$#" >&2
    return 2
  fi

  if ! spb_is_indexed_array "${input_name}"; then
    if declare -p "${input_name}" >/dev/null 2>&1; then
      printf "error: enforce_max_consecutive: variable '%s' is not an indexed array\n" "${input_name}" >&2
    else
      printf "error: enforce_max_consecutive: variable '%s' is not set\n" "${input_name}" >&2
    fi
    return 2
  fi

  if ! spb_is_indexed_array "${result_name}"; then
    if declare -p "${result_name}" >/dev/null 2>&1; then
      printf "error: enforce_max_consecutive: variable '%s' is not an indexed array\n" "${result_name}" >&2
    else
      printf "error: enforce_max_consecutive: variable '%s' is not set\n" "${result_name}" >&2
    fi
    return 2
  fi

  if ! spb_is_uint_literal "${target_length_s}"; then
    printf "error: enforce_max_consecutive: TARGET_LENGTH must be a valid integer (got '%s')\n" "${target_length_s}" >&2
    return 2
  fi

  if ! spb_is_uint_literal "${max_consecutive_s}"; then
    printf "error: enforce_max_consecutive: MAX_CONSECUTIVE must be a valid integer (got '%s')\n" "${max_consecutive_s}" >&2
    return 2
  fi

  target_length=$((10#${target_length_s}))
  max_consecutive=$((10#${max_consecutive_s}))

  if (( target_length < 1 || target_length > 512 )); then
    printf 'error: enforce_max_consecutive: TARGET_LENGTH must be between 1 and 512 (got %d)\n' "${target_length}" >&2
    return 2
  fi

  if (( max_consecutive < 0 || max_consecutive > 512 )); then
    printf 'error: enforce_max_consecutive: MAX_CONSECUTIVE must be between 0 and 512 (got %d)\n' "${max_consecutive}" >&2
    return 2
  fi

  local -n input_ref=${input_name}
  local -n result_ref=${result_name}

  if (( ${#input_ref[@]} < target_length )); then
    printf 'error: enforce_max_consecutive: input length %d is smaller than TARGET_LENGTH %d\n' "${#input_ref[@]}" "${target_length}" >&2
    return 2
  fi

  result_ref=()

  if (( max_consecutive == 0 || max_consecutive >= target_length )); then
    for ((attempt = 0; attempt < target_length; attempt++)); do
      result_ref+=("${input_ref[attempt]}")
    done
    return 0
  fi

  local -a queue=("${input_ref[@]}")
  processed_candidates=0

  while (( ${#result_ref[@]} < target_length )); do
    queue_size=${#queue[@]}
    accepted=0

    for ((attempt = 0; attempt < queue_size; attempt++)); do
      current_char=${queue[0]}
      queue=("${queue[@]:1}")
      (( processed_candidates++ ))

      current_class=$(spb_classify_char "${current_char}") || {
        printf 'error: enforce_max_consecutive: failed to classify character\n' >&2
        return 2
      }

      if (( ${#result_ref[@]} > 0 )) && [[ ${current_class} == "${prev_class}" ]] && (( run_length >= max_consecutive )); then
        queue+=("${current_char}")
        continue
      fi

      result_ref+=("${current_char}")
      if [[ ${current_class} == "${prev_class}" ]]; then
        (( run_length++ ))
      else
        run_length=1
        prev_class=${current_class}
      fi
      accepted=1
      break
    done

    if (( ! accepted )); then
      local -i remaining_needed=$((target_length - ${#result_ref[@]}))
      result_ref=()
      printf 'error: enforce_max_consecutive: reserve exhausted after %d candidates (need %d more characters)\n' \
        "${processed_candidates}" "${remaining_needed}" >&2
      return 1
    fi
  done

  return 0
}
