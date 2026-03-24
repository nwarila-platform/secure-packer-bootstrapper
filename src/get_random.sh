_spb_wrapper_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || return 1
# shellcheck source=get_random/get_random.sh
. "${_spb_wrapper_dir}/get_random/get_random.sh"
unset _spb_wrapper_dir
