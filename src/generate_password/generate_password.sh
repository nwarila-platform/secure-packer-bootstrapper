if [[ -z ${_SPB_BUNDLE_MODE:-} ]]; then
  _spb_generate_password_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || return 1
  # shellcheck source=../lib/common.sh
  . "${_spb_generate_password_dir}/../lib/common.sh"
  # shellcheck source=../get_random/get_random.sh
  . "${_spb_generate_password_dir}/../get_random/get_random.sh"
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
  local option
  local invalid_chars
  local duplicate_chars
  local active_combined=''
  local password
  local draw_output
  local draw_index
  local line
  local class_name
  local character
  local prev_class=''
  local selected_class
  local od_bin
  local urandom_path=${GET_RANDOM_URANDOM_PATH:-/dev/urandom}
  local byte_dump byte
  local -i length min_upper min_lower min_digit min_special max_consecutive minimum_sum
  local -i fill_count remaining_slots total_weight cumulative_weight
  local -i remaining_upper remaining_lower remaining_digit remaining_special
  local -i candidate_upper candidate_lower candidate_digit candidate_special
  local -i largest_count other_total
  local -i run_length=0
  local -i buffered_bytes=0 buffer_index=0 selector_draw scanned
  local -i upper_boundary lower_boundary digit_boundary
  local -i upper_cursor=0 lower_cursor=0 digit_cursor=0 special_cursor=0
  local -a pool_upper=()
  local -a pool_lower=()
  local -a pool_digit=()
  local -a pool_special=()
  local -a pool_combined=()
  local -a random_bytes=()
  local -a draw_upper=()
  local -a draw_lower=()
  local -a draw_digit=()
  local -a draw_special=()
  local -a result=()
  local IFS=$' \t\n'

  special=$(spb_default_special_chars)

  # Phase 1: parse the public command-line options.
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

  # Phase 2: validate numeric inputs before converting them to integers.
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

  # Phase 3: validate the characters assigned to each class.
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

  # Phase 4: verify the remaining configuration is satisfiable.
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

  # Phase 5: make sure the lower-level random generator was sourced.
  spb_require_function get_random "${caller}" || return $?

  od_bin=${GET_RANDOM_OD_BIN:-}
  if [[ -z ${od_bin} ]]; then
    od_bin=$(type -P od 2>/dev/null) || {
      printf 'error: generate_password requires od but it is not available\n' >&2
      return 127
    }
  elif [[ ! -x ${od_bin} ]]; then
    printf 'error: generate_password requires od but it is not available\n' >&2
    return 127
  fi

  if [[ ! -r ${urandom_path} ]]; then
    printf 'error: generate_password: %s is not readable\n' "${urandom_path}" >&2
    return 1
  fi

  # Draw one uniformly random index from [0, SPAN) using a buffered entropy
  # stream so the class-placement loop does not spawn `od` on every step.
  spb_generate_password_draw_index() {
    local -i span=${1}
    local -i acceptance_limit=$((256 - (256 % span)))

    while :; do
      if (( buffered_bytes - buffer_index < 1 )); then
        byte_dump=$("${od_bin}" -An -v -N 256 -t u1 "${urandom_path}" 2>/dev/null) || {
          printf 'error: generate_password: od failed while reading entropy\n' >&2
          return 1
        }

        buffer_index=0
        buffered_bytes=0
        scanned=0
        for byte in ${byte_dump}; do
          [[ ${byte} =~ ^[0-9]+$ ]] || continue
          if (( byte < 0 || byte > 255 )); then
            printf 'error: generate_password: unexpected byte value from od: %s\n' "${byte}" >&2
            return 1
          fi
          random_bytes[buffered_bytes]=${byte}
          (( buffered_bytes++ ))
          (( scanned++ ))
        done

        if (( scanned != 256 )); then
          printf 'error: generate_password: short read from od (requested %d bytes, got %d)\n' 256 "${scanned}" >&2
          return 1
        fi
      fi

      selector_draw=${random_bytes[buffer_index]}
      (( buffer_index++ ))
      if (( span == 256 || selector_draw < acceptance_limit )); then
        selector_draw=$((selector_draw % span))
        return 0
      fi
    done
  }

  # Phase 6: build the reusable class pools once.
  if [[ -n ${upper} ]]; then
    spb_string_to_array "${upper}" pool_upper
    active_combined+="${upper}"
  fi
  if [[ -n ${lower} ]]; then
    spb_string_to_array "${lower}" pool_lower
    active_combined+="${lower}"
  fi
  if [[ -n ${digit} ]]; then
    spb_string_to_array "${digit}" pool_digit
    active_combined+="${digit}"
  fi
  if [[ -n ${special} ]]; then
    spb_string_to_array "${special}" pool_special
    active_combined+="${special}"
  fi
  spb_string_to_array "${active_combined}" pool_combined
  upper_boundary=${#pool_upper[@]}
  lower_boundary=$((upper_boundary + ${#pool_lower[@]}))
  digit_boundary=$((lower_boundary + ${#pool_digit[@]}))

  # Phase 7: draw the exact multiset of characters we will place.
  draw_upper=()
  draw_lower=()
  draw_digit=()
  draw_special=()

  if (( min_upper > 0 )); then
    draw_output=$(get_random "${min_upper}" 0 "${#pool_upper[@]}") || return $?
    while IFS= read -r line; do
      draw_upper+=("${pool_upper[line]}")
    done <<< "${draw_output}"
  fi
  if (( min_lower > 0 )); then
    draw_output=$(get_random "${min_lower}" 0 "${#pool_lower[@]}") || return $?
    while IFS= read -r line; do
      draw_lower+=("${pool_lower[line]}")
    done <<< "${draw_output}"
  fi
  if (( min_digit > 0 )); then
    draw_output=$(get_random "${min_digit}" 0 "${#pool_digit[@]}") || return $?
    while IFS= read -r line; do
      draw_digit+=("${pool_digit[line]}")
    done <<< "${draw_output}"
  fi
  if (( min_special > 0 )); then
    draw_output=$(get_random "${min_special}" 0 "${#pool_special[@]}") || return $?
    while IFS= read -r line; do
      draw_special+=("${pool_special[line]}")
    done <<< "${draw_output}"
  fi

  fill_count=$((length - minimum_sum))
  if (( fill_count > 0 )); then
    draw_output=$(get_random "${fill_count}" 0 "${#pool_combined[@]}") || return $?
    while IFS= read -r line; do
      draw_index=$((10#${line}))
      character=${pool_combined[draw_index]}
      if (( draw_index < upper_boundary )); then
        draw_upper+=("${character}")
      elif (( draw_index < lower_boundary )); then
        draw_lower+=("${character}")
      elif (( draw_index < digit_boundary )); then
        draw_digit+=("${character}")
      else
        draw_special+=("${character}")
      fi
    done <<< "${draw_output}"
  fi

  # Phase 8: reject class-count mixes that can never satisfy the run limit.
  remaining_upper=${#draw_upper[@]}
  remaining_lower=${#draw_lower[@]}
  remaining_digit=${#draw_digit[@]}
  remaining_special=${#draw_special[@]}
  if (( max_consecutive > 0 )); then
    largest_count=${remaining_upper}
    (( remaining_lower > largest_count )) && largest_count=${remaining_lower}
    (( remaining_digit > largest_count )) && largest_count=${remaining_digit}
    (( remaining_special > largest_count )) && largest_count=${remaining_special}
    other_total=$((length - largest_count))
    if (( largest_count > max_consecutive * (other_total + 1) )); then
      printf 'error: generate_password: consecutive-class constraint unsatisfiable with current class counts\n' >&2
      return 1
    fi
  fi

  # Phase 9: place the pre-drawn characters directly into a valid sequence.
  result=()
  prev_class=''
  run_length=0
  while (( ${#result[@]} < length )); do
    remaining_slots=$((length - ${#result[@]}))
    total_weight=0

    for class_name in upper lower digit special; do
      case "${class_name}" in
        upper) cumulative_weight=${remaining_upper} ;;
        lower) cumulative_weight=${remaining_lower} ;;
        digit) cumulative_weight=${remaining_digit} ;;
        special) cumulative_weight=${remaining_special} ;;
      esac

      if (( cumulative_weight == 0 )); then
        continue
      fi
      if (( max_consecutive > 0 )) && [[ ${class_name} == "${prev_class}" ]] && (( run_length >= max_consecutive )); then
        continue
      fi

      candidate_upper=${remaining_upper}
      candidate_lower=${remaining_lower}
      candidate_digit=${remaining_digit}
      candidate_special=${remaining_special}
      case "${class_name}" in
        upper) (( candidate_upper-- )) ;;
        lower) (( candidate_lower-- )) ;;
        digit) (( candidate_digit-- )) ;;
        special) (( candidate_special-- )) ;;
      esac

      largest_count=${candidate_upper}
      (( candidate_lower > largest_count )) && largest_count=${candidate_lower}
      (( candidate_digit > largest_count )) && largest_count=${candidate_digit}
      (( candidate_special > largest_count )) && largest_count=${candidate_special}

      if (( max_consecutive > 0 )); then
        other_total=$(((remaining_slots - 1) - largest_count))
        if (( largest_count > max_consecutive * (other_total + 1) )); then
          continue
        fi
      fi

      total_weight=$((total_weight + cumulative_weight))
    done

    if (( total_weight == 0 )); then
      printf 'error: generate_password: consecutive-class constraint unsatisfiable with current class counts\n' >&2
      return 1
    fi

    spb_generate_password_draw_index "${total_weight}" || return $?
    draw_index=${selector_draw}
    cumulative_weight=0
    selected_class=''

    for class_name in upper lower digit special; do
      case "${class_name}" in
        upper) remaining_slots=${remaining_upper} ;;
        lower) remaining_slots=${remaining_lower} ;;
        digit) remaining_slots=${remaining_digit} ;;
        special) remaining_slots=${remaining_special} ;;
      esac

      if (( remaining_slots == 0 )); then
        continue
      fi
      if (( max_consecutive > 0 )) && [[ ${class_name} == "${prev_class}" ]] && (( run_length >= max_consecutive )); then
        continue
      fi

      candidate_upper=${remaining_upper}
      candidate_lower=${remaining_lower}
      candidate_digit=${remaining_digit}
      candidate_special=${remaining_special}
      case "${class_name}" in
        upper) (( candidate_upper-- )) ;;
        lower) (( candidate_lower-- )) ;;
        digit) (( candidate_digit-- )) ;;
        special) (( candidate_special-- )) ;;
      esac

      largest_count=${candidate_upper}
      (( candidate_lower > largest_count )) && largest_count=${candidate_lower}
      (( candidate_digit > largest_count )) && largest_count=${candidate_digit}
      (( candidate_special > largest_count )) && largest_count=${candidate_special}

      if (( max_consecutive > 0 )); then
        other_total=$(((length - ${#result[@]} - 1) - largest_count))
        if (( largest_count > max_consecutive * (other_total + 1) )); then
          continue
        fi
      fi

      cumulative_weight=$((cumulative_weight + remaining_slots))
      if (( draw_index < cumulative_weight )); then
        selected_class=${class_name}
        break
      fi
    done

    case "${selected_class}" in
      upper)
        character=${draw_upper[upper_cursor]}
        (( upper_cursor++ ))
        (( remaining_upper-- ))
        ;;
      lower)
        character=${draw_lower[lower_cursor]}
        (( lower_cursor++ ))
        (( remaining_lower-- ))
        ;;
      digit)
        character=${draw_digit[digit_cursor]}
        (( digit_cursor++ ))
        (( remaining_digit-- ))
        ;;
      special)
        character=${draw_special[special_cursor]}
        (( special_cursor++ ))
        (( remaining_special-- ))
        ;;
      *)
        printf 'error: generate_password: failed to choose the next character class\n' >&2
        return 1
        ;;
    esac

    result+=("${character}")
    if [[ ${selected_class} == "${prev_class}" ]]; then
      (( run_length++ ))
    else
      prev_class=${selected_class}
      run_length=1
    fi
  done

  # Success: emit exactly one finished password and nothing else.
  password=$(spb_array_to_string result)
  printf '%s\n' "${password}" || {
    printf 'error: generate_password: failed to emit password\n' >&2
    return 1
  }
  return 0
)
