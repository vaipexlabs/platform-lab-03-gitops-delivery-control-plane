#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
KUSTOMIZATION_FILE="${REPOSITORY_ROOT}/bootstrap/argocd/kustomization.yaml"

# shellcheck source=../versions.env
source "${REPOSITORY_ROOT}/versions.env"

required_commands=(kind kubectl)
for required_command in "${required_commands[@]}"; do
  if ! command -v "${required_command}" >/dev/null 2>&1; then
    echo "Required command not found: ${required_command}" >&2
    exit 1
  fi
done

cluster_found=false
for existing_cluster in $(kind get clusters); do
  if [[ "${existing_cluster}" == "${CLUSTER_NAME}" ]]; then
    cluster_found=true
    break
  fi
done

if [[ "${cluster_found}" != "true" ]]; then
  echo "Cluster ${CLUSTER_NAME} does not exist. Run ./scripts/create-cluster.sh first." >&2
  exit 1
fi

expected_source="https://raw.githubusercontent.com/argoproj/argo-cd/${ARGO_CD_VERSION}/manifests/install.yaml"
if ! grep -F -- "${expected_source}" "${KUSTOMIZATION_FILE}" >/dev/null; then
  echo "Argo CD source does not match ARGO_CD_VERSION=${ARGO_CD_VERSION}." >&2
  exit 1
fi

kubectl --context "${KUBE_CONTEXT}" get namespace argocd >/dev/null

echo "Installing Argo CD ${ARGO_CD_VERSION}..."
kubectl --context "${KUBE_CONTEXT}" apply \
  --namespace argocd \
  --server-side \
  --force-conflicts \
  --kustomize "${REPOSITORY_ROOT}/bootstrap/argocd"

"${SCRIPT_DIR}/verify-argocd.sh"
