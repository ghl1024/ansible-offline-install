#!/usr/bin/env bash
# 离线包构建脚本：在联网机器上运行，打出可拷入内网的离线安装包。
# Offline bundle builder: run this on an ONLINE machine with the SAME OS
# family / CPU arch / Python version as the offline target.
#
# WITH_COLLECTIONS=1（默认）会把 collections-requirements.yml 里列的
# Galaxy collections（含依赖）一并下载进离线包；=0 则只打 ansible-core。
# 界面语言 / UI language: 默认中文，--lang en 或 ANSIBLE_OFFLINE_LANG=en 切英文。
set -euo pipefail

SCRIPT_LANG="${ANSIBLE_OFFLINE_LANG:-zh}"
while [ $# -gt 0 ]; do
  case "$1" in
    --lang) SCRIPT_LANG="${2:-zh}"; shift 2 ;;
    --lang=*) SCRIPT_LANG="${1#--lang=}"; shift ;;
    *) shift ;;
  esac
done
case "${SCRIPT_LANG}" in en*) SCRIPT_LANG="en" ;; *) SCRIPT_LANG="zh" ;; esac

# t <key> [args...] - 按当前语言输出一条消息 / print one message in the selected language
t() {
  local key="$1"; shift
  if [ "${SCRIPT_LANG}" = "en" ]; then
    case "${key}" in
      python_not_found) printf 'python3 not found' ;;
      python_too_old) printf 'Python >= 3.11 required' ;;
      downloading_wheels) printf 'Downloading wheels (this step needs network)' ;;
      downloading_collections) printf 'Downloading Galaxy collections (with dependencies)' ;;
      packing) printf 'Packing %s' "$1" ;;
      sha256) printf 'SHA256' ;;
      done) printf 'Done: %s' "$1" ;;
      offline_hint) printf 'On the offline machine: tar xf %s && cd %s && bash install.sh' "$1" "$2" ;;
    esac
  else
    case "${key}" in
      python_not_found) printf '未找到 python3' ;;
      python_too_old) printf '需要 Python >= 3.11' ;;
      downloading_wheels) printf '正在下载 wheel 包（此步需要联网）' ;;
      downloading_collections) printf '正在下载 Galaxy collections（含依赖）' ;;
      packing) printf '正在打包 %s' "$1" ;;
      sha256) printf 'SHA256 校验' ;;
      done) printf '完成：%s' "$1" ;;
      offline_hint) printf '到离线机器上执行：tar xf %s && cd %s && bash install.sh' "$1" "$2" ;;
    esac
  fi
}
b() { printf '[打包 bundle] %s\n' "$(t "$@")"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSION="${VERSION:-2.0.0}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
WITH_COLLECTIONS="${WITH_COLLECTIONS:-1}"
BUNDLE_NAME="ansible-offline-install-${VERSION}-bundle"
OUT_DIR="${REPO_DIR}/dist"

command -v "${PYTHON_BIN}" >/dev/null 2>&1 || { b python_not_found >&2; exit 1; }
"${PYTHON_BIN}" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)' \
  || { b python_too_old >&2; exit 1; }

cd "${REPO_DIR}"
rm -rf wheelhouse
mkdir -p wheelhouse "${OUT_DIR}"

b downloading_wheels
"${PYTHON_BIN}" -m pip download -r requirements.txt -d wheelhouse

STAGE="$(mktemp -d)"
trap 'rm -rf "${STAGE}"' EXIT
mkdir -p "${STAGE}/${BUNDLE_NAME}"
cp -r wheelhouse install.sh requirements.txt README.md README.en.md LICENSE CHANGELOG.md "${STAGE}/${BUNDLE_NAME}/"

if [ "${WITH_COLLECTIONS}" = "1" ]; then
  b downloading_collections
  BUILD_VENV="$(mktemp -d)/venv"
  "${PYTHON_BIN}" -m venv "${BUILD_VENV}"
  "${BUILD_VENV}/bin/pip" install -q -r requirements.txt
  mkdir -p "${STAGE}/${BUNDLE_NAME}/collections"
  "${BUILD_VENV}/bin/ansible-galaxy" collection download \
    -r collections-requirements.yml -p "${STAGE}/${BUNDLE_NAME}/collections"
  cp collections-requirements.yml "${STAGE}/${BUNDLE_NAME}/"
  rm -rf "$(dirname "${BUILD_VENV}")"
fi

b packing "${BUNDLE_NAME}.tar.gz"
tar -czf "${OUT_DIR}/${BUNDLE_NAME}.tar.gz" -C "${STAGE}" "${BUNDLE_NAME}"

b sha256
(cd "${OUT_DIR}" && sha256sum "${BUNDLE_NAME}.tar.gz" | tee "${BUNDLE_NAME}.tar.gz.sha256")
b done "${OUT_DIR}/${BUNDLE_NAME}.tar.gz"
b offline_hint "${BUNDLE_NAME}.tar.gz" "${BUNDLE_NAME}"
