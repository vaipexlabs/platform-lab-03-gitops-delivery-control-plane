#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=../versions.env
source "${REPOSITORY_ROOT}/versions.env"

if ! command -v kind >/dev/null 2>&1 || ! command -v kubectl >/dev/null 2>&1; then
  echo "kind and kubectl are required." >&2
  exit 1
fi

cluster_found=false
for existing_cluster in $(kind get clusters); do
  if [[ "${existing_cluster}" == "${CLUSTER_NAME}" ]]; then
    cluster_found=true
    break
  fi
done

if [[ "${cluster_found}" != "true" ]]; then
  echo "Cluster ${CLUSTER_NAME} does not exist." >&2
  exit 1
fi

kubectl --context "${KUBE_CONTEXT}" wait \
  --for=condition=Ready \
  nodes \
  --all \
  --timeout=120s

for namespace in argocd apps-dev apps-staging apps-prod; do
  kubectl --context "${KUBE_CONTEXT}" get namespace "${namespace}" >/dev/null
done

echo
echo "Cluster nodes:"
kubectl --context "${KUBE_CONTEXT}" get nodes --output=wide

echo
echo "Platform namespaces:"
kubectl --context "${KUBE_CONTEXT}" get namespaces \
  --selector app.kubernetes.io/part-of=vaipex-gitops-control-plane \
  --show-labels

echo
echo "Cluster ${CLUSTER_NAME} is ready on context ${KUBE_CONTEXT}."
