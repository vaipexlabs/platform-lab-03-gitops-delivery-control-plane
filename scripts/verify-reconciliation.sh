#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=../versions.env
source "${REPOSITORY_ROOT}/versions.env"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "Required command not found: kubectl" >&2
  exit 1
fi

expected_applications=(vaipex-root vaipex-demo-dev vaipex-demo-staging vaipex-demo-prod)

for application in "${expected_applications[@]}"; do
  kubectl --context "${KUBE_CONTEXT}" wait \
    --namespace argocd \
    --for=create \
    "application/${application}" \
    --timeout=180s

  kubectl --context "${KUBE_CONTEXT}" wait \
    --namespace argocd \
    --for=jsonpath='{.status.sync.status}'=Synced \
    "application/${application}" \
    --timeout=300s

  kubectl --context "${KUBE_CONTEXT}" wait \
    --namespace argocd \
    --for=jsonpath='{.status.health.status}'=Healthy \
    "application/${application}" \
    --timeout=300s
done

echo
echo "Argo CD applications:"
kubectl --context "${KUBE_CONTEXT}" get applications \
  --namespace argocd \
  --output=wide

echo
echo "Application workloads:"
for namespace in apps-dev apps-staging apps-prod; do
  kubectl --context "${KUBE_CONTEXT}" get deployments,pods \
    --namespace "${namespace}"
done

echo
echo "Git reconciliation is synced and healthy on context ${KUBE_CONTEXT}."
