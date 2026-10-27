# ansible-offline-install

[Simplified Chinese](README.md) | **English**

![license](https://img.shields.io/github/license/ghl1024/ansible-offline-install.svg)
![last commit](https://img.shields.io/github/last-commit/ghl1024/ansible-offline-install.svg)
![issues](https://img.shields.io/github/issues/ghl1024/ansible-offline-install.svg)
![stars](https://img.shields.io/github/stars/ghl1024/ansible-offline-install.svg)
![forks](https://img.shields.io/github/forks/ghl1024/ansible-offline-install.svg)
[![CI](https://github.com/ghl1024/ansible-offline-install/actions/workflows/ci.yml/badge.svg)](https://github.com/ghl1024/ansible-offline-install/actions/workflows/ci.yml)

**Install Ansible on servers with no internet access, in one command.**
This project packages Ansible into a single offline bundle: copy it to your
air-gapped machine, run one command, done. No network needed at any point
during installation.

## 📖 Contents

- [ansible-offline-install](#ansible-offline-install)
  - [📖 Contents](#-contents)
  - [🌐 Source repositories and mirrors](#-source-repositories-and-mirrors)
  - [1. What this does, in plain words](#1-what-this-does-in-plain-words)
  - [2. Before you start: check your server's info](#2-before-you-start-check-your-servers-info)
  - [3. Install in 3 steps (beginner path)](#3-install-in-3-steps-beginner-path)
    - [Step 1: Download the bundle that matches your server](#step-1-download-the-bundle-that-matches-your-server)
    - [Step 2: Copy the bundle to the offline server and extract it](#step-2-copy-the-bundle-to-the-offline-server-and-extract-it)
    - [Step 3: Run the installer and check the result](#step-3-run-the-installer-and-check-the-result)
  - [4. FAQ (check here first)](#4-faq-check-here-first)
  - [5. Glossary (when a term is unclear)](#5-glossary-when-a-term-is-unclear)
  - [6. Advanced usage](#6-advanced-usage)
    - [Bundled collections (already included)](#bundled-collections-already-included)
    - [Build your own bundle](#build-your-own-bundle)
    - [Pinned version](#pinned-version)
  - [7. Repository layout](#7-repository-layout)
  - [8. Roadmap](#8-roadmap)
  - [9. License](#9-license)

## 🌐 Source repositories and mirrors

The project is published on four platforms with identical content; the
mirrors are usually faster for downloads inside China:

| Platform | URL | Notes |
| --- | --- | --- |
| GitHub | https://github.com/ghl1024/ansible-offline-install | Primary repository: development and releases |
| Gitee | https://gitee.com/ghl1024/ansible-offline-install | China mirror, releases synced automatically |
| GitCode | https://gitcode.com/haydenguo/ansible-offline-install | China mirror |
| CNB | https://cnb.cool/ghl1024/ansible-offline-install | China mirror |

## 1. What this does, in plain words

Many company and datacenter servers are not allowed to reach the internet
(an "air-gapped" environment). On such a machine, `pip install ansible`
always fails, because it needs to download packages.

This project works around that in three steps:

1. On a computer **with** internet access, pack everything needed into one
   archive file (or simply download a ready-made, tested bundle from this
   project, see "Install in 3 steps" below).
2. Copy that file into the intranet (USB stick, bastion host, internal file
   server - anything works).
3. On the offline server, run the installer inside the bundle. Ansible goes
   into a **dedicated folder**, nothing on the system is modified, and
   deleting that folder uninstalls it completely.

## 2. Before you start: check your server's info

Run these three commands on your server and note the results; you will need
them to pick the right bundle:

```bash
cat /etc/os-release     # OS: Rocky Linux 9 / Ubuntu 24.04 / Debian 12 ...
uname -m                # CPU architecture: x86_64 or aarch64 (aarch64 = ARM64)
python3 --version       # Python version: 3.11 or newer is required
```

Supported systems (the machine Ansible is installed on, called the
"control node"):

| OS | Python |
| --- | --- |
| EL 9 family: Rocky Linux 9 / AlmaLinux 9 / RHEL 9 / CentOS Stream 9 | 3.11 (`python3.11` package) |
| Ubuntu 24.04 | 3.12 (included by default) |
| Ubuntu 22.04 | 3.11 (in the default repositories) |
| Debian 12 | 3.11 (included by default) |

Notes:

- **Root is not required.** A regular user can install (into their home
  directory); installing as root makes Ansible available system-wide.
- The machines Ansible will manage (managed nodes) need nothing special:
  just SSH and any Python. That is Ansible's own rule, unrelated to this
  project.

## 3. Install in 3 steps (beginner path)

### Step 1: Download the bundle that matches your server

Go to the [Releases page](https://github.com/ghl1024/ansible-offline-install/releases).
Release bundles are built and install-tested by GitHub Actions on real
machines (including native ARM64). File names look like this, and every part
means something:

```
ansible-offline-install-2.0.0-el9-aarch64-py311.tar.gz
└────────────┬───────────┘ └┬┘ └─┬───┘ └──┬──┘
         version 2.0.0      OS    arch    Python
```

Match the info you collected above:

| Your server | Download this bundle |
| --- | --- |
| Rocky / Alma / RHEL / CentOS Stream 9, x86_64 | `...-el9-x86_64-py311.tar.gz` |
| Rocky / Alma / RHEL / CentOS Stream 9, ARM64 | `...-el9-aarch64-py311.tar.gz` |
| Ubuntu 24.04, x86_64 | `...-ubuntu2404-x86_64-py312.tar.gz` |
| Ubuntu 24.04, ARM64 | `...-ubuntu2404-aarch64-py312.tar.gz` |
| Ubuntu 22.04, x86_64 | `...-ubuntu2204-x86_64-py311.tar.gz` |
| Ubuntu 22.04, ARM64 | `...-ubuntu2204-aarch64-py311.tar.gz` |
| Debian 12, x86_64 | `...-debian12-x86_64-py311.tar.gz` |
| Debian 12, ARM64 | `...-debian12-aarch64-py311.tar.gz` |

Prebuilt bundles exist for all four OSes, on both x86_64 and ARM64 - just
download the one you need. Build your own bundle only if you want a
different Ansible version or a different set of collections (see
"Build your own bundle" below).

If a matching `.sha256` file is offered next to the bundle, you can download
it too and verify the file was not corrupted in transfer (optional):

```bash
sha256sum -c ansible-offline-install-2.0.0-el9-aarch64-py311.tar.gz.sha256
# An "OK" line means the file is intact.
```

### Step 2: Copy the bundle to the offline server and extract it

Copy the `.tar.gz` file to the server (USB, bastion host, internal file
server), then:

```bash
tar xf ansible-offline-install-2.0.0-el9-aarch64-py311.tar.gz
cd ansible-offline-install-2.0.0-bundle
```

### Step 3: Run the installer and check the result

```bash
bash install.sh
```

The script prints its progress line by line (in Chinese by default; add
`--lang en` for English) and runs a self-check at the end. Output containing
`"ping": "pong"` means success:

```
[ansible-offline] Verifying installation
localhost | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
[ansible-offline] Done. Ansible is ready, fully offline.
```

Try `ansible --version` - if it prints a version, you are ready to write
your first playbook.

## 4. FAQ (check here first)

**Q: `ansible` says "command not found" after installing?**
A: For regular-user installs, commands are linked into `~/.local/bin`, which
may not be on your PATH yet. Run `export PATH="$HOME/.local/bin:$PATH"` or
simply open a new terminal.

**Q: The script says python3 is missing, or Python >= 3.11 is required?**
A: Install Python for your OS (this does not disturb anything else):

- EL 9: `sudo dnf install -y python3.11 python3.11-venv` (or `python3.11-devel` if there is no venv subpackage)
- Ubuntu 22.04 / Debian 12: `sudo apt install -y python3.11 python3.11-venv`
- Ubuntu 24.04 ships Python 3.12, so this error should not appear there.

**Q: The script says "wheelhouse not found"?**
A: Almost always this means only `install.sh` was copied, or the script was
run outside the extracted folder. Extract the full `.tar.gz`, change into
the `ansible-offline-install-2.0.0-bundle` folder, then run it. The
"wheelhouse" is the folder inside the bundle holding all install files.

**Q: Does CentOS 7 work?**
A: No. CentOS 7 reached end of life in 2024 and its Python is too old for
current Ansible. Please use an EL 9 family system (e.g. Rocky Linux 9).
The very first version of this project targeted CentOS 7; it has since been
fully rewritten and CentOS 7 is no longer supported.

**Q: Will this break my system's Python?**
A: No. Everything is installed into a dedicated folder (`/opt/ansible-offline`
for root, `~/ansible-offline` for regular users); only the `ansible`
commands are linked out. The system Python and other programs are untouched.

**Q: I don't want the bundled collections.**
A: Run `INSTALL_COLLECTIONS=0 bash install.sh` to skip them. A collection is
an Ansible plugin package; two popular ones are included by default.

**Q: Can the scripts print in English / Chinese?**
A: Yes. Both scripts speak Chinese by default and accept
`--lang en` for English (e.g. `bash install.sh --lang en`), or the
`ANSIBLE_OFFLINE_LANG=en` environment variable.

**Q: How do I uninstall?**
A: Delete the install folder and the command links - nothing is left behind:

```bash
# If installed as root:
rm -rf /opt/ansible-offline /usr/local/bin/ansible*
# If installed as a regular user:
rm -rf ~/ansible-offline ~/.local/bin/ansible*
```

**Q: The build machine cannot reach PyPI or Galaxy (no overseas network)?**
A: This is exactly why this project keeps mirrors on China-based platforms:

- If you just need Ansible installed: skip building and download a ready-made bundle from Releases - Gitee, GitCode and CNB all host them (see "Source repositories and mirrors"), no overseas network needed, and the bundles already include the collections.
- If you do need to build (e.g. for a different Ansible version): point pip at a domestic mirror by prefixing the build command: `PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple bash scripts/make-offline-bundle.sh` (Tsinghua mirror shown; Aliyun and others work too). Note: the collections are downloaded from Galaxy overseas and have no stable domestic mirror - if that step cannot connect, use a ready-made bundle instead.

## 5. Glossary (when a term is unclear)

- **Offline bundle**: one archive file containing everything needed for
  installation, so it works on machines without internet.
- **wheel**: Python's prebuilt package format - like a Windows installer;
  no compiling at install time, fast and reliable.
- **venv (virtual environment)**: a dedicated folder holding this Ansible
  installation, isolated from the system; deleting the folder removes it
  completely.
- **collection**: an Ansible plugin package that adds features, e.g. modules
  for firewalls or cloud providers. This project bundles `ansible.posix`
  and `community.general`, the two most commonly used ones.

## 6. Advanced usage

### Bundled collections (already included)

Bundles downloaded from Releases already contain `ansible.posix` and
`community.general` (including their dependencies); `install.sh` installs
them automatically, nothing extra to do. `collections-requirements.yml`
lists them; edit it and rebuild (next section) to change the set.

### Build your own bundle

Useful to change the Ansible version or the bundled collections.
On an **online** machine with the **same** OS family, CPU architecture and
Python version as the offline target, clone this repository and run:

```bash
bash scripts/make-offline-bundle.sh
```

The result lands in `dist/`: `ansible-offline-install-2.0.0-bundle.tar.gz`
plus its `.sha256` checksum file. Copy it to the offline machine and follow
steps 2 and 3 above.

Options (environment variables):

- `WITH_COLLECTIONS=0`: bundle Ansible only, without collections (smaller).
- `PYTHON_BIN=python3.11`: pick which Python builds the bundle (when several
  are installed).
- To change the Ansible version, edit the `ansible-core` pin in
  `requirements.txt` before building.
- `PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple`: use a domestic
  PyPI mirror when overseas networks are unreachable (Tsinghua shown;
  Aliyun works too).

### Pinned version

`requirements.txt` pins `ansible-core==2.18.19` (the last 2.18.x release
supporting Python 3.11), so every machine gets an identical, reproducible
environment.

## 7. Repository layout

Listed in the order you will use them:

1. 🚀 `install.sh` - the installer for the offline machine; the only file most users need (Chinese UI, `--lang en` for English)
2. 📦 `scripts/make-offline-bundle.sh` - the bundle builder for the online machine
3. 📌 `requirements.txt` - ansible-core version pin
4. 🧩 `collections-requirements.yml` - collections bundled with the offline package
5. 🤖 `.github/workflows/ci.yml` - CI: script checks + install tests for 8 OS/arch combos
6. 🚢 `.github/workflows/release.yml` - Release: builds, tests and publishes bundles for all 8 targets
7. 📝 `CHANGELOG.md` - version history
8. 📄 `LICENSE` - MIT license

## 8. Roadmap

- [x] Galaxy collections bundled for offline install
- [x] CI: script checks + container install tests on EL 9, Ubuntu 24.04 / 22.04 and Debian 12, on x86_64 and ARM64
- [x] Release bundles for x86_64 and ARM64, built, install-tested and published by GitHub Actions on native ARM64 runners

Questions or requests: open an
[Issue](https://github.com/ghl1024/ansible-offline-install/issues) and, if
you can, include your OS version (the output of `cat /etc/os-release`) and
the error message you saw.

## 9. License

MIT License. See [LICENSE](LICENSE).
