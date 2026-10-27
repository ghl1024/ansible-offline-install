# Changelog

## 2.0.0 - 2026-10-27

A ground-up refactor of the installer for current systems. The project now
targets modern distributions and the current ansible-core line only.

### Added
- Offline installer (`install.sh`) based on a local wheelhouse and an
  isolated Python venv; pip runs with `--no-index`, no network at install time.
- Bundle builder (`scripts/make-offline-bundle.sh`) producing a versioned
  `.tar.gz` plus SHA256 checksum for Release distribution.
- MIT `LICENSE`.
- Bilingual README: Chinese by default (`README.md`) with an English
  version (`README.en.md`), linked to each other for language switching.
- Support matrix: EL 9 family (Rocky / Alma / RHEL / CentOS Stream 9),
  Ubuntu 22.04 and 24.04, Debian 12.
- Minimal `/etc/ansible/ansible.cfg` and example inventory, created only
  when no existing config is present.
- Optional offline Galaxy collections: bundles built with
  `WITH_COLLECTIONS=1` (default) ship ansible.posix and community.general
  (with dependencies) from `collections-requirements.yml`, and the
  installer sets them up from local tarballs.
- CI workflow (`.github/workflows/ci.yml`): shellcheck plus install tests
  in Rocky Linux 9 and Ubuntu 24.04 containers, covering the bundled
  collections, on both x86_64 and native ARM64 runners.
- Release workflow (`.github/workflows/release.yml`): pushing a version
  tag builds, install-tests and publishes offline bundles for all
  supported OSes (EL 9, Ubuntu 24.04 / 22.04, Debian 12) on x86_64 and
  ARM64 - 8 targets in total - with SHA256 checksums. The CI install-test
  matrix covers the same 8 combinations.
- Both scripts now auto-detect a Python >= 3.11 interpreter
  (python3.13 / 3.12 / 3.11) when `PYTHON_BIN` is not set, because on
  EL 9 `python3` is 3.9 and on Ubuntu 22.04 it is 3.10 even after
  python3.11 is installed. (The first CI run caught exactly this on
  Rocky Linux 9 and Ubuntu 22.04.)
- Both scripts (`install.sh`, `scripts/make-offline-bundle.sh`) now print
  in Chinese by default, matching the primarily Chinese user base;
  `--lang en` or `ANSIBLE_OFFLINE_LANG=en` switches them to English.
- Release workflow gains a `sync-gitee` job: on tag pushes it pushes the
  tag to Gitee, creates (or reuses) the matching Gitee release with the
  same release notes, and uploads all 8 bundle assets. Requires the
  `GITEE_TOKEN` repository secret; the job skips itself with a warning
  when the secret is absent.
- READMEs gain a mirrors section listing all four hosting platforms
  (GitHub primary; Gitee, GitCode and CNB mirrors for faster downloads
  in China).
- READMEs rewritten for beginners: pre-flight checks with example
  commands, a bundle filename decoder and selection table, a 3-step
  install path with the expected success output, an FAQ (PATH, Python
  version, wheelhouse, CentOS 7, uninstall) and a plain-language
  glossary.

### Changed
- Ansible pinned to `ansible-core==2.18.19` (Python >= 3.11) in
  `requirements.txt`, installed from prebuilt wheels instead of compiling
  source tarballs.
- The wheelhouse is no longer committed to git; it ships as a Release asset.
