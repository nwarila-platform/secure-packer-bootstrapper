# Requirements: `generate_ssh_keypair`

## Overview

`generate_ssh_keypair` creates a passphrase-protected SSH keypair for image
build automation. The default profile is FIPS-friendly and compatibility-first:
RSA with a 4096-bit modulus and the modern OpenSSH private-key format.

## Function Signature

```bash
generate_ssh_keypair \
  --output-dir DIR \
  --name BASENAME \
  --passphrase VALUE \
  [--comment TEXT] \
  [--type rsa|ecdsa] \
  [--bits N] \
  [--force]
```

## Defaults

- `--type rsa`
- `--bits 4096` for RSA
- `--bits 384` for ECDSA
- `--comment builder@secure-packer-bootstrapper`

## Output Contract

On success, stdout prints:

1. Private key path
2. Public key path

## Validation Rules

- `--output-dir` is required
- `--passphrase` is required
- RSA bits must be between `3072` and `8192`
- ECDSA bits must be one of `256`, `384`, or `521`
- Existing key files must not be overwritten unless `--force` is set

## Exit Codes

- `0`: success
- `1`: runtime failure
- `2`: usage error
- `127`: missing dependency
