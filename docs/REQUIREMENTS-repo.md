# Repository Requirements Ledger

## Purpose

This file is the authoritative ledger for cross-cutting repository
requirements. It exists because this repository is more than one thing at
once:

- a Bash CLI entrypoint
- a set of sourceable Bash modules
- a generated single-file release bundle
- a downstream artifact producer for Packer, Kickstart, and Ansible consumers
- a GitHub-managed CI/CD and release surface

Module-local behavior belongs in `src/<module>/REQUIREMENTS.md`.
Repository-wide classification, evidence policy, portability language, release
surface, and audit-governance requirements belong here.

## Artifact Classification

Current-state repository classification, based on repository evidence:

- Primary executable artifact: a Bash CLI invoked through
  `bin/secure-packer-bootstrapper`.
- Source artifact: a sourceable Bash module tree under `src/`, with shared
  helpers under `src/lib/`.
- Generated distribution artifact: the single-file bundle
  `dist/secure-packer-bootstrapper.sh`, assembled from `src/` by
  `scripts/build-release.sh`.
- Downstream integration artifact: a minimal bootstrap output set composed of
  generated secret values, SSH private/public key files, and downstream-facing
  contract documentation.
- CI/CD artifact surface: GitHub Actions workflows that verify the repo and
  publish release assets.

The following artifact types are not supported by current repository evidence
and therefore are out of scope unless the repo is explicitly reclassified
later:

- Packer plugin
- Terraform module
- generic framework template
- GitHub Action implementation
- POSIX `sh` library
- non-Linux Unix portability target

## Supported Platform Contract

Current evidence supports the following contract:

- Operating system versions with current automated execution evidence:
  - Ubuntu 22.04 LTS and 24.04 LTS
- Downstream consumer focus:
  - Rocky Linux 8, 9, and 10 image-build repos
  - Ubuntu 22.04 LTS and 24.04 LTS image-build repos
- Shell language: GNU Bash, not generic POSIX `sh`.
- Minimum Bash baseline: Bash 4.3 or newer.
  Reason: the implementation relies on namerefs (`local -n`), associative
  arrays (`declare -A`), `mapfile`, Bash regex matching, and `BASH_SOURCE`.
- Non-Linux environments are not part of the supported contract unless they
  are separately documented and verified.
- Support claims are bounded by current verification evidence. The repo does
  not claim every future release in a distro family by default.
- The repo intentionally does not treat container-only Rocky checks as
  equivalent to GitHub-hosted Ubuntu runner evidence. Rocky is therefore a
  downstream target context rather than a CI-verified execution-host claim for
  this repository until first-class Rocky runner evidence exists.
- External command requirements are module-specific and must remain documented
  in the nearest module ledger, but the repo-wide contract must still say that
  Linux command availability and file-path assumptions are part of the support
  envelope.

This contract is intentionally narrower than "portable shell." The repo makes
deliberate use of Bash-only features, and that is acceptable so long as the
support statement stays truthful.

## Standards Register

| Standard family | Applicability | Why |
|---|---|---|
| GNU Bash language and manual | Applicable | The implementation, entrypoint, scripts, and tests are written for Bash and use Bash-only features. |
| Linux kernel and Linux man-pages | Applicable | Runtime behavior depends on Linux paths and interfaces such as `/dev/urandom`. |
| GNU Coreutils and related GNU/Linux userland documentation | Applicable | Runtime modules, scripts, and tests invoke GNU/Linux command-line tools such as `od`, `dirname`, `cat`, `chmod`, `date`, `find`, `grep`, `mkdir`, `mktemp`, `mv`, `rm`, `sed`, `sha256sum`, and `sort`. |
| OpenSSH command documentation | Applicable | The repo invokes `ssh-keygen` and emits SSH key material for downstream consumers. |
| OpenSSL command documentation | Applicable | The password-hash module invokes `openssl passwd`. |
| GitHub Actions and GitHub Releases documentation | Applicable | CI verification, release publication, and downstream workflow guidance depend on GitHub workflow, secret-handling, and masking behavior. |
| GitHub-hosted runners documentation | Applicable | CI and release workflows depend on `ubuntu-latest`, GitHub-hosted runner behavior, and preinstalled `gh`. |
| Red Hat / Rocky vendor hardening and install docs | Partially applicable | These govern downstream Kickstart and FIPS interpretation, and they constrain what this repo may truthfully claim, but they do not redefine this repo as an OS hardening benchmark. |
| Packer documentation | Partially applicable | Packer governs the meaning of downstream variable and var-file conventions, not the internal Bash implementation. |
| Ansible documentation | Partially applicable | Ansible governs downstream SSH/become integration semantics, not the internal Bash implementation. |
| POSIX shell specification | Not applicable as the primary shell standard | The repo does not claim POSIX `sh` compatibility and intentionally uses Bash-only features. |
| Terraform module standards | Not applicable | There is no Terraform module surface in repository evidence. |
| Packer plugin standards | Not applicable | There is no Go plugin, plugin SDK, or Packer plugin packaging surface in repository evidence. |
| STIG / CIS benchmark catalogs | Not directly applicable to this repo's code | They apply to downstream built systems and to claim language, not to this repo as a standalone Bash bootstrapper. |

## Source Register

- `SR-1`: GNU Bash Reference Manual.  
  https://www.gnu.org/software/bash/manual/bash.html
- `SR-2`: Chet Ramey, "Bash-4.3 available for FTP" (official Bash release
  announcement; notes `nameref` support as a Bash 4.3 feature).  
  https://lists.gnu.org/archive/html/bug-bash/2014-02/msg00081.html
- `SR-3`: Linux `random(7)` manual page.  
  https://man7.org/linux/man-pages/man7/random.7.html
- `SR-4`: GitHub Docs, "Store and share data with workflow artifacts".  
  https://docs.github.com/actions/writing-workflows/choosing-what-your-workflow-does/storing-and-sharing-data-from-a-workflow
- `SR-5`: GitHub Docs, "About releases".  
  https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases
- `SR-6`: GitHub Docs, "Use GITHUB_TOKEN for authentication in workflows".  
  https://docs.github.com/en/actions/configuring-and-managing-workflows/authenticating-with-the-github_token
- `SR-7`: Red Hat Enterprise Linux 9 Security hardening, "Switching the system
  to FIPS mode".  
  https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/epub/security_hardening/switching-the-system-to-fips-mode_using-the-system-wide-cryptographic-policies
- `SR-8`: OpenSSL Documentation, `openssl-passwd`.  
  https://docs.openssl.org/3.3/man1/openssl-passwd/
- `SR-9`: `ssh-keygen(1)` Linux manual page for Portable OpenSSH.  
  https://www.man7.org/linux/man-pages/man1/ssh-keygen.1@@openssh.html
- `SR-10`: `ssh-agent(1)` Linux manual page for Portable OpenSSH.  
  https://www.man7.org/linux/man-pages/man1/ssh-agent.1.html
- `SR-11`: HashiCorp Packer documentation, "Input Variables and local
  variables".  
  https://developer.hashicorp.com/packer/guides/hcl/variables
- `SR-12`: Red Hat Enterprise Linux automatic installation documentation,
  `user --iscrypted` / `--plaintext`.  
  https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html-single/automatically_installing_rhel/index
- `SR-13`: Ansible SSH connection documentation.  
  https://docs.ansible.com/ansible/7/collections/ansible/builtin/ssh_connection.html
- `SR-14`: Local repository standard, `docs/STUDENT-FIRST-STANDARDS.md`.  
  Repository-local source
- `SR-15`: GNU Coreutils manual.  
  https://www.gnu.org/software/coreutils/manual/coreutils.html
- `SR-16`: GNU Coreutils manual, `od` invocation.  
  https://www.gnu.org/software/coreutils/manual/html_node/od-invocation.html
- `SR-17`: `ssh-add(1)` Linux manual page for Portable OpenSSH.  
  https://man7.org/linux/man-pages/man1/ssh-add.1.html
- `SR-18`: `setsid(1)` Linux manual page from util-linux.  
  https://www.man7.org/linux/man-pages/man1/setsid.1.html
- `SR-19`: GitHub Docs, "Using GitHub CLI in workflows".  
  https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-github-cli
- `SR-20`: GitHub Docs, "GitHub-hosted runners".  
  https://docs.github.com/en/actions/concepts/runners/github-hosted-runners
- `SR-21`: GitHub Docs, "GitHub-hosted runners reference".  
  https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- `SR-22`: GitHub Docs, "Running variations of jobs in a workflow".  
  https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/run-job-variations
- `SR-23`: Red Hat Enterprise Linux 9 Security hardening, "Using the
  system-wide cryptographic policies".  
  https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/security_hardening/using-the-system-wide-cryptographic-policies_security-hardening
- `SR-24`: Red Hat Enterprise Linux 9 Security hardening, "Switching RHEL to
  FIPS mode".  
  https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/security_hardening/switching-rhel-to-fips-mode_security-hardening
- `SR-25`: GitHub Docs, "Using secrets in GitHub Actions".  
  https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets
- `SR-26`: GitHub Docs, "Workflow commands for GitHub Actions".  
  https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands
- `SR-27`: Linux `proc_pid_cmdline(5)` manual page.  
  https://man7.org/linux/man-pages/man5/proc_pid_cmdline.5.html
- `SR-28`: Linux `proc_pid_environ(5)` manual page.  
  https://man7.org/linux/man-pages/man5/proc_pid_environ.5.html
- `SR-29`: EditorConfig Specification.  
  https://spec.editorconfig.org/
- `SR-30`: GitHub Docs, "Contexts reference".  
  https://docs.github.com/en/actions/learn-github-actions/contexts
- `SR-31`: GitHub Docs, "Security hardening for GitHub Actions".  
  https://docs.github.com/en/actions/how-tos/security-for-github-actions/security-guides/security-hardening-for-github-actions
- `SR-32`: GitHub Docs, "Workflow syntax for GitHub Actions".  
  https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions
- `SR-33`: GitHub Docs, "About code owners".  
  https://docs.github.com/github/creating-cloning-and-archiving-repositories/about-code-owners
- `SR-34`: GitHub Docs, "Adding a security policy to your repository".  
  https://docs.github.com/en/code-security/getting-started/adding-a-security-policy-to-your-repository
- `SR-35`: GitHub Docs, "Using artifact attestations to establish provenance for builds".  
  https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations/using-artifact-attestations-to-establish-provenance-for-builds
- `SR-36`: GitHub Docs, "Immutable releases".  
  https://docs.github.com/code-security/supply-chain-security/understanding-your-software-supply-chain/immutable-releases
- `SR-37`: GitHub Docs, "Verifying the integrity of a release".  
  https://docs.github.com/en/code-security/supply-chain-security/understanding-your-software-supply-chain/verifying-the-integrity-of-a-release?tool=webui

## Ledger Placement Strategy

- Repository-wide requirements belong in this file.
- Module behavior belongs in `src/<module>/REQUIREMENTS.md`.
- Cross-cutting docs under `docs/` may explain design, but they are not
  authoritative ledgers unless they explicitly say so.
- A concern should have one authoritative ledger. Legacy copies must be marked
  as superseded rather than silently diverging.

## Status, Priority, and Severity Vocabulary

- `Status`
  - `Open`: accepted requirement, not yet fully satisfied
  - `Partial`: some supporting evidence exists, but the repo-wide contract is
    still incomplete or inconsistent
  - `Satisfied`: implemented and verified in current state
  - `Superseded`: replaced by a newer authoritative requirement or ledger
  - `Rejected`: considered and intentionally declined with reasons recorded
- `Priority`
  - `P1`: should be addressed before making or expanding strong claims
  - `P2`: important for auditability and long-term maintenance
  - `P3`: useful cleanup or clarity work
- `Severity`
  - `High`: can materially mislead security, portability, or compliance review
  - `Medium`: weakens auditability or reviewer confidence
  - `Low`: readability or process issue with limited risk

## REQ-REPO-001

Status: Satisfied
Priority: P1
Severity: High
Domain: artifact-classification
Applies to: repository identity, scope boundaries, and future audit framing
Affected files/lines:
- `README.md:3-9`
- `README.md:36-46`
- `README.md:97-140`
- `bin/secure-packer-bootstrapper:1-10`
- `scripts/build-release.sh:1-33`
- `.github/workflows/release-artifact.yml:1-47`
- `src/bootstrap_credentials/REQUIREMENTS.md:5-67`
Authoritative sources:
- `SR-1`
- `SR-4`
- `SR-5`
Repository evidence:
- `README.md` describes a modular Bash project that generates downstream build
  artifacts.
- `bin/secure-packer-bootstrapper` is a Bash entrypoint that sources
  `bootstrap_credentials.sh`.
- `scripts/build-release.sh` assembles a single-file Bash distribution.
- `.github/workflows/release-artifact.yml` publishes release assets from the
  bundled script.
Applicability analysis:
- This repo has multiple review surfaces, and later standards selection depends
  on classifying them correctly.
- Plugin, Terraform-module, and generic-template standards would be misleading
  unless the repo is first reclassified into those artifact types.
Requirement:
- The repository MUST maintain an explicit artifact classification and scope
  boundary that identifies it as a Bash CLI, a sourceable Bash module library,
  a generated single-file distribution, and a downstream artifact producer, and
  MUST explicitly reject non-applicable artifact types unless new evidence is
  added.
Rationale:
- Standards selection is only trustworthy when the repo is classified
  correctly before any audit imports outside rules.
Acceptance criteria:
- This file contains the authoritative artifact classification.
- Future audits and requirements use that classification instead of guessing.
- Non-applicable artifact types are named explicitly, not merely omitted.
Recommended change:
- Keep the classification section in this file current whenever a new
  executable, packaging format, or delivery surface is added.
Verification method:
- Review the repo root, entrypoint, build script, and release workflow and
  confirm each claimed artifact surface maps to a concrete file or workflow.
Counterpoints / reasons to reject:
- Reject only if the repo intentionally adds a new artifact type and documents
  it with equivalent evidence and verification.

## REQ-REPO-002

Status: Satisfied
Priority: P1
Severity: High
Domain: portability
Applies to: supported shell, OS envelope, and portability claims
Affected files/lines:
- `bin/secure-packer-bootstrapper:1-10`
- `Makefile:1-15`
- `src/lib/common.sh:1-214`
- `src/get_random/get_random.sh:1-145`
- `src/bootstrap_credentials/bootstrap_credentials.sh:23-40`
- `src/bootstrap_credentials/bootstrap_credentials.sh:291-427`
- `.github/workflows/verify.yml:1-22`
- `.github/workflows/release-artifact.yml:1-47`
- `src/fisher_yates_shuffle/REQUIREMENTS.md:128-193`
- `src/generate_password/REQUIREMENTS.md:283-310`
Authoritative sources:
- `SR-1`
- `SR-2`
- `SR-3`
- `SR-8`
- `SR-9`
- `SR-10`
Repository evidence:
- The shebangs and `Makefile` invoke Bash directly.
- `src/lib/common.sh` uses `local -n` and `declare -A`.
- `src/bootstrap_credentials/bootstrap_credentials.sh` uses `mapfile`,
  `BASH_REMATCH`, Linux `/proc`, and Linux/Red Hat FIPS helpers.
- `src/get_random/get_random.sh` reads `/dev/urandom`.
- CI runs on `ubuntu-latest` and installs Linux package names.
Applicability analysis:
- Bash-only and Linux-only behavior is intentional in current code.
- POSIX `sh` and non-Linux portability cannot be truthfully implied from the
  current implementation.
Requirement:
- The repository MUST state its supported platform contract as GNU Bash on
  Linux, with Bash 4.3 or newer as the minimum shell baseline, and MUST say
  plainly that POSIX `sh` compatibility and non-Linux Unix support are not
  currently claimed unless separately documented and verified.
Rationale:
- Reviewers and operators need one truthful portability statement before they
  can evaluate risk or choose test environments.
Acceptance criteria:
- The repo-wide ledger states the supported shell and OS contract.
- Future docs do not imply POSIX-shell portability without evidence.
- Module ledgers continue to document command-specific prerequisites and
  distro-sensitive assumptions.
Recommended change:
- Normalize README and future audit language to reuse this platform contract.
Verification method:
- Confirm the current implementation still depends on Bash-only features and
  Linux-specific paths; if those dependencies are removed later, revisit the
  baseline.
Counterpoints / reasons to reject:
- Reject only if maintainers intentionally narrow support further to a single
  distro and make that narrower statement explicit and tested.

## REQ-REPO-003

Status: Satisfied
Priority: P1
Severity: Medium
Domain: standards-governance
Applies to: standards selection, applicability testing, and audit consistency
Affected files/lines:
- `README.md:3-9`
- `README.md:97-140`
- `docs/MODULE-DECOMPOSITION.md:35-40`
- `docs/STUDENT-FIRST-STANDARDS.md:33-63`
- `docs/DOWNSTREAM-MIGRATION.md:15-166`
- `.github/workflows/verify.yml:1-22`
- `.github/workflows/release-artifact.yml:1-47`
Authoritative sources:
- `SR-1`
- `SR-4`
- `SR-5`
- `SR-7`
- `SR-11`
- `SR-12`
- `SR-13`
- `SR-14`
Repository evidence:
- The repo mixes Bash implementation concerns, Linux assumptions, downstream
  Packer/Kickstart/Ansible contracts, and GitHub release automation.
- Before this audit, there was no repo-wide standards register explaining which
  standards families govern which surfaces.
Applicability analysis:
- Different surfaces are governed by different authoritative sources.
- Importing the wrong standards family creates false positives and false
  compliance claims.
Requirement:
- The repository MUST maintain a standards register that lists each major
  standards family, whether it is applicable, partially applicable, or not
  applicable, and why that classification is correct for this repository.
Rationale:
- Later audits should not have to rediscover the repo's governing standards
  from scratch, and they should not import unrelated rules by analogy.
Acceptance criteria:
- This file contains a standards register.
- The register distinguishes internal Bash/Linux rules from downstream
  Packer/Kickstart/Ansible interface rules.
- Non-applicable families are named explicitly.
Recommended change:
- Update the standards register whenever a new external surface is added, such
  as a container image, GitHub Action, or new downstream protocol.
Verification method:
- Review each row in the standards register and confirm that the cited files or
  workflows actually exercise that standard family.
Counterpoints / reasons to reject:
- Reject only if the repo becomes so narrowly scoped that a standards register
  adds no traceability value, which is not the current state.

## REQ-REPO-004

Status: Satisfied
Priority: P1
Severity: High
Domain: evidence-protocol
Applies to: future audit findings and requirement updates
Affected files/lines:
- `docs/STUDENT-FIRST-STANDARDS.md:33-63`
- `docs/STUDENT-FIRST-STANDARDS.md:94-154`
- `src/bootstrap_credentials/REQUIREMENTS.md:1-74`
- `src/get_random/REQUIREMENTS.md:1-206`
- `src/fisher_yates_shuffle/REQUIREMENTS.md:1-194`
- `src/generate_password/REQUIREMENTS.md:1-376`
Authoritative sources:
- `SR-14`
- `SR-1`
- `SR-4`
- `SR-5`
Repository evidence:
- Module ledgers document behavior, but there was no repo-wide schema requiring
  explicit applicability analysis, source citations, verification methods, and
  counterpoints for every cross-cutting requirement.
Applicability analysis:
- This repository is both a technical artifact and a portfolio artifact, so the
  reasoning trail must be reviewable by specialists and non-specialists.
Requirement:
- Every repository-wide requirement entry added or updated through audit work
  MUST include status, priority, severity, domain, affected files/lines,
  authoritative sources, repository evidence, applicability analysis,
  requirement statement, rationale, acceptance criteria, recommended change,
  verification method, and counterpoints or reasons to reject.
Rationale:
- A requirement without evidence, applicability testing, and a verification
  path is a preference, not an auditable rule.
Acceptance criteria:
- New repo-wide entries in this file use the full schema.
- Unsupported claims are marked unverified and excluded from the requirement
  set instead of being silently promoted into policy.
- Superseded and rejected items remain traceable.
Recommended change:
- Treat the schema in this file as mandatory for future repo-wide audit work.
Verification method:
- Review the next audit batch and confirm every new entry carries the full
  evidence and verification fields.
Counterpoints / reasons to reject:
- Reject only if a simpler schema can preserve the same traceability and review
  value, which current evidence does not show.

## REQ-REPO-005

Status: Satisfied
Priority: P1
Severity: High
Domain: terminology-and-claim-discipline
Applies to: security, compliance, portability, and release-language claims
Affected files/lines:
- `README.md:88-95`
- `README.md:97-140`
- `src/bootstrap_credentials/bootstrap_credentials.sh:23-40`
- `src/bootstrap_credentials/bootstrap_credentials.sh:301-308`
- `src/bootstrap_credentials/REQUIREMENTS.md:41-67`
- `docs/DOWNSTREAM-MIGRATION.md:45-166`
Authoritative sources:
- `SR-5`
- `SR-7`
- `SR-12`
- `SR-13`
- `SR-14`
Repository evidence:
- The repo now constrains its own security surface through argument validation,
  fixed password-hash rounds, and restricted SSH key algorithm/size choices.
- README language now scopes claims to safe script behavior rather than host
  compliance state.
- Downstream integration docs discuss Packer, Kickstart, Ansible, and release
  consumption in the same narrative surface.
Applicability analysis:
- Red Hat documents that switching a system to FIPS mode after installation
  does not by itself guarantee FIPS compliance, and that only enabling FIPS at
  installation time guarantees all keys are generated under FIPS rules.
- Therefore, this repo should describe only the security properties it actually
  controls: algorithms, parameter bounds, secret handling, and released
  artifacts. It should not imply platform compliance from script behavior.
Requirement:
- Repository docs and ledgers MUST distinguish among detection, compatibility,
  alignment, and verified compliance. In particular, this repo MUST NOT claim
  FIPS, STIG, or CIS compliance for itself or for downstream systems unless the
  claim is scoped, evidenced, and tied to a verification method that reaches
  the actual governed surface.
Rationale:
- Overstated compliance language is a high-risk failure mode because it misleads
  operators, reviewers, and portfolio readers about what was actually proven.
Acceptance criteria:
- Repo-wide guidance defines the allowed terminology for strong security and
  compliance claims.
- Downstream-only guarantees are labeled as downstream guarantees.
- Script-level guarantees are described in terms of validated settings and
  fixed safe defaults, not host compliance markers.
Recommended change:
- Normalize future README and audit wording around "validated secure defaults",
  "restricted algorithm choices", and similarly scoped script-level language.
Verification method:
- Review all new or updated docs for words such as "compliant", "STIG",
  "CIS", "FIPS-enforced", "portable", and "secure" and confirm each has a
  scoped evidence trail.
Counterpoints / reasons to reject:
- Reject only if a later audit adds a full verification matrix that genuinely
  supports a stronger claim on the exact governed surface.

## REQ-REPO-006

Status: Satisfied
Priority: P2
Severity: Medium
Domain: ledger-authority
Applies to: requirements-ledger placement and duplicate-ledger control
Affected files/lines:
- `src/generate_password/REQUIREMENTS.md:1-120`
- `docs/REQUIREMENTS-generate_password.md:1-120`
- `docs/STUDENT-FIRST-STANDARDS.md:44-63`
Authoritative sources:
- `SR-14`
Repository evidence:
- `generate_password` currently has both a module-local requirements ledger and
  a second requirements document under `docs/`.
- `docs/REQUIREMENTS-generate_password.md` now marks itself as superseded and
  points to `src/generate_password/REQUIREMENTS.md` as the authoritative ledger.
- The docs copy is now reduced to a short legacy note that points readers to
  `src/generate_password/REQUIREMENTS.md` instead of preserving a second
  current-sounding contract body.
Applicability analysis:
- Duplicate ledgers for the same concern create reviewer confusion and make it
  unclear which file future contributors should update.
Requirement:
- Each concern MUST have one authoritative requirements ledger. Legacy or
  alternate copies MUST be marked explicitly as superseded or informational and
  MUST point to the authoritative ledger.
Rationale:
- Traceability breaks down when two different files can both look
  authoritative to a new contributor or reviewer.
Acceptance criteria:
- `src/generate_password/REQUIREMENTS.md` is treated as the authoritative
  module-local ledger for `generate_password`.
- `docs/REQUIREMENTS-generate_password.md` is marked as legacy/superseded.
- Future duplicated ledgers are either removed or clearly marked.
Recommended change:
- Keep the module-local ledger authoritative and preserve the docs copy only as
  a clearly labeled legacy snapshot if it must remain in the repo. If the
  snapshot continues to contain historical normative content, control that
  review-surface risk under a separate legacy-snapshot hygiene rule rather than
  allowing authority ambiguity to reappear.
Verification method:
- Search the repo for requirements ledgers and confirm that each concern maps
  to one authoritative file.
Counterpoints / reasons to reject:
- Reject only if maintainers intentionally keep two files for separate,
  explicitly documented audiences and can prevent semantic drift.

## REQ-REPO-007

Status: Satisfied
Priority: P1
Severity: High
Domain: verification-traceability
Applies to: repo-wide claims about artifacts, releases, portability, and CI
Affected files/lines:
- `scripts/lint.sh:1-14`
- `scripts/test.sh:1-6`
- `scripts/build-release.sh:1-33`
- `scripts/verify.sh:1-9`
- `.github/workflows/verify.yml:1-22`
- `.github/workflows/release-artifact.yml:1-47`
- `README.md:142-148`
Authoritative sources:
- `SR-4`
- `SR-5`
- `SR-6`
- `SR-14`
Repository evidence:
- The repo already has syntax checks, tests, bundle creation, and GitHub
  workflows.
- However, there was no repo-wide rule requiring every strong repo-wide claim
  to map to an automated or explicitly manual verification path.
Applicability analysis:
- This repo publishes artifacts for others to consume, so reviewable evidence
  needs to exist for the release surface as well as for the source tree.
Requirement:
- Every repo-wide claim about generated artifacts, release assets, portability,
  quality gates, or security-relevant behavior MUST map to at least one
  automated verification step or an explicit manual verification procedure. If
  no such verification exists, the claim MUST be marked unverified.
Rationale:
- Trustworthy release and audit language depends on being able to show how the
  claim is checked, not merely restate intent.
Acceptance criteria:
- Future repo-wide claims identify the script, workflow, or manual check that
  verifies them.
- Claims without verification are labeled unverified rather than presented as
  guaranteed behavior.
- Release-surface claims distinguish between workflow artifacts and release
  assets when relevant.
Recommended change:
- When a new repo-wide claim is added, add or reference its verification path in
  the same change.
Verification method:
- Trace each repo-wide claim in README or docs to a test, script, workflow, or
  explicit manual procedure.
Counterpoints / reasons to reject:
- Reject only if the claim is clearly marked aspirational and not presented as a
  current guarantee.

## REQ-REPO-008

Status: Satisfied
Priority: P2
Severity: Medium
Domain: bash-module-architecture
Applies to: sourceable module safety and executable-surface isolation
Affected files/lines:
- `src/lib/common.sh:1-4`
- `src/get_random/get_random.sh:1-145`
- `src/fisher_yates_shuffle/fisher_yates_shuffle.sh:1-63`
- `src/enforce_max_consecutive/enforce_max_consecutive.sh:1-138`
- `src/generate_password/generate_password.sh:1-413`
- `src/generate_password_hash/generate_password_hash.sh:1-103`
- `src/generate_ssh_keypair/generate_ssh_keypair.sh:1-196`
- `src/bootstrap_credentials/bootstrap_credentials.sh:1-432`
- `bin/secure-packer-bootstrapper:1-10`
Authoritative sources:
- `SR-1`
- `SR-14`
Repository evidence:
- Each module under `src/` is written to be sourced, not executed directly.
- `src/lib/common.sh` uses a source guard and `return 0` pattern that is valid
  only in a sourced-file context.
- The user-facing execution handoff happens in `bin/secure-packer-bootstrapper`
  and in the generated bundle trailer, not inside the reusable modules.
Applicability analysis:
- The Bash manual states that `.` / `source` executes commands in the current
  shell context, and that `return` may terminate a sourced file.
- In a source-based Bash architecture, unexpected top-level execution would
  mutate the caller shell, complicate tests, and make bundle composition much
  harder to reason about.
Requirement:
- Files under `src/` that are part of the sourceable module tree MUST remain
  safe to source into the current shell. They MAY define functions, constants,
  guards, and dependency sourcing, but they MUST NOT perform CLI execution,
  write downstream artifacts, or parse user-facing options at import time.
Rationale:
- This is the architectural rule that makes the repo's current test strategy,
  modular decomposition, and bundle assembly understandable and reliable.
Acceptance criteria:
- Sourcing a module loads its helpers without generating files or invoking the
  repo's CLI behavior.
- Executable behavior remains isolated to the entrypoint or explicit function
  calls.
- New modules follow the same import-time discipline.
Recommended change:
- Preserve the current source-safe module pattern and treat top-level side
  effects in `src/` as an architectural regression.
Verification method:
- Source representative modules in a clean Bash process and confirm they only
  load functions and helpers.
- Inspect top-level statements in `src/` files and confirm they do not invoke
  CLI orchestration or emit artifacts.
Counterpoints / reasons to reject:
- Reject only if the repository is intentionally reclassified away from a
  sourceable module architecture and documents a different execution model.

## REQ-REPO-009

Status: Satisfied
Priority: P2
Severity: Medium
Domain: entrypoint-design
Applies to: user-facing executable dispatch and CLI authority
Affected files/lines:
- `bin/secure-packer-bootstrapper:1-10`
- `src/bootstrap_credentials/bootstrap_credentials.sh:430-432`
- `scripts/build-release.sh:26-30`
Authoritative sources:
- `SR-1`
- `SR-14`
Repository evidence:
- `bin/secure-packer-bootstrapper` resolves the repo root, sources the
  bootstrap module, and delegates directly to `bootstrap_credentials "$@"`.
- `scripts/build-release.sh` appends the same `bootstrap_credentials "$@"`
  handoff to the standalone bundle.
- The actual option parsing and orchestration live in
  `bootstrap_credentials()`, not in duplicate wrappers.
Applicability analysis:
- In a Bash repo that is both sourceable and executable, duplicated CLI logic is
  a common drift risk because small wrapper differences can silently change
  behavior between local, bundled, and CI execution paths.
Requirement:
- User-facing executable surfaces MUST remain thin dispatch layers that hand off
  to one authoritative CLI function, rather than re-implementing argument
  parsing or orchestration logic in multiple wrappers.
Rationale:
- A single authoritative CLI boundary reduces architectural drift and gives
  reviewers one place to inspect public behavior.
Acceptance criteria:
- The repo has one authoritative CLI function for bootstrap orchestration.
- Wrapper scripts do only path resolution, module loading, and argument
  forwarding.
- New executable surfaces do not duplicate the option parser.
Recommended change:
- Keep future entrypoints as thin dispatchers and extend behavior in the shared
  CLI function instead of in wrapper scripts.
Verification method:
- Inspect the executable wrappers and confirm they delegate directly to the same
  CLI function with `"$@"`.
- Run the supported executable surfaces and confirm they reach the same
  bootstrap contract.
Counterpoints / reasons to reject:
- Reject only if the repo intentionally introduces multiple distinct CLIs and
  documents their behavior as separate public interfaces.

## REQ-REPO-010

Status: Satisfied
Priority: P1
Severity: High
Domain: release-bundle-verification
Applies to: source-to-bundle parity for published standalone artifacts
Affected files/lines:
- `scripts/build-release.sh:1-33`
- `scripts/verify.sh:1-9`
- `.github/workflows/verify.yml:1-22`
- `.github/workflows/release-artifact.yml:24-47`
- `README.md:129-147`
- `test/run.sh:8-13`
- `test/bootstrap_credentials_test.sh:15-41`
- `test/generate_password_test.sh:9-34`
Authoritative sources:
- `SR-1`
- `SR-4`
- `SR-5`
- `SR-14`
Repository evidence:
- `scripts/build-release.sh` assembles `dist/secure-packer-bootstrapper.sh`
  from the source modules, strips top-of-file source-loader guards, and appends
  an executable trailer.
- `scripts/verify.sh` now syntax-checks the bundled script and then executes
  `test/release_bundle_verify.sh` against the freshly built bundle.
- `.github/workflows/release-artifact.yml` publishes the bundled script and its
  checksum as release assets, making the bundle a supported downstream surface.
- Current behavioral tests execute source modules directly through `test/run.sh`.
Applicability analysis:
- GitHub distinguishes workflow artifacts from release assets; release assets
  are distributable files attached to a published release, not merely temporary
  CI outputs.
- Because this repo publishes the bundle as a release asset, syntax-only
  validation is not enough to support a strong claim that the released bundle is
  behaviorally equivalent to the source tree.
Requirement:
- Any bundled script that is published as a supported release asset MUST be
  treated as a first-class executable surface. Verification MUST execute the
  bundle in at least one contract-level test or smoke test, not only syntax
  check it. The published bundle MUST also exclude source-only dependency
  loader scaffolding that exists only to support module-local sourcing during
  development.
Rationale:
- Concatenation-based bundles can drift through missing files, ordering mistakes,
  bundle-only guard interactions, or wrapper differences that `bash -n` will not
  detect.
Acceptance criteria:
- The verification flow runs the bundled script itself under CI.
- At least one automated check confirms that the bundle can generate the
  documented bootstrap contract on a supported host.
- At least one automated check confirms that the bundle does not retain
  source-only loader guards or `shellcheck source=../...` annotations copied
  from the `src/` modules.
- Release publication depends on that bundle-level verification passing.
Recommended change:
- Extend `scripts/verify.sh` and CI to run `dist/secure-packer-bootstrapper.sh`
  with a controlled output directory and assert the same contract-critical files
  and exports that the source-path integration test expects.
Verification method:
- In CI, build the bundle, execute it, and validate the resulting documented
  bootstrap contract.
- Assert that the built bundle omits source-only loader guards and similar
  `src/`-layout scaffolding.
- Optionally compare the bundle-produced contract surface against the `bin/`
  entrypoint surface for the same invocation.
Counterpoints / reasons to reject:
- Reject only if the bundle is reclassified as a convenience artifact that is
  not documented, released, or supported as a downstream execution surface.

## REQ-REPO-011

Status: Satisfied
Priority: P3
Severity: Low
Domain: module-path-traceability
Applies to: canonical source paths, wrappers, and import-path clarity
Affected files/lines:
- `src/get_random.sh:1-4`
- `src/get_random/get_random.sh:1-145`
- `README.md:48-72`
- `test/get_random_test.sh:6-7`
Authoritative sources:
- `SR-1`
- `SR-14`
Repository evidence:
- The canonical module implementation lives at `src/get_random/get_random.sh`.
- A second wrapper path, `src/get_random.sh`, also exists and sources that file.
- Repo docs and tests consistently reference the nested path, but the wrapper's
  purpose is not explained.
Applicability analysis:
- In a source-based Bash repository, ambiguous import paths add review overhead
  because new contributors cannot easily tell which path is canonical, legacy,
  or compatibility-only.
Requirement:
- Every sourceable module MUST have one documented canonical path. Any wrapper
  or alternate import path MUST say whether it exists for compatibility,
  convenience, or deprecation, and docs/tests MUST consistently prefer the
  canonical path.
Rationale:
- File-path clarity is part of architecture readability, especially in a repo
  intended as a learning and portfolio artifact.
Acceptance criteria:
- The canonical source path for each module is identifiable from docs or file
  comments.
- Any compatibility wrapper is explicitly labeled.
- New imports in docs and tests use the canonical path.
Recommended change:
- Document the purpose of `src/get_random.sh`, or remove it if no compatibility
  role is intended.
Verification method:
- Search the repo for module import paths and confirm that one path is treated
  as canonical and any alternates are explained.
Counterpoints / reasons to reject:
- Reject only if maintainers intentionally support multiple equivalent import
  paths and document that choice as part of the public contract.

## REQ-REPO-012

Status: Satisfied
Priority: P1
Severity: High
Domain: dependency-surface
Applies to: Linux userland prerequisites, dependency tiers, and operator-facing
support contract
Affected files/lines:
- `README.md:74-148`
- `docs/REQUIREMENTS-repo.md:46-60`
- `src/get_random/get_random.sh:63-78`
- `src/generate_password_hash/generate_password_hash.sh:84-85`
- `src/generate_ssh_keypair/generate_ssh_keypair.sh:151-153`
- `src/bootstrap_credentials/bootstrap_credentials.sh:23-40`
- `src/bootstrap_credentials/bootstrap_credentials.sh:56-58`
- `src/bootstrap_credentials/bootstrap_credentials.sh:291-299`
- `scripts/lint.sh:4-13`
- `scripts/verify.sh:4-9`
- `test/run.sh:4-13`
- `test/testlib.sh:19-87`
- `test/generate_password_hash_test.sh:9`
- `test/bootstrap_credentials_test.sh:9-10`
- `.github/workflows/verify.yml:11-22`
- `.github/workflows/release-artifact.yml:14-47`
Authoritative sources:
- `SR-1`
- `SR-8`
- `SR-9`
- `SR-10`
- `SR-16`
- `SR-17`
- `SR-18`
- `SR-19`
- `SR-20`
- `SR-21`
- `SR-23`
- `SR-24`
- `SR-14`
Repository evidence:
- Runtime modules explicitly depend on `od`, `/dev/urandom`, `openssl`,
  `ssh-keygen`, `ssh-agent`, `ssh-add`, `setsid`, and common GNU/Linux file
  utilities.
- Developer scripts and tests add further dependencies such as `dirname`,
  `find`, `sort`, `mktemp`, `grep`, `shellcheck`, `sha256sum`, `sudo`, and
  `gh`.
- The README now includes one consolidated dependency contract that separates
  mandatory runtime, optional runtime, developer/test, and CI/release
  dependency surfaces.
Applicability analysis:
- On Linux, portability depends not only on Bash syntax but also on the
  availability and behavior of the surrounding userland tools.
- This repository has at least four dependency surfaces with different risk
  profiles: mandatory runtime, optional runtime features, developer/test tools,
  and CI/release tools.
- GitHub's docs distinguish between runner-provided tools and tools installed by
  the workflow itself, which means the support contract should do the same.
Upstream / vendor example:
- GitHub's workflow docs note that GitHub CLI is preinstalled on GitHub-hosted
  runners, while the repo's own workflows explicitly install `openssl`,
  `openssh-client`, and `shellcheck` with `apt-get`.
- Red Hat documents `update-crypto-policies --show` as a RHEL-specific helper,
  which is useful diagnostic context but not a generic Linux prerequisite.
Requirement:
- The repository MUST publish one authoritative dependency contract that
  classifies every external command, Linux-specific path, and environment
  assumption by surface: mandatory runtime, optional runtime / feature-gated,
  developer/test only, or CI/release only. The contract MUST describe the
  failure behavior or opt-out for optional items, and it MUST NOT present an
  Ubuntu-specific package-manager recipe as if it were the generic Linux setup
  story.
Rationale:
- Broad Linux portability cannot be reviewed honestly when the command surface
  is implicit, mixed across contexts, or tied to one distro's package manager
  without saying so.
Acceptance criteria:
- The repo documents mandatory runtime items such as Bash, `/dev/urandom`,
  `od`, `openssl`, `ssh-keygen`, and the required file utilities.
- Optional runtime items are either absent from the active contract or
  explicitly marked as feature-gated and non-essential.
- Developer/test-only items such as `mktemp`, `grep`, `find`, `sort`, and
  optional `shellcheck` are classified separately from runtime requirements.
- CI/release-only items such as `sudo`, `apt-get`, `sha256sum`, and `gh` are
  documented as workflow-surface dependencies rather than runtime CLI
  prerequisites.
Recommended change:
- Add a repo-wide dependency table, linked from the README, that separates the
  four dependency surfaces and records which commands are optional, installed by
  CI, or expected from the base Linux image.
Verification method:
- Inventory every external command and Linux path used in `src/`, `scripts/`,
  `test/`, and `.github/workflows/`, and confirm each one appears in the
  documented dependency contract with the right surface and failure mode.
Counterpoints / reasons to reject:
- Reject only if maintainers intentionally narrow support to one fixed Linux
  image and document that narrower image contract truthfully instead of claiming
  broad Linux portability.

## REQ-REPO-013

Status: Satisfied
Priority: P1
Severity: High
Domain: portability-evidence
Applies to: distro-family compatibility claims and verification coverage
Affected files/lines:
- `README.md:74-148`
- `docs/REQUIREMENTS-repo.md:46-60`
- `scripts/verify.sh:1-9`
- `.github/workflows/verify.yml:9-22`
- `.github/workflows/release-artifact.yml:13-47`
- `src/bootstrap_credentials/bootstrap_credentials.sh:23-40`
Authoritative sources:
- `SR-20`
- `SR-21`
- `SR-22`
- `SR-23`
- `SR-24`
- `SR-14`
Repository evidence:
- The repo-wide platform contract now distinguishes between CI-verified
  execution hosts and downstream consumer targets.
- The verification workflow now runs on `ubuntu-22.04` and `ubuntu-24.04`.
- The maintainer decision is that Rocky remains a downstream target context for
  generated artifacts, but the repo does not currently treat Rocky container
  checks as equivalent to first-class runner evidence for its own
  execution-host support claim.
Applicability analysis:
- GitHub documents that `runs-on: ubuntu-latest` selects a GitHub-hosted Ubuntu
  runner, and that matrix strategies can create multiple job variants across
  different environments.
- A portability claim that spans Rocky/RHEL-family and Ubuntu/Debian-family
  hosts needs evidence from both families or an explicit statement that support
  is narrower.
Upstream / vendor example:
- GitHub's matrix-strategy docs show how one workflow definition can run across
  multiple operating systems or environment variants.
- The repository now uses that model for Ubuntu runner variants and narrows its
  execution-host claim instead of mixing runner-backed Ubuntu evidence with a
  separate Rocky container evidence model.
Requirement:
- If the repository claims Linux portability across more than one distro family,
  the verification evidence MUST cover at least one RHEL-family environment and
  at least one Debian/Ubuntu-family environment. The evidence MAY be an
  automated CI matrix or an explicit manual verification record, but Ubuntu-only
  CI MUST NOT be presented as sufficient evidence for Rocky / CentOS Stream
  compatibility.
Rationale:
- Portability is a support claim, and support claims need evidence on the
  environments they name or imply.
Acceptance criteria:
- The supported versions are named explicitly, or the support statement is
  narrowed.
- The repo links each claimed supported version family to an automated
  verification job or a documented manual verification procedure.
- Release and README language does not imply broader Rocky or Ubuntu execution
  coverage than the evidence actually proves.
Recommended change:
- Add or maintain a distro-version verification plan: an automated matrix that
  covers the exact named execution-host versions, or else narrow the support
  statement to match the evidence and document downstream-target-only contexts
  separately.
Verification method:
- Review the support statement and confirm there is a matching verification path
  for each named supported version family.
- Confirm that one Ubuntu or Rocky job is not reused as proof for additional
  unverified versions.
Counterpoints / reasons to reject:
- Reject only if the repo explicitly narrows its support statement to
  Ubuntu-only or another single, well-defined Linux environment.

## REQ-REPO-014

Status: Satisfied
Priority: P1
Severity: High
Domain: documentation-traceability
Applies to: synchronization between authoritative ledgers and the real repo surface
Affected files/lines:
- `docs/STUDENT-FIRST-STANDARDS.md:33-63`
- `src/get_random/REQUIREMENTS.md:14-21`
- `src/fisher_yates_shuffle/REQUIREMENTS.md:12-19`
- `src/enforce_max_consecutive/REQUIREMENTS.md:17-24`
- `src/generate_password/REQUIREMENTS.md:18-25`
- `test/run.sh:1-15`
- `test/get_random_test.sh:1-47`
- `test/fisher_yates_shuffle_test.sh:1-29`
- `test/enforce_max_consecutive_test.sh:1-40`
- `test/generate_password_test.sh:1-34`
Authoritative sources:
- `SR-14`
- `SR-29`
Repository evidence:
- The student-first standard says each public module should explain its
  contract in the module's `REQUIREMENTS.md`.
- Several authoritative module ledgers still describe `.bats` files and
  "100% code-path coverage tests", while the actual test surface is the
  `test/*.sh` suite driven by `test/run.sh`.
- The audit surface for this repo depends heavily on readers trusting module
  ledgers as accurate maps of the code and tests.
Applicability analysis:
- In this repository, the module ledgers are not optional prose; they are part
  of the teaching and audit contract.
- A mismatch between the ledger and the actual file/test surface increases
  reviewer effort and can mislead both maintainers and non-specialist readers
  about what was really implemented or verified.
Upstream / vendor example:
- The EditorConfig specification exists to keep text-formatting expectations
  consistent across tools. In the same spirit, this repo's authoritative
  ledgers need to keep their file names, test names, and evidence claims
  consistent with the actual repository state.
Requirement:
- Every authoritative module ledger MUST describe the current repository state
  truthfully. File trees, test filenames, coverage claims, and behavioral
  summaries in `REQUIREMENTS.md` files MUST match the real code and test
  surface, or be explicitly labeled as legacy, planned, or target coverage.
Rationale:
- Traceability breaks when the explanation layer teaches a different repo than
  the one reviewers are actually reading.
Acceptance criteria:
- Module-location sections reference the real file names and paths.
- Test-surface descriptions point to the actual `test/*.sh` files or are marked
  as target coverage rather than current files.
- Strong wording such as "100% code-path coverage" is removed, evidenced, or
  clearly labeled as a future goal.
Recommended change:
- Normalize every authoritative module ledger so its location, test, and
  evidence sections match the current repo tree and current verification scope.
Verification method:
- Compare each module ledger against the actual files under `src/` and `test/`.
- Search the repo for outdated test names or unsupported coverage claims and
  confirm they are corrected or explicitly labeled as non-current.
Counterpoints / reasons to reject:
- Reject only if a given document is intentionally preserved as a historical
  snapshot and is clearly marked non-authoritative, which is not how the
  current module-local ledgers are presented.

## REQ-REPO-015

Status: Satisfied
Priority: P2
Severity: Medium
Domain: review-surface-readability
Applies to: plain-text readability, encoding hygiene, and student-facing documentation style
Affected files/lines:
- `docs/STUDENT-FIRST-STANDARDS.md:112-130`
- `src/get_random/REQUIREMENTS.md:8-21`
- `src/get_random/REQUIREMENTS.md:55-106`
- `src/fisher_yates_shuffle/REQUIREMENTS.md:12-19`
- `src/fisher_yates_shuffle/REQUIREMENTS.md:46-76`
- `src/enforce_max_consecutive/REQUIREMENTS.md:11-24`
- `src/enforce_max_consecutive/REQUIREMENTS.md:86-142`
- `src/generate_password/REQUIREMENTS.md:5-9`
- `src/generate_password/REQUIREMENTS.md:18-25`
- `src/generate_password/REQUIREMENTS.md:126-198`
- `.editorconfig:1-12`
Authoritative sources:
- `SR-14`
- `SR-29`
Repository evidence:
- The student-first standard says to prefer plain ASCII because it is easier to
  copy, search, and read in more terminals and editors.
- The repo's `.editorconfig` already defines a simple UTF-8/LF text baseline.
- The active module ledgers now use ASCII trees, ASCII examples, and current
  Bash test-file names.
- Search no longer finds mojibake, box-drawing diagrams, or stale `.bats`
  references in the authoritative module ledgers covered by this requirement.
Applicability analysis:
- This repository explicitly treats readability for first-year students and
  non-specialist reviewers as a first-class goal.
- UTF-8 file support does not itself justify decorative or corrupted text in the
  learning/audit surface; those are content decisions, not file-format needs.
Upstream / vendor example:
- The EditorConfig specification focuses on predictable text-file behavior
  across editors. This repo's student-first standard adds a stricter local rule:
  prefer plain ASCII when that improves copyability and terminal readability.
Requirement:
- Authoritative learning and audit documents MUST remain plain-text readable in
  common terminals and editors. ASCII SHOULD be the default for prose, diagrams,
  and examples unless non-ASCII materially improves correctness, and mojibake or
  decorative Unicode that does not improve comprehension MUST be removed.
Rationale:
- Encoding noise and decorative diagrams raise cognitive load at exactly the
  point where this repo is trying to be unusually approachable.
Acceptance criteria:
- No authoritative doc contains mojibake or similar corrupted text.
- Phase diagrams and examples use simple ASCII or ordinary headings/tables
  unless a non-ASCII character is clearly justified.
- The docs remain consistent with `.editorconfig` formatting expectations and
  the student-first readability rules.
Recommended change:
- Replace decorative Unicode diagrams with simple ASCII layouts or normal
  sectioned prose, and normalize any corrupted characters in authoritative
  ledgers.
Verification method:
- Search authoritative docs for common mojibake and non-ASCII glyph patterns.
- Open the files in a plain terminal view and confirm they remain easy to read
  without special rendering support.
Counterpoints / reasons to reject:
- Reject only if a specific non-ASCII character is necessary for correctness and
  clearly improves the reader's understanding more than the ASCII alternative.

## REQ-REPO-016

Status: Satisfied
Priority: P1
Severity: High
Domain: top-level-doc-clarity
Applies to: problem statement, split-secret explanation, and mixed-audience operator onboarding
Affected files/lines:
- `README.md:3-23`
- `README.md:97-140`
- `docs/DOWNSTREAM-MIGRATION.md:3-43`
- `docs/STUDENT-FIRST-STANDARDS.md:3-9`
- `docs/STUDENT-FIRST-STANDARDS.md:47-63`
- `test/bootstrap_credentials_test.sh:15-35`
Authoritative sources:
- `SR-11`
- `SR-12`
- `SR-13`
- `SR-14`
- `SR-25`
Repository evidence:
- The README now opens with the problem statement, the split-secret design,
  supported platforms, install-time versus provisioning-time values, and a
  concise consumer map.
- `docs/DOWNSTREAM-MIGRATION.md` now matches that story and explains the
  same-step shell-export pattern for downstream use.
- `test/bootstrap_credentials_test.sh` confirms the actual contract split:
  the bootstrap step emits the password hash for install-time use, while the
  plaintext password and SSH passphrase remain in the same-step shell-export
  contract for immediate provisioning use.
Applicability analysis:
- This repository explicitly serves first-year students, maintainers, security
  reviewers, and downstream operators. Those audiences need the top-level docs
  to explain both what the tool generates and why the generated values are split
  across different downstream consumers.
- Packer, Kickstart, and Ansible each give different meaning to the generated
  artifacts, so a reader should not have to reconstruct the security model by
  stitching together README bullets, migration notes, and tests.
Upstream / vendor example:
- HashiCorp documents `.auto.pkrvars.json` files as input-variable surfaces for
  Packer templates.
- Red Hat documents `user --iscrypted` and `user --plaintext` as distinct
  Kickstart password modes.
- Ansible documents the SSH connection plugin's SSH-key and `ssh-agent`
  expectations separately from privilege-escalation passwords.
Requirement:
- The top-level documentation MUST explain the split-secret design in plain
  language and provide one concise consumer map that distinguishes the deploy
  user's plaintext password, the SHA-512 crypt password hash, the SSH private
  key and public key, the SSH key passphrase, the `PKR_VAR_*` install-time
  inputs, the `SPB_*` retained file-path exports, and the metadata files. The
  docs MUST make it obvious which values are for Kickstart/Packer install-time
  use, which are for SSH login or provisioning, which are for sudo / become,
  and which are reference metadata.
Rationale:
- A mixed-audience security repo becomes much easier to trust when the
  first-contact documentation makes the secret split explicit instead of leaving the
  reader to infer it from multiple documents.
Acceptance criteria:
- The README states the problem this repo solves in plain language, including
  the move away from long-lived or static workflow secrets toward runtime
  bootstrap artifacts.
- The README or an immediately linked operator doc contains a compact
  artifact-role map or glossary that explains each generated secret or metadata
  file, its downstream consumer, and its intended use phase.
- The docs explicitly say that the plaintext password is retained for sudo /
  become, not for Kickstart user creation, and that `SPB_*` exports are file
  paths rather than raw secret values.
- The public docs stay synchronized with the behavior asserted by
  `test/bootstrap_credentials_test.sh`.
Recommended change:
- Add a short "Why this repo exists" section near the README opening and a
  compact "Who consumes what" table near the downstream-integration section.
Verification method:
- Read the README from top to bottom as a first-time reviewer and confirm that
  the repo's purpose, split-secret model, and downstream consumer roles are
  understandable without opening the implementation first.
- Compare the public docs against `bootstrap_credentials_test.sh` and confirm
  the documented install-time versus retained-secret split matches the tested
  behavior.
Counterpoints / reasons to reject:
- Reject only if the repo intentionally narrows its audience to experts who are
  already expected to infer the split-secret contract from code and downstream
  tooling knowledge, which conflicts with the repo's student-first standard.

## REQ-REPO-017

Status: Satisfied
Priority: P1
Severity: High
Domain: example-safety
Applies to: public usage snippets, CI-safe operator guidance, and release-consumption examples
Affected files/lines:
- `README.md:74-95`
- `README.md:129-140`
- `docs/DOWNSTREAM-MIGRATION.md:47-112`
- `.github/workflows/release-artifact.yml:24-47`
- `scripts/build-release.sh:1-34`
- `docs/STUDENT-FIRST-STANDARDS.md:122-144`
Authoritative sources:
- `SR-5`
- `SR-14`
- `SR-25`
- `SR-26`
- `SR-30`
Repository evidence:
- The README now labels local demo usage separately from same-step CI usage and
  shows the preferred `$RUNNER_TEMP` plus `eval "$( ... )"` flow for CI.
- The safer downstream workflow pattern already exists in
  `docs/DOWNSTREAM-MIGRATION.md`: download the published release asset, verify
  the pinned checksum, generate artifacts in `$RUNNER_TEMP`, evaluate the
  emitted shell exports only in the shell that will run Packer, and delete the
  temporary directory in cleanup.
- The release workflow publishes the exact standalone script and checksum that a
  downstream repo is expected to pin and review.
Applicability analysis:
- This repository is used both as a teaching repo and as a real downstream
  integration surface for GitHub workflows. Public examples therefore influence
  both learner understanding and operator behavior.
- GitHub documents `runner.temp` as the job-scoped temporary directory and
  documents releases as the packaged download surface for published software.
Upstream / vendor example:
- GitHub's contexts reference defines `runner.temp` for temporary per-job files.
- GitHub's release docs describe releases as the supported packaged download
  surface for binary files and other distributable assets.
Requirement:
- Public examples MUST be labeled by operating context. Local-learning examples
  MAY use a workspace path and interactive conveniences, but CI or downstream
  examples MUST show the safer operator pattern: consume the published release
  asset or explicitly explain the chosen source-consumption model, verify the
  pinned checksum when using release assets, generate artifacts in temporary
  runner storage such as `$RUNNER_TEMP` or `runner.temp`, evaluate the
  bootstrap output only inside the shell that will immediately consume it, and
  make cleanup ownership explicit.
Rationale:
- Examples are one of the strongest teaching tools in this repo. If they do not
  distinguish "easy to try locally" from "safe to run in CI," readers may carry
  demo habits into security-sensitive workflow code.
Acceptance criteria:
- The README or an immediately linked doc shows at least one clearly labeled
  local example and one clearly labeled CI/downstream example.
- The CI/downstream example uses the published release asset names from the
  release workflow, or explicitly states that it is using a reviewed source
  checkout instead.
- CI/downstream examples mention temporary runner storage, masking, and cleanup
  in the example itself or immediately adjacent explanatory text.
- Example text stays synchronized with the asset names produced by
  `.github/workflows/release-artifact.yml`.
Recommended change:
- Keep the current local quick-start commands, but label them as local/demo use
  and add a short CI-safe example block that points downstream operators to the
  release asset, checksum verification, `$RUNNER_TEMP`, masking, and cleanup.
Verification method:
- Review the public examples and confirm a first-time reader can tell which ones
  are safe for CI consumption and which are only local-learning shortcuts.
- Compare the documented release asset names and example flow against the
  current release workflow and migration doc.
Counterpoints / reasons to reject:
- Reject only if the repo intentionally stops publishing CI/downstream examples
  for public consumers and documents itself as a local-only teaching artifact,
  which is not how the README, release workflow, and migration guide present it.

## REQ-REPO-018

Status: Satisfied
Priority: P1
Severity: High
Domain: verification-harness-correctness
Applies to: shared test helpers, failure diagnostics, and truthful CI results
Affected files/lines:
- `test/testlib.sh:9-87`
- `test/bootstrap_credentials_test.sh:15-39`
- `test/run.sh:8-13`
- `scripts/test.sh:1-6`
- `scripts/verify.sh:6-9`
- `.github/workflows/verify.yml:16-22`
- `README.md:142-148`
Authoritative sources:
- `SR-1`
- `SR-14`
Repository evidence:
- The repo's shared test harness and all test files run under `set -euo
  pipefail`.
- `assert_file_not_contains` currently uses `grep ... && fail ...` without an
  explicit success return. In Bash functions, the function's status becomes the
  status of the last command executed.
- Multiple tests use `assert_file_not_contains` to verify negative conditions
  under `set -euo pipefail`, so a passing negative assertion must return zero
  explicitly instead of leaking `grep`'s non-zero status.
- The repo presents `scripts/test.sh`, `scripts/verify.sh`, and GitHub Actions
  verification as quality gates, so harness-control-flow bugs directly affect
  the truthfulness of the public verification story.
Applicability analysis:
- In this repository, the test helpers are part of the verification surface, not
  a disposable convenience layer. If they mishandle exit statuses, CI can fail
  for the wrong reason or hide the real failing assertion.
- The Bash manual documents both `errexit` behavior and that `return` without an
  explicit numeric argument uses the exit status of the last command executed.
Upstream / vendor example:
- The Bash manual's `set -e` documentation explains when non-zero statuses cause
  shell exit.
- The Bash manual's `return` documentation explains that a shell function uses
  the last command's status when no explicit return value is supplied.
Requirement:
- Shared test helpers MUST return zero when an assertion succeeds and MUST emit
  an explicit failure diagnostic when it does not. Negative assertions and other
  fault-injection helpers MUST be safe under `set -euo pipefail`, and the repo's
  verification scripts MUST fail only for real test failures or runtime errors,
  not because a helper leaks the status of an internal probe command.
Rationale:
- A broken verification harness can make the repo look less reliable than it is,
  and it can also hide the actual reason a test stopped.
Acceptance criteria:
- Passing negative assertions such as "file does not contain" return status `0`.
- Failing assertions print a `FAIL:` message or equivalent diagnostic before the
  test exits.
- `scripts/test.sh` succeeds when all tests pass and fails only when a real
  assertion or runtime error occurs.
- The shared harness has at least one automated self-test or equivalent smoke
  coverage for both positive and negative assertion helpers under
  `set -euo pipefail`.
Recommended change:
- Add a small `test/testlib_test.sh` or equivalent harness-level test, and make
  negative assertion helpers end with an explicit successful return when the
  assertion passes.
Verification method:
- Run `scripts/test.sh` on a supported Linux Bash environment and confirm the
  suite no longer aborts at a passing negative assertion.
- Run the harness-level test and confirm helper functions produce deterministic
  pass/fail behavior and visible diagnostics.
Counterpoints / reasons to reject:
- Reject only if the repo intentionally removes the shared helper layer and
  inlines all assertions directly inside each test, which is not the current
  design.

## REQ-REPO-019

Status: Satisfied
Priority: P1
Severity: High
Domain: workflow-dependency-immutability
Applies to: GitHub Actions third-party action references and workflow supply-chain trust
Affected files/lines:
- `.github/workflows/verify.yml:13-14`
- `.github/workflows/release-artifact.yml:16-17`
- `.github/workflows/release-artifact.yml:30-31`
Authoritative sources:
- `SR-31`
- `SR-14`
Repository evidence:
- The verification and release workflows now pin `actions/checkout` to a full
  commit SHA with an inline reviewed-tag comment.
- The release workflow no longer depends on `actions/upload-artifact`.
Applicability analysis:
- This repository's trust story depends on GitHub Actions to verify the code and
  publish downstream-consumed release assets.
- GitHub's security-hardening guidance says that pinning an action to a
  full-length commit SHA is the only way to use an immutable action release and
  is the recommended mitigation for action-repository compromise or retagging.
Upstream / vendor example:
- GitHub's security-hardening guide explicitly recommends full-length commit-SHA
  pins for actions and explains why tag pins remain mutable.
Requirement:
- All externally sourced GitHub Actions used by this repository MUST be pinned
  to full-length commit SHAs. For reviewer readability, each SHA pin SHOULD be
  accompanied by a comment or nearby note that states the reviewed tag or
  release it corresponds to.
Rationale:
- A security-focused release repo should not rely on mutable action tags for the
  very workflows that validate and publish its executable artifacts.
Acceptance criteria:
- Every `uses:` entry that references an external action resolves to a full
  40-character commit SHA.
- Human reviewers can still see which upstream action release was intended, by a
  comment, commit message, or linked documentation note.
- New workflow actions follow the same rule unless an explicit, reviewable
  exception records why a mutable pin remains temporarily necessary.
Recommended change:
- Replace mutable action tags with verified full-length SHAs and preserve the
  human-readable version context in comments.
Verification method:
- Inspect all workflow `uses:` entries and confirm they are pinned to full
  commit SHAs from the canonical upstream repositories.
- Review the comments or docs and confirm each SHA can be mapped back to the
  intended reviewed upstream release.
Counterpoints / reasons to reject:
- Reject only if the repo is intentionally used as a low-trust teaching sandbox
  with no claim of secure automation or release integrity, which conflicts with
  the current release and downstream-consumer posture.

## REQ-REPO-020

Status: Satisfied
Priority: P1
Severity: High
Domain: workflow-token-permissions
Applies to: explicit `GITHUB_TOKEN` scoping and least-privilege workflow design
Affected files/lines:
- `.github/workflows/verify.yml:1-22`
- `.github/workflows/release-artifact.yml:1-47`
Authoritative sources:
- `SR-6`
- `SR-31`
- `SR-32`
Repository evidence:
- `verify.yml` now declares explicit read-only permissions.
- `release-artifact.yml` now declares read-only workflow defaults and scopes
  `contents: write` to the single release-publishing job.
- GitHub documents that actions can access `github.token` even when the token is
  not explicitly passed as an input.
Applicability analysis:
- These workflows perform privileged tasks: source checkout, repository reads,
  and release-asset publication.
- GitHub's documentation recommends granting the `GITHUB_TOKEN` the minimum
  access required and allows workflows or jobs to define explicit permission
  scopes.
Upstream / vendor example:
- GitHub's `GITHUB_TOKEN` guidance states that workflows should grant the token
  only the minimum required access.
- GitHub's workflow-syntax docs show the `permissions` key and note that
  unspecified scopes become `none` once explicit permissions are declared.
Requirement:
- Every workflow or job in this repository MUST declare explicit minimum
  `GITHUB_TOKEN` permissions. Read-only verification jobs MUST NOT rely on
  repository-default token permissions, and write scopes such as `contents:
  write` MUST be limited to the job that actually publishes or mutates release
  state. Additional scopes such as `attestations: write` or `id-token: write`
  MUST only appear when a workflow step truly needs them.
Rationale:
- Token scoping is one of the simplest high-value controls in GitHub Actions,
  and relying on repository defaults weakens the review surface for a
  security-sensitive automation repo.
Acceptance criteria:
- `verify.yml` declares explicit read-only permissions appropriate to its job.
- `release-artifact.yml` declares only the write scopes needed for release
  publication, and no broader implicit defaults are relied upon.
- Future workflows add new token scopes only when the corresponding steps and
  rationale are visible in review.
Recommended change:
- Add explicit `permissions` blocks to every workflow and scope write access to
  the smallest job surface that needs it.
Verification method:
- Review each workflow YAML file and confirm that the token permissions are
  explicit, minimal, and consistent with the steps in that job.
- Check that no workflow depends on undocumented repository-level defaults for
  token access.
Counterpoints / reasons to reject:
- Reject only if the repo is intentionally delegating all workflow-permission
  control to organization-wide policy and documents that policy in a
  repo-visible way, which is not evidenced in the current repository.

## REQ-REPO-021

Status: Satisfied
Priority: P1
Severity: High
Domain: release-integrity-model
Applies to: published release assets, downstream verification guidance, and provenance claims
Affected files/lines:
- `.github/workflows/release-artifact.yml:24-47`
- `README.md:129-140`
- `docs/DOWNSTREAM-MIGRATION.md:47-67`
- `docs/DOWNSTREAM-MIGRATION.md:102-112`
- `docs/REQUIREMENTS-repo.md:661-722`
Authoritative sources:
- `SR-5`
- `SR-35`
- `SR-36`
- `SR-37`
- `SR-14`
Repository evidence:
- The release workflow now creates the release with the script and checksum
  attached at creation time instead of uploading assets after publication.
- The same workflow now publishes GitHub build provenance attestations for the
  release assets and declares the required `attestations: write` and
  `id-token: write` permissions only in the publishing job.
- README and the downstream migration guide now tell consumers to pin the
  published release, verify the checksum for file equality, verify the GitHub
  attestation for provenance, and treat immutable-release protection as a
  separate setting that is not claimed unless explicitly enabled.
Applicability analysis:
- This repository publishes an executable Bash script as a supported downstream
  release asset, so consumers need a truthful answer to "what does this checksum
  actually prove?"
- GitHub documents that immutable releases protect both tags and assets from
  post-publication changes, and that artifact or release attestations can
  establish build provenance and verification workflows for consumers.
- A checksum file attached to the same mutable release is useful for
  file-equality checks after download, but by itself it does not prove build
  provenance or protect against a post-publication replacement of both asset and
  checksum.
Upstream / vendor example:
- GitHub's immutable-releases docs recommend drafting the release, attaching all
  assets, and then publishing it.
- GitHub's release-integrity docs describe `gh release verify` and
  `gh release verify-asset` for immutable-release verification.
- GitHub's artifact-attestation docs describe attestations as a way to establish
  where and how software was built.
Requirement:
- The repository MUST define and document its current release integrity model.
  If downstream consumers are expected to trust published release assets, the
  repo MUST either:
  1. publish immutable releases with all assets attached before publication and
     document the corresponding verification flow, or
  2. generate verifiable provenance for the published artifact, such as GitHub
     artifact or release attestations, and clearly document the remaining limits
     of mutable releases until immutability is in place.
  Checksum files alone MUST NOT be presented as full supply-chain integrity
  proof for mutable releases.
Rationale:
- The repo already asks downstream automation to consume reviewed release assets.
  The release workflow and docs therefore need to say exactly what integrity and
  provenance guarantees exist today, and what does not yet exist.
Acceptance criteria:
- Public docs state whether release assets are mutable or protected by immutable
  release controls.
- The documented downstream verification flow matches the actual release process
  and does not overstate what a checksum proves.
- If immutable releases are adopted, the release workflow becomes compatible
  with draft-attach-publish release handling.
- If attestations are adopted, the workflow declares the required permissions
  and includes the attestation step in the published trust story.
Recommended change:
- Choose and document one concrete trust path: either move toward immutable
  releases with compatible workflow sequencing, or add attestations and clearly
  bound the current checksum-only guarantees until immutability is available.
Verification method:
- Review the release workflow, README, and downstream migration guide together
  and confirm the documented trust guarantees match the actual publication flow.
- If immutable releases or attestations are added later, review the workflow and
  published release process to confirm the new controls are really in place.
Counterpoints / reasons to reject:
- Reject only if the repo intentionally reclassifies published releases as
  convenience downloads with no supported trust story for downstream automation,
  which conflicts with the current README and migration guidance.

## REQ-REPO-022

Status: Satisfied
Priority: P2
Severity: Medium
Domain: governance-and-ownership
Applies to: security disclosure, review ownership, and maturity signals for the workflow/release surface
Affected files/lines:
- `.github/workflows/verify.yml:1-22`
- `.github/workflows/release-artifact.yml:1-47`
- `scripts/build-release.sh:1-34`
- `README.md:1-148`
- `Repository root (no SECURITY.md at audit time)`
- `.github/ (no CODEOWNERS at audit time)`
Authoritative sources:
- `SR-31`
- `SR-33`
- `SR-34`
- `SR-14`
Repository evidence:
- The repository publishes release assets and presents itself as a security-aware
  bootstrapper for downstream automation.
- A `LICENSE` file exists, which is a positive governance signal.
- The repository now includes `SECURITY.md` and `.github/CODEOWNERS`.
Applicability analysis:
- This repo is not just sample code; it publishes an executable artifact for
  others to consume in automation. In that setting, people need to know how to
  report vulnerabilities and who owns sensitive paths such as workflows and
  release scripts.
- GitHub's security-hardening guidance specifically recommends using CODEOWNERS
  to monitor changes, and GitHub's security-policy docs describe `SECURITY.md`
  as the repository-visible place to explain vulnerability reporting.
Upstream / vendor example:
- GitHub's CODEOWNERS docs describe defining responsible reviewers for paths in a
  repository.
- GitHub's security-policy docs describe adding `SECURITY.md` to tell people how
  to report vulnerabilities and which versions are supported.
Requirement:
- The repository MUST publish a minimal governance surface for its
  security-sensitive automation paths. At minimum, it MUST provide a
  repo-visible vulnerability reporting path via `SECURITY.md` or an equivalent
  clearly linked policy, and it MUST identify review ownership for
  `.github/workflows/`, `scripts/build-release.sh`, and release-governing docs
  through `CODEOWNERS` or an equally explicit owner map.
Rationale:
- A downstream-consumed security utility is easier to trust when disclosure and
  review ownership are explicit rather than tribal knowledge.
Acceptance criteria:
- A `SECURITY.md` file or equivalent repo-visible policy tells reporters how to
  disclose vulnerabilities and what support expectation exists.
- A `CODEOWNERS` file or equivalent owner map covers workflow and release paths.
- The governance docs are easy for maintainers, reviewers, and outside
  reporters to find from the repo root.
Recommended change:
- Add a minimal `SECURITY.md` and a focused `CODEOWNERS` file that covers the
  CI/CD and release surface first, then extend contributor guidance later if
  needed.
Verification method:
- Review the repository root and `.github/` directory and confirm that the
  governance files exist and cover the security-sensitive paths.
- Read the governance docs as a first-time outsider and confirm the reporting
  and review path are understandable without private maintainer knowledge.
Counterpoints / reasons to reject:
- Reject only if the repo is intentionally private, single-maintainer, and
  explicitly documented as having no external contribution or disclosure path,
  which is not how the current public-facing documentation presents it.

## REQ-REPO-023

Status: Satisfied
Priority: P2
Severity: Medium
Domain: legacy-snapshot-hygiene
Applies to: retained superseded ledgers, historical snapshots, and review-surface safety
Affected files/lines:
- `docs/REQUIREMENTS-generate_password.md:1-32`
- `docs/REQUIREMENTS-generate_password.md:458-470`
- `docs/REQUIREMENTS-repo.md:173-176`
- `docs/STUDENT-FIRST-STANDARDS.md:112-120`
Authoritative sources:
- `SR-14`
- `SR-29`
Repository evidence:
- `docs/REQUIREMENTS-generate_password.md` now declares itself a legacy,
  superseded snapshot and points readers to
  `src/generate_password/REQUIREMENTS.md`.
- The legacy file is now reduced to a short superseded note that points readers
  directly to the authoritative module ledger.
- The stale historical body, mojibake, and obsolete test claims have been
  removed from the active review surface.
Applicability analysis:
- This repository intentionally keeps requirements ledgers as part of its
  teaching and audit surface, not as private maintainer notes.
- Retaining historical intent is useful, but a superseded file that still reads
  like live policy after the first screenful weakens reviewer comprehension and
  undercuts the student-first readability rules.
Upstream / vendor example:
- The EditorConfig specification exists to keep file-format expectations stable
  and predictable across editors. In the same spirit, this repo's legacy
  snapshots need unmistakable scope markers so readers can reliably tell
  historical material from the current contract.
Requirement:
- Any retained superseded ledger or historical requirements snapshot MUST remain
  unmistakably non-current throughout the file. If obsolete normative text,
  file trees, coverage targets, or examples are preserved for traceability, the
  file MUST either:
  1. move that content under a clearly labeled "Historical snapshot" section
     after a repeated warning,
  2. replace the body with a short summary plus a pointer to the authoritative
     ledger, or
  3. move the preserved snapshot to an archive path that is clearly outside the
     active review surface.
  A single top-of-file superseded banner is not enough when the rest of the
  file still reads like a live contract document.
Rationale:
- Skim readers, search results, and recruiter-style spot checks often land
  below the first heading. Legacy material that still looks current can
  reintroduce confusion even after authority has been formally reassigned.
Acceptance criteria:
- Superseded requirement snapshots are visually or structurally separated from
  active ledgers by sectioning, file path, or repeated warning text.
- Historical body sections are labeled as historical before obsolete normative
  statements appear.
- Search hits for stale phrases such as `.bats` or `100% branch coverage` in
  superseded docs are either removed from the active review surface or clearly
  marked as historical nearby.
Recommended change:
- Either collapse `docs/REQUIREMENTS-generate_password.md` to a brief legacy
  note plus an authoritative-link pointer, or keep the preserved body only
  under an explicitly titled historical section or archive location.
Verification method:
- Open each superseded ledger at the first obsolete phrase returned by search
  and confirm the reader sees a nearby indication that the content is
  historical rather than current contract text.
- Review the repo tree and confirm legacy snapshots cannot be mistaken for
  authoritative current requirements during a skim read.
Counterpoints / reasons to reject:
- Reject only if the repo intentionally preserves raw historical snapshots for
  archival reasons and moves them into an archive namespace or other location
  that clearly removes them from the active learning and audit surface.
