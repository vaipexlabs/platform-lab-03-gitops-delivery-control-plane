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
desired_digest="$2"

if [[ ! "${desired_digest}" =~ ^sha256:[a-f0-9]{64}$ ]]; then
  echo "Image digest must use the form sha256:<64 lowercase hexadecimal characters>." >&2
  exit 1
fi

case "${target_environment}" in
  dev)
    predecessor_environment=""
    ;;
  staging)
    predecessor_environment="dev"
    ;;
  prod)
    predecessor_environment="staging"
    ;;
  *)
    echo "Target environment must be dev, staging, or prod." >&2
    exit 1
    ;;
esac

digest_from_file() {
  local file="$1"
  local digest_count
  local digest

  digest_count="$(awk '$1 == "digest:" { count++ } END { print count + 0 }' "${file}")"
  if [[ "${digest_count}" -ne 1 ]]; then
    echo "Expected exactly one image digest in ${file}." >&2
    exit 1
  fi

  digest="$(awk '$1 == "digest:" { print $2 }' "${file}")"
  if [[ ! "${digest}" =~ ^sha256:[a-f0-9]{64}$ ]]; then
    echo "Existing image digest is invalid in ${file}." >&2
    exit 1
  fi

  printf '%s\n' "${digest}"
}

target_file="${OVERLAY_ROOT}/${target_environment}/kustomization.yaml"
current_digest="$(digest_from_file "${target_file}")"

if [[ "${current_digest}" == "${desired_digest}" ]]; then
  echo "${target_environment} already references ${desired_digest}." >&2
  exit 1
fi

if [[ -n "${predecessor_environment}" ]]; then
  predecessor_file="${OVERLAY_ROOT}/${predecessor_environment}/kustomization.yaml"
  predecessor_digest="$(digest_from_file "${predecessor_file}")"
  if [[ "${predecessor_digest}" != "${desired_digest}" ]]; then
    echo "Cannot promote ${desired_digest} to ${target_environment}." >&2
    echo "${predecessor_environment} currently references ${predecessor_digest}." >&2
    exit 1
  fi
fi

temporary_file="$(mktemp)"
cleanup() {
  rm -f -- "${temporary_file}"
}
trap cleanup EXIT

awk -v desired_digest="${desired_digest}" '
  $1 == "digest:" {
    sub(/digest:.*/, "digest: " desired_digest)
  }
  { print }
' "${target_file}" > "${temporary_file}"

mv "${temporary_file}" "${target_file}"
trap - EXIT

echo "Prepared ${target_environment} promotion:"
echo "  from: ${current_digest}"
echo "  to:   ${desired_digest}"
echo "  file: ${target_file#"${REPOSITORY_ROOT}/"}"
