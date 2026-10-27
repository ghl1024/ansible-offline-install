#!/usr/bin/env bash
# ansible-offline-install - ansible-core 离线安装脚本 / offline installer for ansible-core
# 从本地 wheelhouse 安装到独立 venv，全程不联网。
# Installs from a local wheelhouse into an isolated venv. No network access.
#
# 界面语言 / UI language: 默认中文。英文：bash install.sh --lang en
# 或环境变量 ANSIBLE_OFFLINE_LANG=en。Default is Chinese; use --lang en for English.
set -euo pipefail

SCRIPT_LANG="${ANSIBLE_OFFLINE_LANG:-zh}"
while [ $# -gt 0 ]; do
  case "$1" in
    --lang) SCRIPT_LANG="${2:-zh}"; shift 2 ;;
    --lang=*) SCRIPT_LANG="${1#--lang=}"; shift ;;
    -h|--help)
      if [ "${SCRIPT_LANG}" = "en" ]; then
        echo "Usage: bash install.sh [--lang zh|en]   (offline install of ansible-core from the bundled wheelhouse)"
      else
        echo "用法：bash install.sh [--lang zh|en]   （从随包 wheelhouse 离线安装 ansible-core）"
      fi
      exit 0 ;;
    *) shift ;;
  esac
done
case "${SCRIPT_LANG}" in en*) SCRIPT_LANG="en" ;; *) SCRIPT_LANG="zh" ;; esac

# t <key> [args...] - 按当前语言输出一条消息 / print one message in the selected language
t() {
  local key="$1"; shift
  if [ "${SCRIPT_LANG}" = "en" ]; then
    case "${key}" in
      python_not_found) printf 'python3 not found. Install Python >= %s first (see the README support matrix).' "${MIN_PY}" ;;
      python_too_old) printf 'Python >= %s is required for ansible-core 2.18.x. Found: %s' "${MIN_PY}" "$1" ;;
      wheelhouse_missing) printf 'wheelhouse/ not found next to install.sh. Download the offline bundle from Releases, or build it on an online machine with: bash scripts/make-offline-bundle.sh' ;;
      requirements_missing) printf 'requirements.txt not found.' ;;
      creating_venv) printf 'Creating venv at %s' "${VENV_DIR}" ;;
      venv_failed) printf 'venv creation failed. On EL9: dnf install -y python3.11 python3.11-devel. On Debian/Ubuntu: apt install -y python3.11 python3.11-venv (22.04) or python3-venv (24.04).' ;;
      installing) printf 'Installing from local wheelhouse (offline)' ;;
      note_path) printf 'Note: add %s to your PATH: export PATH="%s:$PATH"' "${LINK_DIR}" "${LINK_DIR}" ;;
      wrote_cfg) printf 'Wrote default /etc/ansible/ansible.cfg' ;;
      wrote_hosts) printf 'Wrote example /etc/ansible/hosts' ;;
      installing_collections) printf 'Installing %s bundled collection tarball(s) to %s' "$1" "${COLLECTIONS_PATH}" ;;
      verifying) printf 'Verifying installation' ;;
      done) printf 'Done. Ansible is ready, fully offline.' ;;
    esac
  else
    case "${key}" in
      python_not_found) printf '未找到 python3，请先安装 Python >= %s（见 README 的支持矩阵）。' "${MIN_PY}" ;;
      python_too_old) printf 'ansible-core 2.18.x 需要 Python >= %s，当前版本：%s' "${MIN_PY}" "$1" ;;
      wheelhouse_missing) printf 'install.sh 同目录下未找到 wheelhouse/。请从 Releases 下载离线包，或在联网机器上用 scripts/make-offline-bundle.sh 构建。' ;;
      requirements_missing) printf '未找到 requirements.txt。' ;;
      creating_venv) printf '正在创建 venv：%s' "${VENV_DIR}" ;;
      venv_failed) printf 'venv 创建失败。EL9 请执行：dnf install -y python3.11 python3.11-devel；Debian/Ubuntu 请执行：apt install -y python3.11 python3.11-venv（22.04）或 python3-venv（24.04）。' ;;
      installing) printf '正在从本地 wheel 包离线安装' ;;
      note_path) printf '提示：请把 %s 加入 PATH：export PATH="%s:$PATH"' "${LINK_DIR}" "${LINK_DIR}" ;;
      wrote_cfg) printf '已写入默认配置 /etc/ansible/ansible.cfg' ;;
      wrote_hosts) printf '已写入示例主机清单 /etc/ansible/hosts' ;;
      installing_collections) printf '正在安装随包附带的 %s 个 collection 到 %s' "$1" "${COLLECTIONS_PATH}" ;;
      verifying) printf '正在验证安装' ;;
      done) printf '完成。Ansible 已就绪，全程离线。' ;;
    esac
  fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WHEELHOUSE="${WHEELHOUSE:-${SCRIPT_DIR}/wheelhouse}"
REQUIREMENTS="${SCRIPT_DIR}/requirements.txt"
PYTHON_BIN="${PYTHON_BIN:-python3}"
MIN_PY="3.11"

if [ "$(id -u)" -eq 0 ]; then
  INSTALL_DIR="${ANSIBLE_INSTALL_DIR:-/opt/ansible-offline}"
  LINK_DIR="/usr/local/bin"
  COLLECTIONS_PATH="${COLLECTIONS_PATH:-/usr/share/ansible/collections}"
else
  INSTALL_DIR="${ANSIBLE_INSTALL_DIR:-${HOME}/ansible-offline}"
  LINK_DIR="${HOME}/.local/bin"
  COLLECTIONS_PATH="${COLLECTIONS_PATH:-${HOME}/.ansible/collections}"
fi
VENV_DIR="${INSTALL_DIR}/venv"

log() { printf '[ansible-offline] %s\n' "$*"; }
die() { printf '[ansible-offline] ERROR: %s\n' "$*" >&2; exit 1; }

# 1. 环境预检 / Preflight
command -v "${PYTHON_BIN}" >/dev/null 2>&1 || die "$(t python_not_found)"
"${PYTHON_BIN}" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)' \
  || die "$(t python_too_old "$(${PYTHON_BIN} --version 2>&1)")"

[ -d "${WHEELHOUSE}" ] || die "$(t wheelhouse_missing)"
[ -f "${REQUIREMENTS}" ] || die "$(t requirements_missing)"

# 2. 创建隔离的 venv（不动系统 Python 的包）/ Create isolated venv
log "$(t creating_venv)"
mkdir -p "${INSTALL_DIR}"
"${PYTHON_BIN}" -m venv "${VENV_DIR}" || die "$(t venv_failed)"

# 3. 离线安装：--no-index 保证 pip 绝不访问网络 / Offline install
log "$(t installing)"
"${VENV_DIR}/bin/pip" install --no-index --find-links "${WHEELHOUSE}" -r "${REQUIREMENTS}"

# 4. 把命令链接到 PATH / Expose binaries
mkdir -p "${LINK_DIR}"
for bin in ansible ansible-playbook ansible-galaxy ansible-doc ansible-vault; do
  ln -sf "${VENV_DIR}/bin/${bin}" "${LINK_DIR}/${bin}"
done
case ":${PATH}:" in
  *":${LINK_DIR}:"*) ;;
  *) log "$(t note_path)" ;;
esac

# 5. 最小配置，仅在不存在时写入，绝不覆盖用户配置 / Minimal config if none exists
if [ "$(id -u)" -eq 0 ]; then
  mkdir -p /etc/ansible
  if [ ! -f /etc/ansible/ansible.cfg ]; then
    printf '[defaults]\ninventory = /etc/ansible/hosts\nlog_path = /var/log/ansible.log\nhost_key_checking = False\n' > /etc/ansible/ansible.cfg
    log "$(t wrote_cfg)"
  fi
  if [ ! -f /etc/ansible/hosts ]; then
    printf '[local]\nlocalhost ansible_connection=local\n' > /etc/ansible/hosts
    log "$(t wrote_hosts)"
  fi
fi

# 6. 可选：随包 collections，全部来自本地 tarball 离线安装 / Optional bundled collections
#    仅当离线包是带 WITH_COLLECTIONS=1 构建时存在。用 INSTALL_COLLECTIONS=0 跳过。
if [ "${INSTALL_COLLECTIONS:-1}" != "0" ] && [ -d "${SCRIPT_DIR}/collections" ]; then
  shopt -s nullglob
  tarballs=("${SCRIPT_DIR}/collections"/*.tar.gz)
  shopt -u nullglob
  if [ "${#tarballs[@]}" -gt 0 ]; then
    log "$(t installing_collections "${#tarballs[@]}")"
    "${VENV_DIR}/bin/ansible-galaxy" collection install --force "${tarballs[@]}" -p "${COLLECTIONS_PATH}"
  fi
fi

# 7. 验证 / Verify
log "$(t verifying)"
"${LINK_DIR}/ansible" --version
"${LINK_DIR}/ansible" localhost -m ping
log "$(t done)"
