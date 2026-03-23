# secure-packer-bootstrapper

`secure-packer-bootstrapper` is a modular Bash credential bootstrapper for
Packer, Kickstart, and Ansible-driven image builds. It generates a secure
deploy-user password, a Linux-compatible SHA-512 crypt password hash, a
passphrase-protected SSH keypair, and release-ready artifacts that can be
handed to downstream repos such as
`Secure-RockyLinux9-Template`.

## What It Builds

- An unbiased `/dev/urandom`-backed integer primitive: `get_random`
- A reusable Fisher-Yates array shuffle primitive
- A deterministic max-consecutive-class enforcer for generated passwords
- A configurable password generator with minimum-class guarantees
- A SHA-512 crypt password hash generator for Kickstart `--iscrypted` usage
- A passphrase-protected SSH keypair generator with FIPS-friendly defaults
- A top-level bootstrap command that emits:
  - `bootstrap.env`
  - `packer.auto.pkrvars.json`
  - password/hash/passphrase secret files
  - SSH private/public key files
  - a manifest describing the generated artifact set

## Repo Layout

```text
.
|-- bin/
|   `-- secure-packer-bootstrapper
|-- scripts/
|   |-- build-release.sh
|   |-- lint.sh
|   |-- test.sh
|   `-- verify.sh
|-- src/
|   |-- bootstrap_credentials/
|   |-- enforce_max_consecutive/
|   |-- fisher_yates_shuffle/
|   |-- generate_password/
|   |-- generate_password_hash/
|   |-- generate_ssh_keypair/
|   |-- get_random/
|   `-- lib/
`-- test/
```

## Local Usage

Run the full verification flow:

```bash
bash scripts/verify.sh
```

Generate a bootstrap artifact set into `artifacts/bootstrap`:

```bash
bin/secure-packer-bootstrapper --skip-agent
```

Generate a FIPS-enforced artifact set with a custom deploy user:

```bash
bin/secure-packer-bootstrapper \
  --deploy-user builder \
  --require-fips \
  --output-dir artifacts/bootstrap-fips
```

## Downstream Integration

The generated `bootstrap.env` file exports the variables that the current
`proxmox-packer-framework` contract expects today:

- `PKR_VAR_deploy_user_name`
- `PKR_VAR_deploy_user_password`
- `PKR_VAR_deploy_user_public_key`

It also exports `SPB_DEPLOY_USER_PASSWORD_HASH` so downstream Kickstart
templates can move from `--plaintext` to `--iscrypted` without losing the
plain password that Packer and Ansible still need for first-hop access.

## Quality Gates

- `bash -n` syntax validation across the repo
- Self-contained Bash unit/integration tests under `test/`
- Optional `shellcheck` integration when installed
- GitHub Actions verification on every push and pull request
- Standalone release-bundle build in `dist/secure-packer-bootstrapper.sh`
