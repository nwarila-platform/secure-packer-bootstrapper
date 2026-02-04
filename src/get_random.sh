get_random() (
  # Hardened random integer generator (Bash).
  #
  # Modes:
  #   get_random COUNT
  #     Emit COUNT integers in [0,256) (0..255), one per line.
  #
  #   get_random MIN MAX [COUNT]
  #     Emit COUNT (default 1) integers in [MIN,MAX), one per line.
  #     Constraints: 0 <= MIN < MAX <= 256.
  #
  # Success (exit 0) guarantees:
  #   - stdout contains exactly COUNT lines
  #   - each line is a base-10 integer
  #   - values are in the requested range
  #   - no stdout is produced until generation+validation completes (atomic stdout)
  #
  # Return codes:
  #   0   success
  #   1   runtime failure (/dev/urandom unreadable, od failed, parse failure, stdout write failed)
  #   2   usage / validation error
  #   127 missing dependency (od)

  # Best-effort hardening: disable tracing inside this generator.
  # Note: if the caller routes xtrace to stdout (BASH_XTRACEFD=1), even disabling
  # xtrace can still result in trace lines on stdout. Avoid that configuration.
  set +x

  # Defensive: disable pathname expansion (globbing).
  set -f

  # Resolve od to an absolute path (bypasses aliases/functions).
  local od_bin
  od_bin=$(type -P od 2>/dev/null) || {
    printf 'get_random: od not found in PATH\n' >&2
    return 127
  }

  # Preconditions.
  [[ -r /dev/urandom ]] || {
    printf 'get_random: /dev/urandom is not readable\n' >&2
    return 1
  }

  #region ------ [ Parse Argument 1 'count' ] --------------------------------------------- #

  # Initialize the string form with default of '1'
  local count_s=${1:-1}

  # Assert that arg1 is an integer between 1 and 999 (no leading zeros)
  if [[ ! $count_s =~ ^[1-9][0-9]{0,2}$ ]]; then
    printf 'error: arg1 (count) must be an integer between 1 and 999 (got %q)\n' "$count_s" >&2
    return 2
  fi

  # Parse as base-10 integer (defensive; avoids leading-zero/octal issues if rules change)
  local -i count=10#$count_s

  #endregion --- [ Parse Argument 1 'count' ] --------------------------------------------- #

  #region ------ [ Parse Argument 2 'min' ] --------------------------------------------- #

  # Initialize the string form with default of '0'
  local min_s=${2:-0}

  # Assert that arg2 is an integer between 0 and 254 (no leading zeros)
  if [[ ! $min_s =~ ^(25[0-4]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$ ]]; then
    printf 'error: arg2 (min) must be an integer between 0 and 254 (got %q)\n' "$min_s" >&2
    return 2
  fi

  # Parse as base-10 integer (defensive; avoids leading-zero/octal issues if rules change)
  local -i min=10#$min_s
  
  #endregion --- [ Parse Argument 2 'min' ] --------------------------------------------- #

  #region ------ [ Parse Argument 3 'max' ] --------------------------------------------- #

  # Initialize the string form with default of '0'
  local max_s=${2:-255}

  # Assert that arg3 is an integer between 0 and 254 (no leading zeros)
  if [[ ! $max_s =~ ^(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[1-9])$ ]]; then
    printf 'error: arg3 (max) must be an integer between 1 and 255 (got %q)\n' "$max_s" >&2
    return 2
  fi

  # Parse as base-10 integer (defensive; avoids leading-zero/octal issues if rules change)
  local -i max=10#$max_s

  # Assert that arg3 (max) is greater than arg2 (min) 
  if (( max <= min )); then
    printf 'error: arg3 (max) must be bigger than arg2 (min) (got max=%q min=%q)\n' "$max_s" "$min_s" >&2
    return 2
  fi

  #endregion --- [ Parse Argument 3 'max' ] --------------------------------------------- #

  #
  local -i span=$((max - min))
  local -i limit=$((256 - (256 % span)))  # rejection threshold

  # Buffer outputs in memory, then emit once complete.
  local -a out=()

  # Conservative: random(4) notes reads <=256 bytes won't be interrupted by signal handlers;
  # larger reads may return short or EINTR if interrupted.
  local -i CHUNK_MAX=256

  local -i produced=0 remaining chunk scanned
  local dump b
  local IFS=$' \t\n'

  while (( produced < want )); do
    remaining=$((want - produced))

    if (( span == 256 )); then
      chunk=$remaining
      (( chunk > CHUNK_MAX )) && chunk=$CHUNK_MAX
    else
      # Heuristic: read extra bytes to offset rejections; cap to CHUNK_MAX.
      if (( remaining > CHUNK_MAX / 4 )); then
        chunk=$CHUNK_MAX
      else
        chunk=$((remaining * 4))
        (( chunk < 64 )) && chunk=64
        (( chunk > CHUNK_MAX )) && chunk=$CHUNK_MAX
      fi
    fi

    # GNU od interprets -N similarly to -j: 0x.. => hex, leading 0 => octal, else decimal.
    # We only ever pass decimal without leading zeros.
    dump=$(LC_ALL=C "$od_bin" -v -A n -N "$chunk" -t u1 /dev/urandom) || {
      printf 'get_random: od failed\n' >&2
      return 1
    }

    scanned=0

    for b in $dump; do
      [[ $b =~ ^[0-9]+$ ]] || continue
      (( ++scanned ))

      # Defensive: od -t u1 should only produce 0..255.
      (( b <= 255 )) || {
        printf 'get_random: unexpected byte value from od: %s\n' "$b" >&2
        return 1
      }

      (( produced < want )) || continue

      if (( span == 256 )); then
        out[produced]=$b
        (( ++produced ))
      else
        # Rejection sampling avoids modulo bias.
        if (( b < limit )); then
          out[produced]=$((min + (b % span)))
          (( ++produced ))
        fi
      fi
    done

    # Fail closed if we didn't parse exactly CHUNK bytes.
    (( scanned == chunk )) || {
      printf 'get_random: short read/parse (requested %d bytes, got %d)\n' "$chunk" "$scanned" >&2
      return 1
    }
  done

  # Atomic emit: only now do we write to stdout.
  printf '%s\n' "${out[@]}" || {
    printf 'get_random: write to stdout failed\n' >&2
    return 1
  }
)
