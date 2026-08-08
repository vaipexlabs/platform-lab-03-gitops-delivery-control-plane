#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=../versions.env
source "${REPOSITORY_ROOT}/versions.env"

previous_context="$(kubectl config current-context 2>/dev/null || true)"

restore_previous_context() {
  if [[ -n "${previous_context}" && "${previous_context}" != "${KUBE_CONTEXT}" ]]; then
    kubectl config use-context "${previous_context}" >/dev/null
  fi
}

trap restore_previous_context EXIT

required_commands=(docker kind kubectl)
for required_command in "${required_commands[@]}"; do
  if ! command -v "${required_command}" >/dev/null 2>&1; then
    echo "Required command not found: ${required_command}" >&2
    exit 1
  fi
done

if ! docker info >/dev/null 2>&1; then
  echo "Docker is not running. Start Docker Desktop and try again." >&2
  exit 1
fi

installed_kind_version="$(kind version | awk '{print $2}')"
if [[ "${installed_kind_version}" != "${KIND_VERSION}" ]]; then
  echo "kind ${KIND_VERSION} is required; found ${installed_kind_version}." >&2
  exit 1
fi

for existing_cluster in $(kind get clusters); do
  if [[ "${existing_cluster}" == "${CLUSTER_NAME}" ]]; then
    echo "Cluster ${CLUSTER_NAME} already exists."
    "${SCRIPT_DIR}/verify-cluster.sh"
    exit 0
  fi
done

echo "Creating ${CLUSTER_NAME} with Kubernetes ${KUBERNETES_VERSION}..."
kind create cluster \
  --name "${CLUSTER_NAME}" \
  --image "${KIND_NODE_IMAGE}" \
  --config "${REPOSITORY_ROOT}/kind/cluster.yaml" \
  --wait 120s

kubectl --context "${KUBE_CONTEXT}" apply \
  --filename "${REPOSITORY_ROOT}/bootstrap/namespaces.yaml"

"${SCRIPT_DIR}/verify-cluster.sh"
