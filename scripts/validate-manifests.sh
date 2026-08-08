#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

for required_command in kubectl kubeconform; do
  if ! command -v "${required_command}" >/dev/null 2>&1; then
    echo "Required command not found: ${required_command}" >&2
    exit 1
  fi
done

# shellcheck disable=SC1091
source "${REPOSITORY_ROOT}/versions.env"

temporary_directory="$(mktemp -d)"
cleanup() {
  rm -rf -- "${temporary_directory}"
}
trap cleanup EXIT

for environment in dev staging prod; do
  rendered_manifest="${temporary_directory}/${environment}.yaml"
  kubectl kustomize \
    "${REPOSITORY_ROOT}/applications/vaipex-demo/overlays/${environment}" \
    > "${rendered_manifest}"

  kubeconform \
    -kubernetes-version "${KUBERNETES_VERSION#v}" \
    -strict \
    -summary \
    "${rendered_manifest}"
done

kubectl kustomize "${REPOSITORY_ROOT}/clusters/local" >/dev/null
kubectl kustomize "${REPOSITORY_ROOT}/bootstrap/argocd" >/dev/null
"${SCRIPT_DIR}/validate-platform-standards.sh"

echo "GitOps manifest validation passed."
