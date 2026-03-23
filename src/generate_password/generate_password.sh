if [[ -z ${_SPB_BUNDLE_MODE:-} ]]; then
  _spb_generate_password_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || return 1
  # shellcheck source=../lib/common.sh
  . "${_spb_generate_password_dir}/../lib/common.sh"
  # shellcheck source=../get_random/get_random.sh
  . "${_spb_generate_password_dir}/../get_random/get_random.sh"
  # shellcheck source=../fisher_yates_shuffle/fisher_yates_shuffle.sh
  . "${_spb_generate_password_dir}/../fisher_yates_shuffle/fisher_yates_shuffle.sh"
  # shellcheck source=../enforce_max_consecutive/enforce_max_consecutive.sh
  . "${_spb_generate_password_dir}/../enforce_max_consecutive/enforce_max_consecutive.sh"
  unset _spb_generate_password_dir
fi

generate_password() (
  set +x
  set -f
  export LC_ALL=C

  local caller='generate_password'
  local length_s=24
  local upper='ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  local lower='abcdefghijklmnopqrstuvwxyz'
  local digit='0123456789'
  local special
  local min_upper_s=1
  local min_lower_s=1
  local min_digit_s=1
  local min_special_s=1
  local max_consecutive_s=3
  local exclude_chars=''
  local option
  local invalid_chars
  local duplicate_chars
  local active_combined=''
  local password
  local draw_output
  local draw_index
  local enforce_status
  local line
  local class_name
  local character
  local character_class
  local -i attempt max_attempts=16
  local -i length min_upper min_lower min_digit min_special max_consecutive minimum_sum
  local -i candidate_target fill_count
  local -i upper_count=0 lower_count=0 digit_count=0 special_count=0
  local -a pool_upper=()
  local -a pool_lower=()
  local -a pool_digit=()
  local -a pool_special=()
  local -a pool_combined=()
  local -a candidates=()
  local -a result=()
  local IFS=$' \t\n'

  special=$(spb_default_special_chars)

  while (( $# > 0 )); do
    option=${1}
    case "${option}" in
      -l|--length)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        length_s=${2}
        shift 2
        ;;
      --length=*)
        length_s=${option#*=}
        shift
        ;;
      --upper)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        upper=${2}
        shift 2
        ;;
      --upper=*)
        upper=${option#*=}
        shift
        ;;
      --lower)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        lower=${2}
        shift 2
        ;;
      --lower=*)
        lower=${option#*=}
        shift
        ;;
      --digit)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        digit=${2}
        shift 2
        ;;
      --digit=*)
        digit=${option#*=}
        shift
        ;;
      --special)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        special=${2}
        shift 2
        ;;
      --special=*)
        special=${option#*=}
        shift
        ;;
      --min-upper)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        min_upper_s=${2}
        shift 2
        ;;
      --min-upper=*)
        min_upper_s=${option#*=}
        shift
        ;;
      --min-lower)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        min_lower_s=${2}
        shift 2
        ;;
      --min-lower=*)
        min_lower_s=${option#*=}
        shift
        ;;
      --min-digit)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        min_digit_s=${2}
        shift 2
        ;;
      --min-digit=*)
        min_digit_s=${option#*=}
        shift
        ;;
      --min-special)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        min_special_s=${2}
        shift 2
        ;;
      --min-special=*)
        min_special_s=${option#*=}
        shift
        ;;
      --max-consecutive)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        max_consecutive_s=${2}
        shift 2
        ;;
      --max-consecutive=*)
        max_consecutive_s=${option#*=}
        shift
        ;;
      --exclude-chars)
        if (( $# < 2 )); then
          printf "error: option '%s' requires a value\n" "${option}" >&2
          return 2
        fi
        exclude_chars=${2}
        shift 2
        ;;
      --exclude-chars=*)
        exclude_chars=${option#*=}
        shift
        ;;
      --)
        shift
        if (( $# > 0 )); then
          printf "error: unknown option '%s'\n" "${1}" >&2
          return 2
        fi
        ;;
      *)
        printf "error: unknown option '%s'\n" "${option}" >&2
        return 2
        ;;
    esac
  done

  for option in \
    "--length:${length_s}" \
    "--min-upper:${min_upper_s}" \
    "--min-lower:${min_lower_s}" \
    "--min-digit:${min_digit_s}" \
    "--min-special:${min_special_s}" \
    "--max-consecutive:${max_consecutive_s}"; do
    if ! spb_is_uint_literal "${option#*:}"; then
      printf "error: %s must be a valid integer (got '%s')\n" "${option%%:*}" "${option#*:}" >&2
      return 2
    fi
  done

  length=$((10#${length_s}))
  min_upper=$((10#${min_upper_s}))
  min_lower=$((10#${min_lower_s}))
  min_digit=$((10#${min_digit_s}))
  min_special=$((10#${min_special_s}))
  max_consecutive=$((10#${max_consecutive_s}))

  if (( length < 8 || length > 256 )); then
    printf 'error: --length must be between 8 and 256 (got %d)\n' "${length}" >&2
    return 2
  fi

  for option in \
    "--min-upper:${min_upper}" \
    "--min-lower:${min_lower}" \
    "--min-digit:${min_digit}" \
    "--min-special:${min_special}" \
    "--max-consecutive:${max_consecutive}"; do
    if (( ${option#*:} < 0 || ${option#*:} > 256 )); then
      printf 'error: %s must be between 0 and 256 (got %d)\n' "${option%%:*}" "${option#*:}" >&2
      return 2
    fi
  done

  for class_name in upper lower digit special; do
    case "${class_name}" in
      upper)
        invalid_chars=$(spb_invalid_chars_for_class upper "${upper}")
        duplicate_chars=$(spb_find_duplicate_chars "${upper}")
        ;;
      lower)
        invalid_chars=$(spb_invalid_chars_for_class lower "${lower}")
        duplicate_chars=$(spb_find_duplicate_chars "${lower}")
        ;;
      digit)
        invalid_chars=$(spb_invalid_chars_for_class digit "${digit}")
        duplicate_chars=$(spb_find_duplicate_chars "${digit}")
        ;;
      special)
        invalid_chars=$(spb_invalid_chars_for_class special "${special}")
        duplicate_chars=$(spb_find_duplicate_chars "${special}")
        ;;
    esac

    if [[ -n ${invalid_chars} ]]; then
      printf "error: --%s contains characters not valid for that class: '%s'\n" "${class_name}" "${invalid_chars}" >&2
      return 2
    fi

    if [[ -n ${duplicate_chars} ]]; then
      printf "error: --%s contains duplicate characters: '%s'\n" "${class_name}" "${duplicate_chars}" >&2
      return 2
    fi
  done

  upper=$(spb_filter_chars "${upper}" "${exclude_chars}")
  lower=$(spb_filter_chars "${lower}" "${exclude_chars}")
  digit=$(spb_filter_chars "${digit}" "${exclude_chars}")
  special=$(spb_filter_chars "${special}" "${exclude_chars}")

  if [[ -z ${upper}${lower}${digit}${special} ]]; then
    printf 'error: --exclude-chars removed all characters from every class\n' >&2
    return 2
  fi

  if (( min_upper > 0 )) && [[ -z ${upper} ]]; then
    printf "error: class 'upper' is empty but --min-upper is %d\n" "${min_upper}" >&2
    return 2
  fi
  if (( min_lower > 0 )) && [[ -z ${lower} ]]; then
    printf "error: class 'lower' is empty but --min-lower is %d\n" "${min_lower}" >&2
    return 2
  fi
  if (( min_digit > 0 )) && [[ -z ${digit} ]]; then
    printf "error: class 'digit' is empty but --min-digit is %d\n" "${min_digit}" >&2
    return 2
  fi
  if (( min_special > 0 )) && [[ -z ${special} ]]; then
    printf "error: class 'special' is empty but --min-special is %d\n" "${min_special}" >&2
    return 2
  fi

  minimum_sum=$((min_upper + min_lower + min_digit + min_special))
  if (( length < minimum_sum )); then
    printf 'error: --length (%d) is less than the sum of minimums (%d)\n' "${length}" "${minimum_sum}" >&2
    return 2
  fi

  spb_require_function get_random "${caller}" || return $?
  spb_require_function fisher_yates_shuffle "${caller}" || return $?
  spb_require_function enforce_max_consecutive "${caller}" || return $?

  for ((attempt = 1; attempt <= max_attempts; attempt++)); do
    active_combined=''
    upper_count=0
    lower_count=0
    digit_count=0
    special_count=0
    pool_upper=()
    pool_lower=()
    pool_digit=()
    pool_special=()
    pool_combined=()
    candidates=()
    result=()

    if [[ -n ${upper} ]]; then
      spb_string_to_array "${upper}" pool_upper
      fisher_yates_shuffle pool_upper || return $?
      active_combined+="${upper}"
    fi

    if [[ -n ${lower} ]]; then
      spb_string_to_array "${lower}" pool_lower
      fisher_yates_shuffle pool_lower || return $?
      active_combined+="${lower}"
    fi

    if [[ -n ${digit} ]]; then
      spb_string_to_array "${digit}" pool_digit
      fisher_yates_shuffle pool_digit || return $?
      active_combined+="${digit}"
    fi

    if [[ -n ${special} ]]; then
      spb_string_to_array "${special}" pool_special
      fisher_yates_shuffle pool_special || return $?
      active_combined+="${special}"
    fi

    spb_string_to_array "${active_combined}" pool_combined
    fisher_yates_shuffle pool_combined || return $?

    if (( min_upper > 0 )); then
      draw_output=$(get_random "${min_upper}" 0 "${#pool_upper[@]}") || return $?
      while IFS= read -r line; do
        candidates+=("${pool_upper[line]}")
      done <<< "${draw_output}"
    fi
    if (( min_lower > 0 )); then
      draw_output=$(get_random "${min_lower}" 0 "${#pool_lower[@]}") || return $?
      while IFS= read -r line; do
        candidates+=("${pool_lower[line]}")
      done <<< "${draw_output}"
    fi
    if (( min_digit > 0 )); then
      draw_output=$(get_random "${min_digit}" 0 "${#pool_digit[@]}") || return $?
      while IFS= read -r line; do
        candidates+=("${pool_digit[line]}")
      done <<< "${draw_output}"
    fi
    if (( min_special > 0 )); then
      draw_output=$(get_random "${min_special}" 0 "${#pool_special[@]}") || return $?
      while IFS= read -r line; do
        candidates+=("${pool_special[line]}")
      done <<< "${draw_output}"
    fi

    candidate_target=$((length * 2))
    fill_count=$((candidate_target - ${#candidates[@]}))
    if (( fill_count > 0 )); then
      draw_output=$(get_random "${fill_count}" 0 "${#pool_combined[@]}") || return $?
      while IFS= read -r line; do
        draw_index=$((10#${line}))
        candidates+=("${pool_combined[draw_index]}")
      done <<< "${draw_output}"
    fi

    fisher_yates_shuffle candidates || return $?

    if (( max_consecutive == 0 )); then
      result=("${candidates[@]:0:length}")
    else
      result=()
      enforce_max_consecutive candidates result "${length}" "${max_consecutive}"
      enforce_status=$?
      if (( enforce_status != 0 )); then
        if (( enforce_status != 1 )); then
          return "${enforce_status}"
        fi
        if (( attempt == max_attempts )); then
          printf 'error: generate_password: consecutive-class constraint unsatisfiable after %d attempts\n' "${max_attempts}" >&2
          return 1
        fi
        continue
      fi
    fi

    for character in "${result[@]}"; do
      character_class=$(spb_classify_char "${character}") || return 1
      case "${character_class}" in
        upper) (( upper_count++ )) ;;
        lower) (( lower_count++ )) ;;
        digit) (( digit_count++ )) ;;
        special) (( special_count++ )) ;;
      esac
    done

    if (( upper_count < min_upper || lower_count < min_lower || digit_count < min_digit || special_count < min_special )); then
      if (( attempt == max_attempts )); then
        if (( upper_count < min_upper )); then
          printf 'error: generate_password: minimums not satisfiable with current constraints (upper needs %d, got %d)\n' "${min_upper}" "${upper_count}" >&2
        elif (( lower_count < min_lower )); then
          printf 'error: generate_password: minimums not satisfiable with current constraints (lower needs %d, got %d)\n' "${min_lower}" "${lower_count}" >&2
        elif (( digit_count < min_digit )); then
          printf 'error: generate_password: minimums not satisfiable with current constraints (digit needs %d, got %d)\n' "${min_digit}" "${digit_count}" >&2
        else
          printf 'error: generate_password: minimums not satisfiable with current constraints (special needs %d, got %d)\n' "${min_special}" "${special_count}" >&2
        fi
        return 1
      fi
      continue
    fi

    password=$(spb_array_to_string result)
    printf '%s\n' "${password}" || {
      printf 'error: generate_password: failed to emit password\n' >&2
      return 1
    }
    return 0
  done
)
