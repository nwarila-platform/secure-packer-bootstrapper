# Security Policy

## Supported Surface

Security issues in this repository should be reported when they affect:

- the generated credential or key material
- the Bash implementation under `src/`
- release artifacts published from this repo
- GitHub workflows under `.github/workflows/`

This repo does not guarantee security outcomes for downstream operating-system
images by itself. Report downstream Packer, Kickstart, Ansible, or image
hardening issues to the downstream repository that owns that surface.

## Reporting A Vulnerability

Please do not open a public issue for an unpatched security bug.

Instead, report it privately to the maintainers through the repository security
advisory flow if available, or by the maintainer contact channel documented in
the repository profile.

When reporting, include:

- affected file or workflow path
- the observed behavior
- expected secure behavior
- reproduction steps
- impact and any known workaround

## Disclosure Expectations

The goal is to acknowledge good-faith reports promptly, validate impact, and
coordinate a fix before public disclosure when that is reasonable.

## Scope Notes

- Generated hashes, plaintext passwords, passphrases, manifests, and bootstrap
  metadata should all be treated as sensitive.
- This repo prefers GitHub-native masked environment variables and temporary
  runner storage for CI consumers.
- Supply-chain issues involving release integrity or workflow dependencies are
  in scope for this policy.
