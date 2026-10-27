#!/usr/bin/env bash
# 同步 GitHub Release 到 Gitee（在 CNB tag_push 流水线中运行）。
# 资产来自上一个 stage 从 GitHub Release 下载到 dist/ 的文件；
# 发布说明来自同 stage 保存的 release-body.md（GitHub Release 正文）。
# 逻辑改编自 Ansible-Admin 的 .cnb/scripts/sync-release.sh（已实战验证）：
# 幂等创建/更新 Release、同名附件先删后传、Gitee 附件配额满时自动清理旧版重试。
# Sync the GitHub Release to Gitee from the CNB tag_push pipeline.
# Adapted from Ansible-Admin's battle-tested sync-release.sh (Gitee part).

set -Eeuo pipefail

readonly TAG="${CNB_BRANCH:?CNB_BRANCH is required}"
readonly GITEE_API="https://gitee.com/api/v5/repos/ghl1024/ansible-offline-install"
readonly GITEE_KEEP_RELEASES="${GITEE_KEEP_RELEASES:-5}"
readonly GITEE_QUOTA_RETRY_KEEP_RELEASES="${GITEE_QUOTA_RETRY_KEEP_RELEASES:-1}"
work_dir="$(mktemp -d /tmp/ansible-offline-release.XXXXXX)"
readonly WORK_DIR="${work_dir}"
readonly BODY_FILE="${WORK_DIR}/release-body.md"
readonly GITEE_RELEASE_FILE="${WORK_DIR}/gitee-release.json"
readonly GITEE_ASSETS_FILE="${WORK_DIR}/gitee-assets.json"

cleanup() {
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_http_success() {
  local status="$1"
  local action="$2"
  local body_file="$3"

  if [[ ! "${status}" =~ ^2[0-9][0-9]$ ]]; then
    echo "${action} failed with HTTP ${status}:" >&2
    sed -n '1,120p' "${body_file}" >&2
    exit 1
  fi
}

for command_name in curl jq; do
  require_command "${command_name}"
done

if [[ -z "${GITEE_TOKEN:-}" ]]; then
  echo "GITEE_TOKEN is not available from the CNB secret import." >&2
  exit 1
fi

echo "Starting Gitee Release synchronization for ${TAG}."

shopt -s nullglob
assets=(dist/*.tar.gz dist/*.sha256)
if (( ${#assets[@]} == 0 )); then
  echo 'No release assets found under dist/.' >&2
  exit 1
fi

release_name="ansible-offline-install ${TAG}"
release_body=''
if [[ -s release-body.md ]]; then
  release_body="$(cat release-body.md)"
fi
if [[ -z "${release_body}" ]]; then
  release_body="${CNB_TAG_RELEASE_DESC:-}"
fi
if [[ -z "${release_body}" ]]; then
  release_body="${CNB_COMMIT_MESSAGE:-ansible-offline-install ${TAG}}"
fi
printf '%s\n' "${release_body}" >"${BODY_FILE}"

curl_args=(
  curl
  -sS
  --retry 3
  --retry-delay 5
  --retry-connrefused
  --connect-timeout 15
  --max-time 300
)

extract_gitee_release_id() {
  local body_file="$1"
  local release_id

  if ! release_id="$(
    jq -r '
      if type == "object" then
        .id // .data.id // .release.id // .data.release.id // empty
      else
        empty
      end
    ' "${body_file}"
  )"; then
    echo 'Gitee release response is not valid JSON:' >&2
    sed -n '1,120p' "${body_file}" >&2
    exit 1
  fi

  printf '%s\n' "${release_id}"
}

is_gitee_quota_error() {
  local body_file="$1"

  grep -Eiq '配额|quota|超出仓库附件配额' "${body_file}"
}

fetch_gitee_releases() {
  local output_file="$1"
  local jsonl_file="${output_file}.jsonl"
  local page=1
  local page_file
  local status
  local count

  : >"${jsonl_file}"

  while :; do
    page_file="${WORK_DIR}/gitee-releases-page-${page}.json"
    status="$("${curl_args[@]}" \
      -o "${page_file}" \
      -w '%{http_code}' \
      --get "${GITEE_API}/releases" \
      --data-urlencode "access_token=${GITEE_TOKEN}" \
      --data-urlencode "page=${page}" \
      --data-urlencode 'per_page=100')"
    require_http_success "${status}" 'Gitee release list' "${page_file}"

    if ! jq -e 'type == "array"' "${page_file}" >/dev/null; then
      echo 'Gitee release list response is not an array:' >&2
      sed -n '1,120p' "${page_file}" >&2
      exit 1
    fi

    count="$(jq 'length' "${page_file}")"
    jq -c '.[]' "${page_file}" >>"${jsonl_file}"

    if (( count < 100 )); then
      break
    fi
    page=$((page + 1))
  done

  jq -s '.' "${jsonl_file}" >"${output_file}"
}

prune_gitee_releases() {
  local keep_count="$1"
  local releases_file="${WORK_DIR}/gitee-releases-retention-${keep_count}.json"
  local delete_list="${WORK_DIR}/gitee-releases-delete-${keep_count}.jsonl"
  local release
  local release_id
  local release_tag
  local delete_body
  local delete_status

  fetch_gitee_releases "${releases_file}"

  jq -c --arg current "${TAG}" --argjson keep "${keep_count}" '
    def release_tag: (.tag_name // .tag // "");
    def version_parts:
      release_tag
      | sub("^v"; "")
      | split(".")
      | map(tonumber? // 0)
      | . + [0, 0, 0]
      | .[0:3];

    [
      .[]
      | select((release_tag | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) and (.id != null))
      | {
          id,
          tag_name: release_tag,
          version: version_parts,
          created_at: (.created_at // .published_at // "")
        }
    ]
    | sort_by(.version[0], .version[1], .version[2], .created_at)
    | reverse
    | .[$keep:]
    | .[]
    | select(.tag_name != $current)
  ' "${releases_file}" >"${delete_list}"

  if [[ ! -s "${delete_list}" ]]; then
    echo "No old Gitee Releases need pruning; keeping latest ${keep_count} semantic releases."
    return
  fi

  while IFS= read -r release; do
    release_id="$(jq -r '.id' <<<"${release}")"
    release_tag="$(jq -r '.tag_name' <<<"${release}")"
    delete_body="${WORK_DIR}/gitee-release-delete-${release_id}.json"

    echo "Deleting old Gitee Release ${release_tag} to free attachment quota."
    delete_status="$("${curl_args[@]}" \
      -o "${delete_body}" \
      -w '%{http_code}' \
      -X DELETE "${GITEE_API}/releases/${release_id}" \
      --get \
      --data-urlencode "access_token=${GITEE_TOKEN}")"

    case "${delete_status}" in
      2*)
        ;;
      404)
        echo "Gitee Release ${release_tag} already missing; skipping delete."
        ;;
      *)
        require_http_success "${delete_status}" "Gitee release delete (${release_tag})" "${delete_body}"
        ;;
    esac
  done <"${delete_list}"
}

upload_gitee_asset() {
  local file="$1"
  local body_file="$2"

  "${curl_args[@]}" \
    -o "${body_file}" \
    -w '%{http_code}' \
    -X POST "${GITEE_API}/releases/${gitee_release_id}/attach_files" \
    -F "access_token=${GITEE_TOKEN}" \
    -F "file=@${file}"
}

create_gitee_release() {
  gitee_status="$("${curl_args[@]}" \
    -o "${GITEE_RELEASE_FILE}" \
    -w '%{http_code}' \
    -X POST "${GITEE_API}/releases" \
    --data-urlencode "access_token=${GITEE_TOKEN}" \
    --data-urlencode "tag_name=${TAG}" \
    --data-urlencode "name=${release_name}" \
    --data-urlencode "body@${BODY_FILE}" \
    --data-urlencode 'target_commitish=main')"
  require_http_success "${gitee_status}" 'Gitee release create' "${GITEE_RELEASE_FILE}"
  gitee_release_id="$(extract_gitee_release_id "${GITEE_RELEASE_FILE}")"
  if [[ -z "${gitee_release_id}" ]]; then
    echo 'Gitee release create returned no release id.' >&2
    sed -n '1,120p' "${GITEE_RELEASE_FILE}" >&2
    exit 1
  fi
}

gitee_release_id=''
gitee_status="$("${curl_args[@]}" \
  -o "${GITEE_RELEASE_FILE}" \
  -w '%{http_code}' \
  --get "${GITEE_API}/releases/tags/${TAG}" \
  --data-urlencode "access_token=${GITEE_TOKEN}")"

case "${gitee_status}" in
  200)
    gitee_release_id="$(extract_gitee_release_id "${GITEE_RELEASE_FILE}")"
    if [[ -n "${gitee_release_id}" ]]; then
      echo "Updating Gitee Release ${TAG}."
      gitee_status="$("${curl_args[@]}" \
        -o "${GITEE_RELEASE_FILE}" \
        -w '%{http_code}' \
        -X PATCH "${GITEE_API}/releases/${gitee_release_id}" \
        --data-urlencode "access_token=${GITEE_TOKEN}" \
        --data-urlencode "tag_name=${TAG}" \
        --data-urlencode "name=${release_name}" \
        --data-urlencode "body@${BODY_FILE}" \
        --data-urlencode 'target_commitish=main')"
      require_http_success "${gitee_status}" 'Gitee release update' "${GITEE_RELEASE_FILE}"
    else
      echo "Gitee release lookup returned no release id; creating Gitee Release ${TAG}."
      create_gitee_release
    fi
    ;;
  404)
    echo "Creating Gitee Release ${TAG}."
    create_gitee_release
    ;;
  *)
    require_http_success "${gitee_status}" 'Gitee release lookup' "${GITEE_RELEASE_FILE}"
    ;;
esac

if (( GITEE_KEEP_RELEASES > 0 )); then
  echo "Applying Gitee Release retention: keeping latest ${GITEE_KEEP_RELEASES} semantic releases."
  prune_gitee_releases "${GITEE_KEEP_RELEASES}"
fi

gitee_status="$("${curl_args[@]}" \
  -o "${GITEE_ASSETS_FILE}" \
  -w '%{http_code}' \
  --get "${GITEE_API}/releases/${gitee_release_id}/attach_files" \
  --data-urlencode "access_token=${GITEE_TOKEN}")"
require_http_success "${gitee_status}" 'Gitee release asset lookup' "${GITEE_ASSETS_FILE}"
jq -e 'type == "array"' "${GITEE_ASSETS_FILE}" >/dev/null

gitee_quota_pruned=false
for file in "${assets[@]}"; do
  filename="$(basename "${file}")"
  existing_asset="$(jq -c --arg name "${filename}" '.[] | select((.name // "") == $name)' "${GITEE_ASSETS_FILE}" | sed -n '1p' || true)"
  if [[ -n "${existing_asset}" ]]; then
    asset_id="$(jq -r '.id // empty' <<<"${existing_asset}")"
    if [[ -n "${asset_id}" ]]; then
      delete_status="$("${curl_args[@]}" \
        -o "${WORK_DIR}/gitee-delete-${asset_id}.json" \
        -w '%{http_code}' \
        -X DELETE "${GITEE_API}/releases/${gitee_release_id}/attach_files/${asset_id}" \
        --get \
        --data-urlencode "access_token=${GITEE_TOKEN}")"
      case "${delete_status}" in
        2*)
          ;;
        404)
          echo "Gitee asset ${filename} already missing; skipping delete."
          ;;
        *)
          require_http_success "${delete_status}" "Gitee asset delete (${filename})" "${WORK_DIR}/gitee-delete-${asset_id}.json"
          ;;
      esac
    fi
  fi

  echo "Uploading ${filename} to Gitee."
  upload_body="${WORK_DIR}/gitee-upload-${filename}.json"
  upload_status="$(upload_gitee_asset "${file}" "${upload_body}")"

  if [[ ! "${upload_status}" =~ ^2[0-9][0-9]$ ]] &&
    is_gitee_quota_error "${upload_body}" &&
    [[ "${gitee_quota_pruned}" == false ]]; then
    echo "Gitee attachment quota exceeded; pruning old releases down to latest ${GITEE_QUOTA_RETRY_KEEP_RELEASES} and retrying ${filename}." >&2
    prune_gitee_releases "${GITEE_QUOTA_RETRY_KEEP_RELEASES}"
    gitee_quota_pruned=true
    upload_status="$(upload_gitee_asset "${file}" "${upload_body}")"
  fi

  require_http_success "${upload_status}" "Gitee asset upload (${filename})" "${upload_body}"
done

echo "Release ${TAG} synchronized to Gitee."
