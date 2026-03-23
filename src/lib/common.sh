if [[ -n ${_SPB_COMMON_SH_LOADED:-} ]]; then
  return 0 2>/dev/null || true
fi
readonly _SPB_COMMON_SH_LOADED=1

spb_require_function() {
  local function_name=${1:-}
  local caller=${2:-module}

  if [[ $(type -t "${function_name}" 2>/dev/null) != "function" ]]; then
    printf 'error: %s requires %s but it is not loaded\n' "${caller}" "${function_name}" >&2
    return 127
  fi
}

spb_require_command() {
  local command_name=${1:-}
  local caller=${2:-module}

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    printf 'error: %s requires %s but it is not installed\n' "${caller}" "${command_name}" >&2
    return 127
  fi
}

spb_is_indexed_array() {
  local variable_name=${1:-}
  local declaration

  declaration=$(declare -p "${variable_name}" 2>/dev/null) || return 1
  [[ ${declaration} == declare\ -a* ]]
}

spb_is_uint_literal() {
  [[ $# -eq 1 ]] && [[ ${1} =~ ^(0|[1-9][0-9]*)$ ]]
}

spb_ord() {
  if [[ $# -ne 1 || -z ${1} ]]; then
    return 1
  fi

  LC_ALL=C printf '%d' "'${1}"
}

spb_char_in_class() {
  local class_name=${1:-}
  local character=${2:-}
  local code

  if [[ -z ${character} ]]; then
    return 1
  fi

  code=$(spb_ord "${character}") || return 1

  case "${class_name}" in
    upper)
      (( code >= 65 && code <= 90 ))
      ;;
    lower)
      (( code >= 97 && code <= 122 ))
      ;;
    digit)
      (( code >= 48 && code <= 57 ))
      ;;
    special)
      (( code >= 33 && code <= 126 )) || return 1
      ! (( (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || (code >= 48 && code <= 57) ))
      ;;
    *)
      return 1
      ;;
  esac
}

spb_classify_char() {
  local character=${1:-}
  local code

  code=$(spb_ord "${character}") || return 1

  if (( code >= 65 && code <= 90 )); then
    printf 'upper\n'
  elif (( code >= 97 && code <= 122 )); then
    printf 'lower\n'
  elif (( code >= 48 && code <= 57 )); then
    printf 'digit\n'
  else
    printf 'special\n'
  fi
}

spb_string_to_array() {
  local input_string=${1-}
  local output_name=${2:-}
  local -n output_ref=${output_name}
  local -i index

  output_ref=()

  for ((index = 0; index < ${#input_string}; index++)); do
    output_ref+=("${input_string:index:1}")
  done
}

spb_array_to_string() {
  local array_name=${1:-}
  local -n array_ref=${array_name}

  printf '%s' "${array_ref[@]}"
}

spb_find_duplicate_chars() {
  local input_string=${1-}
  local duplicates=''
  local character
  local -i index
  declare -A seen=()
  declare -A reported=()

  for ((index = 0; index < ${#input_string}; index++)); do
    character=${input_string:index:1}
    if [[ -n ${seen["${character}"]+x} ]]; then
      if [[ -z ${reported["${character}"]+x} ]]; then
        duplicates+="${character}"
        reported["${character}"]=1
      fi
      continue
    fi
    seen["${character}"]=1
  done

  printf '%s' "${duplicates}"
}

spb_filter_chars() {
  local input_string=${1-}
  local exclude_string=${2-}
  local output=''
  local character
  local -i index
  declare -A excluded=()

  for ((index = 0; index < ${#exclude_string}; index++)); do
    excluded["${exclude_string:index:1}"]=1
  done

  for ((index = 0; index < ${#input_string}; index++)); do
    character=${input_string:index:1}
    if [[ -z ${excluded["${character}"]+x} ]]; then
      output+="${character}"
    fi
  done

  printf '%s' "${output}"
}

spb_invalid_chars_for_class() {
  local class_name=${1:-}
  local input_string=${2-}
  local invalid=''
  local character
  local -i index
  declare -A reported=()

  for ((index = 0; index < ${#input_string}; index++)); do
    character=${input_string:index:1}
    if ! spb_char_in_class "${class_name}" "${character}"; then
      if [[ -z ${reported["${character}"]+x} ]]; then
        invalid+="${character}"
        reported["${character}"]=1
      fi
    fi
  done

  printf '%s' "${invalid}"
}

spb_default_special_chars() {
  printf '%s' "!@#\$%^&*()-_=+[]{}|;:',.<>?/\\\`~"
}

spb_shell_quote() {
  local value=${1-}
  printf "'%s'" "${value//\'/\'\"\'\"\'}"
}

spb_json_escape() {
  local value=${1-}

  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}

  printf '%s' "${value}"
}
