if [[ -z ${_SPB_BUNDLE_MODE:-} ]]; then
  _spb_fisher_yates_shuffle_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || return 1
  # shellcheck source=../lib/common.sh
  . "${_spb_fisher_yates_shuffle_dir}/../lib/common.sh"
  # shellcheck source=../get_random/get_random.sh
  . "${_spb_fisher_yates_shuffle_dir}/../get_random/get_random.sh"
  unset _spb_fisher_yates_shuffle_dir
fi

fisher_yates_shuffle() {
  set +x
  set -f

  local caller='fisher_yates_shuffle'
  local array_name
  local -i index item_count
  local random_index
  local swap_value

  if (( $# != 1 )); then
    if (( $# == 0 )); then
      printf 'error: fisher_yates_shuffle requires an array name argument\n' >&2
    else
      printf 'error: fisher_yates_shuffle takes exactly 1 argument (got %d)\n' "$#" >&2
    fi
    return 2
  fi

  spb_require_function get_random "${caller}" || return $?

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

  if (( item_count <= 1 )); then
    return 0
  fi

  for ((index = item_count - 1; index > 0; index--)); do
    random_index=$(get_random 1 0 $((index + 1))) || {
      printf 'error: fisher_yates_shuffle: get_random failed\n' >&2
      return 1
    }

    swap_value=${array_ref[index]}
    array_ref[index]=${array_ref[random_index]}
    array_ref[random_index]=${swap_value}
  done
}
