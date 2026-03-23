# Requirements: `generate_password_hash`

## Overview

`generate_password_hash` turns a plaintext password into a Linux-compatible
SHA-512 crypt hash suitable for Kickstart `user --iscrypted` usage.

## Function Signature

```bash
generate_password_hash [--password VALUE] [--salt-length N]
```

If `--password` is omitted, the function reads one password line from stdin.

## Defaults

- Algorithm: SHA-512 crypt via `openssl passwd -6`
- Salt length: `16`

## Validation Rules

- `--salt-length` must be an integer between `8` and `16`
- A password value must be supplied either with `--password` or stdin

## Security Rules

- Salt characters must come from `get_random`
- The function must never pass the password to `openssl` on the command line
- The hash must be written only to stdout on success

## Exit Codes

- `0`: success
- `1`: runtime failure
- `2`: usage error
- `127`: missing dependency
