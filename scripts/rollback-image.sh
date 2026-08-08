#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OVERLAY_ROOT="${REPOSITORY_ROOT}/applications/vaipex-demo/overlays"

if [[ "$#" -ne 2 ]]; then
  echo "Usage: $0 <dev|staging|prod> <sha256:digest>" >&2
  exit 1
fi

target_environment="$1"
rollback_digest="$2"

case "${target_environment}" in
  dev | staging | prod) ;;
  *)
    echo "Target environment must be dev, staging, or prod." >&2
    exit 1
    ;;
esac

if [[ ! "${rollback_digest}" =~ ^sha256:[a-f0-9]{64}$ ]]; then
  echo "Rollback digest must use the form sha256:<64 lowercase hexadecimal characters>." >&2
  exit 1
fi

relative_target_file="applications/vaipex-demo/overlays/${target_environment}/kustomization.yaml"
target_file="${REPOSITORY_ROOT}/${relative_target_file}"

if ! git -C "${REPOSITORY_ROOT}" diff --quiet -- "${relative_target_file}" \
  || ! git -C "${REPOSITORY_ROOT}" diff --cached --quiet -- "${relative_target_file}"; then
  echo "The ${target_environment} overlay already has uncommitted changes." >&2
  exit 1
fi

digest_from_content() {
  local content="$1"
  local digest_count
  local digest

  digest_count="$(printf '%s\n' "${content}" | awk '$1 == "digest:" { count++ } END { print count + 0 }')"
  if [[ "${digest_count}" -ne 1 ]]; then
    echo "Expected exactly one image digest in ${relative_target_file}." >&2
    exit 1
  fi

  digest="$(printf '%s\n' "${content}" | awk '$1 == "digest:" { print $2 }')"
  if [[ ! "${digest}" =~ ^sha256:[a-f0-9]{64}$ ]]; then
    echo "Existing image digest is invalid in ${relative_target_file}." >&2
    exit 1
  fi

  printf '%s\n' "${digest}"
}

current_content="$(cat "${target_file}")"
current_digest="$(digest_from_content "${current_content}")"
if [[ "${current_digest}" == "${rollback_digest}" ]]; then
  echo "${target_environment} already references ${rollback_digest}." >&2
  exit 1
fi

rollback_approved=false
while IFS= read -r historical_revision; do
  historical_content="$(
    git -C "${REPOSITORY_ROOT}" show "${historical_revision}:${relative_target_file}"
  )"
  historical_digest="$(digest_from_content "${historical_content}")"
  if [[ "${historical_digest}" == "${rollback_digest}" ]]; then
    rollback_approved=true
    break
  fi
done < <(git -C "${REPOSITORY_ROOT}" rev-list HEAD -- "${relative_target_file}")

if [[ "${rollback_approved}" != "true" ]]; then
  echo "${rollback_digest} was never approved in ${target_environment}." >&2
  exit 1
fi

temporary_file="$(mktemp)"
cleanup() {
  rm -f -- "${temporary_file}"
}
trap cleanup EXIT

awk -v rollback_digest="${rollback_digest}" '
  $1 == "digest:" {
    sub(/digest:.*/, "digest: " rollback_digest)
  }
  { print }
' "${target_file}" > "${temporary_file}"

mv "${temporary_file}" "${target_file}"
trap - EXIT

echo "Prepared ${target_environment} rollback:"
echo "  from: ${current_digest}"
echo "  to:   ${rollback_digest}"
echo "  file: ${relative_target_file}"
