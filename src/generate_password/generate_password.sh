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
  local password
  local class_name
  local character
  local od_bin
  local urandom_path=${GET_RANDOM_URANDOM_PATH:-/dev/urandom}
  local byte_dump byte
  local -i length min_upper min_lower min_digit min_special max_consecutive minimum_sum
  local -i remaining_slots next_prev_class next_run_length
  local -i candidate_class_id
  local -i buffered_bytes=0 buffer_index=0 selector_draw scanned
  local -i current_prev_class=0 current_run_length=0
  local -i next_need_upper next_need_lower next_need_digit next_need_special
  local can_complete_result
  local -a pool_upper=()
  local -a pool_lower=()
  local -a pool_digit=()
  local -a pool_special=()
  local -a combined_pool=()
  local -a combined_class_ids=()
  local -a random_bytes=()
  local -A feasibility_cache=()
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

  spb_generate_password_can_complete() {
    local target_key
    local state_key
    local child_key
    local found_completion
    local -a stack_slots=()
    local -a stack_need_upper=()
    local -a stack_need_lower=()
    local -a stack_need_digit=()
    local -a stack_need_special=()
    local -a stack_prev_class=()
    local -a stack_prev_run=()
    local -a stack_stage=()
    local -i stack_size=0 stack_index
    local -i slots need_upper need_lower need_digit need_special prev_class_id prev_run_length
    local -i class_id pool_size next_run
    local -i child_need_upper child_need_lower child_need_digit child_need_special

    target_key="${1}|${2}|${3}|${4}|${5}|${6}|${7}"
    if [[ -v feasibility_cache["${target_key}"] ]]; then
      can_complete_result=${feasibility_cache["${target_key}"]}
      return 0
    fi

    stack_slots[0]=${1}
    stack_need_upper[0]=${2}
    stack_need_lower[0]=${3}
    stack_need_digit[0]=${4}
    stack_need_special[0]=${5}
    stack_prev_class[0]=${6}
    stack_prev_run[0]=${7}
    stack_stage[0]=0
    stack_size=1

    while (( stack_size > 0 )); do
      stack_index=$((stack_size - 1))
      slots=${stack_slots[stack_index]}
      need_upper=${stack_need_upper[stack_index]}
      need_lower=${stack_need_lower[stack_index]}
      need_digit=${stack_need_digit[stack_index]}
      need_special=${stack_need_special[stack_index]}
      prev_class_id=${stack_prev_class[stack_index]}
      prev_run_length=${stack_prev_run[stack_index]}
      state_key="${slots}|${need_upper}|${need_lower}|${need_digit}|${need_special}|${prev_class_id}|${prev_run_length}"

      if [[ -v feasibility_cache["${state_key}"] ]]; then
        (( stack_size-- ))
        continue
      fi

      if (( stack_stage[stack_index] == 0 )); then
        if (( need_upper + need_lower + need_digit + need_special > slots )); then
          feasibility_cache["${state_key}"]=0
          (( stack_size-- ))
          continue
        fi

        if (( slots > 0 && max_consecutive == 0 )); then
          feasibility_cache["${state_key}"]=0
          (( stack_size-- ))
          continue
        fi

        if (( slots == 0 )); then
          if (( need_upper == 0 && need_lower == 0 && need_digit == 0 && need_special == 0 )); then
            feasibility_cache["${state_key}"]=1
          else
            feasibility_cache["${state_key}"]=0
          fi
          (( stack_size-- ))
          continue
        fi

        stack_stage[stack_index]=1
        for class_id in 1 2 3 4; do
          case "${class_id}" in
            1) pool_size=${#pool_upper[@]} ;;
            2) pool_size=${#pool_lower[@]} ;;
            3) pool_size=${#pool_digit[@]} ;;
            4) pool_size=${#pool_special[@]} ;;
          esac

          if (( pool_size == 0 )); then
            continue
          fi
          if (( class_id == prev_class_id && prev_run_length >= max_consecutive )); then
            continue
          fi

          child_need_upper=${need_upper}
          child_need_lower=${need_lower}
          child_need_digit=${need_digit}
          child_need_special=${need_special}
          case "${class_id}" in
            1) (( child_need_upper > 0 )) && (( child_need_upper-- )) ;;
            2) (( child_need_lower > 0 )) && (( child_need_lower-- )) ;;
            3) (( child_need_digit > 0 )) && (( child_need_digit-- )) ;;
            4) (( child_need_special > 0 )) && (( child_need_special-- )) ;;
          esac

          if (( class_id == prev_class_id )); then
            next_run=$((prev_run_length + 1))
          else
            next_run=1
          fi

          child_key="$((slots - 1))|${child_need_upper}|${child_need_lower}|${child_need_digit}|${child_need_special}|${class_id}|${next_run}"
          if [[ -v feasibility_cache["${child_key}"] ]]; then
            continue
          fi

          stack_slots[stack_size]=$((slots - 1))
          stack_need_upper[stack_size]=${child_need_upper}
          stack_need_lower[stack_size]=${child_need_lower}
          stack_need_digit[stack_size]=${child_need_digit}
          stack_need_special[stack_size]=${child_need_special}
          stack_prev_class[stack_size]=${class_id}
          stack_prev_run[stack_size]=${next_run}
          stack_stage[stack_size]=0
          (( stack_size++ ))
        done
        continue
      fi

      found_completion=0
      for class_id in 1 2 3 4; do
        case "${class_id}" in
          1) pool_size=${#pool_upper[@]} ;;
          2) pool_size=${#pool_lower[@]} ;;
          3) pool_size=${#pool_digit[@]} ;;
          4) pool_size=${#pool_special[@]} ;;
        esac

        if (( pool_size == 0 )); then
          continue
        fi
        if (( class_id == prev_class_id && prev_run_length >= max_consecutive )); then
          continue
        fi

        child_need_upper=${need_upper}
        child_need_lower=${need_lower}
        child_need_digit=${need_digit}
        child_need_special=${need_special}
        case "${class_id}" in
          1) (( child_need_upper > 0 )) && (( child_need_upper-- )) ;;
          2) (( child_need_lower > 0 )) && (( child_need_lower-- )) ;;
          3) (( child_need_digit > 0 )) && (( child_need_digit-- )) ;;
          4) (( child_need_special > 0 )) && (( child_need_special-- )) ;;
        esac

        if (( class_id == prev_class_id )); then
          next_run=$((prev_run_length + 1))
        else
          next_run=1
        fi

        child_key="$((slots - 1))|${child_need_upper}|${child_need_lower}|${child_need_digit}|${child_need_special}|${class_id}|${next_run}"
        if [[ ${feasibility_cache["${child_key}"]} == 1 ]]; then
          found_completion=1
          break
        fi
      done

      feasibility_cache["${state_key}"]=${found_completion}
      (( stack_size-- ))
    done

    can_complete_result=${feasibility_cache["${target_key}"]}
    return 0
  }

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
    for character in "${pool_upper[@]}"; do
      combined_pool[${#combined_pool[@]}]=${character}
      combined_class_ids[${#combined_class_ids[@]}]=1
    done
  fi
  if [[ -n ${lower} ]]; then
    spb_string_to_array "${lower}" pool_lower
    for character in "${pool_lower[@]}"; do
      combined_pool[${#combined_pool[@]}]=${character}
      combined_class_ids[${#combined_class_ids[@]}]=2
    done
  fi
  if [[ -n ${digit} ]]; then
    spb_string_to_array "${digit}" pool_digit
    for character in "${pool_digit[@]}"; do
      combined_pool[${#combined_pool[@]}]=${character}
      combined_class_ids[${#combined_class_ids[@]}]=3
    done
  fi
  if [[ -n ${special} ]]; then
    spb_string_to_array "${special}" pool_special
    for character in "${pool_special[@]}"; do
      combined_pool[${#combined_pool[@]}]=${character}
      combined_class_ids[${#combined_class_ids[@]}]=4
    done
  fi

  if (( ${#combined_pool[@]} == 0 )); then
    printf 'error: generate_password: at least one character class must remain non-empty\n' >&2
    return 2
  fi

  spb_generate_password_can_complete \
    "${length}" \
    "${min_upper}" \
    "${min_lower}" \
    "${min_digit}" \
    "${min_special}" \
    0 \
    0 || return 1
  if [[ ${can_complete_result} != 1 ]]; then
    printf 'error: generate_password: consecutive-class constraint unsatisfiable with current class counts\n' >&2
    return 1
  fi

  # Phase 7-9: draw candidate passwords uniformly from the active character
  # set and restart early whenever a prefix can no longer reach a valid
  # completion. This keeps the accepted output uniform over the valid password
  # space without relying on heuristic placement.
  while :; do
    password=''
    remaining_slots=${length}
    current_prev_class=0
    current_run_length=0
    next_need_upper=${min_upper}
    next_need_lower=${min_lower}
    next_need_digit=${min_digit}
    next_need_special=${min_special}

    while (( remaining_slots > 0 )); do
      spb_generate_password_draw_index "${#combined_pool[@]}" || return $?
      character=${combined_pool[selector_draw]}
      candidate_class_id=${combined_class_ids[selector_draw]}

      if (( candidate_class_id == current_prev_class )); then
        next_run_length=$((current_run_length + 1))
      else
        next_run_length=1
      fi
      if (( candidate_class_id == current_prev_class && current_run_length >= max_consecutive )); then
        break
      fi

      case "${candidate_class_id}" in
        1)
          next_prev_class=1
          (( next_need_upper > 0 )) && (( next_need_upper-- ))
          ;;
        2)
          next_prev_class=2
          (( next_need_lower > 0 )) && (( next_need_lower-- ))
          ;;
        3)
          next_prev_class=3
          (( next_need_digit > 0 )) && (( next_need_digit-- ))
          ;;
        4)
          next_prev_class=4
          (( next_need_special > 0 )) && (( next_need_special-- ))
          ;;
      esac

      spb_generate_password_can_complete \
        "$((remaining_slots - 1))" \
        "${next_need_upper}" \
        "${next_need_lower}" \
        "${next_need_digit}" \
        "${next_need_special}" \
        "${next_prev_class}" \
        "${next_run_length}" || return 1
      if [[ ${can_complete_result} != 1 ]]; then
        break
      fi

      password+="${character}"
      current_prev_class=${next_prev_class}
      current_run_length=${next_run_length}
      (( remaining_slots-- ))
    done

    if (( remaining_slots == 0 )); then
      break
    fi
  done

  printf '%s\n' "${password}" || {
    printf 'error: generate_password: failed to emit password\n' >&2
    return 1
  }
  return 0
)
