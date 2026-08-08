#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ "$#" -ne 2 ]]; then
  echo "Usage: $0 <base-revision> <head-revision>" >&2
  exit 1
fi

base_revision="$1"
head_revision="$2"
overlay_root="applications/vaipex-demo/overlays"

git -C "${REPOSITORY_ROOT}" rev-parse --verify "${base_revision}^{commit}" >/dev/null
git -C "${REPOSITORY_ROOT}" rev-parse --verify "${head_revision}^{commit}" >/dev/null

changed_overlay_files="$(
  git -C "${REPOSITORY_ROOT}" diff --name-only \
    "${base_revision}" \
    "${head_revision}" \
    -- "${overlay_root}/*/kustomization.yaml"
)"
changed_overlay_count="$(printf '%s\n' "${changed_overlay_files}" | awk 'NF { count++ } END { print count + 0 }')"

if [[ "${changed_overlay_count}" -ne 1 ]]; then
  echo "A promotion must change exactly one environment overlay; found ${changed_overlay_count}." >&2
  exit 1
fi

target_file="${changed_overlay_files}"
case "${target_file}" in
  "${overlay_root}/dev/kustomization.yaml")
    target_environment="dev"
    predecessor_environment=""
    ;;
  "${overlay_root}/staging/kustomization.yaml")
    target_environment="staging"
    predecessor_environment="dev"
    ;;
  "${overlay_root}/prod/kustomization.yaml")
    target_environment="prod"
    predecessor_environment="staging"
    ;;
  *)
    echo "Unsupported promotion target: ${target_file}" >&2
    exit 1
    ;;
esac

digest_from_revision() {
  local revision="$1"
  local file="$2"
  local content
  local digest_count
  local digest

  content="$(git -C "${REPOSITORY_ROOT}" show "${revision}:${file}")"
  digest_count="$(printf '%s\n' "${content}" | awk '$1 == "digest:" { count++ } END { print count + 0 }')"
  if [[ "${digest_count}" -ne 1 ]]; then
    echo "Expected exactly one image digest in ${file} at ${revision}." >&2
    exit 1
  fi

  digest="$(printf '%s\n' "${content}" | awk '$1 == "digest:" { print $2 }')"
  if [[ ! "${digest}" =~ ^sha256:[a-f0-9]{64}$ ]]; then
    echo "Invalid image digest in ${file} at ${revision}." >&2
    exit 1
  fi

  printf '%s\n' "${digest}"
}

base_digest="$(digest_from_revision "${base_revision}" "${target_file}")"
head_digest="$(digest_from_revision "${head_revision}" "${target_file}")"

if [[ "${base_digest}" == "${head_digest}" ]]; then
  echo "The ${target_environment} image digest did not change." >&2
  exit 1
fi

temporary_directory="$(mktemp -d)"
cleanup() {
  rm -rf -- "${temporary_directory}"
}
trap cleanup EXIT

git -C "${REPOSITORY_ROOT}" show "${base_revision}:${target_file}" \
  | sed -E 's/^([[:space:]]*)digest:.*/\1digest: <promotion-digest>/' \
  > "${temporary_directory}/base.yaml"
git -C "${REPOSITORY_ROOT}" show "${head_revision}:${target_file}" \
  | sed -E 's/^([[:space:]]*)digest:.*/\1digest: <promotion-digest>/' \
  > "${temporary_directory}/head.yaml"

if ! diff -u "${temporary_directory}/base.yaml" "${temporary_directory}/head.yaml"; then
  echo "A promotion overlay may change only its image digest." >&2
  exit 1
fi

if [[ -n "${predecessor_environment}" ]]; then
  predecessor_file="${overlay_root}/${predecessor_environment}/kustomization.yaml"
  predecessor_digest="$(digest_from_revision "${head_revision}" "${predecessor_file}")"
  if [[ "${head_digest}" != "${predecessor_digest}" ]]; then
    echo "${target_environment} must promote the digest currently approved in ${predecessor_environment}." >&2
    echo "${target_environment}: ${head_digest}" >&2
    echo "${predecessor_environment}: ${predecessor_digest}" >&2
    exit 1
  fi
fi

echo "Promotion policy passed:"
echo "  environment: ${target_environment}"
echo "  from:        ${base_digest}"
echo "  to:          ${head_digest}"
