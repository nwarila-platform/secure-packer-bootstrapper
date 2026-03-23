# Requirements: `bootstrap_credentials`

## Overview

`bootstrap_credentials` is the repo-level orchestrator. It generates the
deploy-user password, password hash, SSH key passphrase, SSH keypair, and the
artifact files that downstream Packer/Kickstart repos consume.

## Function Signature

```bash
bootstrap_credentials [OPTIONS]
```

## Supported Options

- `--deploy-user NAME`
- `--output-dir DIR`
- `--password-length N`
- `--passphrase-length N`
- `--ssh-key-type rsa|ecdsa`
- `--ssh-key-bits N`
- `--ssh-key-name BASENAME`
- `--ssh-key-comment TEXT`
- `--require-fips`
- `--skip-agent`

## Required Artifacts

- `secrets/deploy_user_password.txt`
- `secrets/deploy_user_password.sha512crypt`
- `secrets/ssh_key_passphrase.txt`
- `ssh/<keyname>`
- `ssh/<keyname>.pub`
- `bootstrap.env`
- `packer.auto.pkrvars.json`
- `manifest.json`

## Behavioral Rules

- `bootstrap.env` must export the current downstream variables:
  - `PKR_VAR_deploy_user_name`
  - `PKR_VAR_deploy_user_password`
  - `PKR_VAR_deploy_user_public_key`
- `bootstrap.env` must also export `SPB_DEPLOY_USER_PASSWORD_HASH`
- `packer.auto.pkrvars.json` must contain only currently-supported Packer vars
- `--require-fips` must fail if the host is not running in FIPS mode
- Unless `--skip-agent` is set, the generated private key should be loaded into
  `ssh-agent`

## Exit Codes

- `0`: success
- `1`: runtime failure
- `2`: usage error
- `127`: missing dependency
