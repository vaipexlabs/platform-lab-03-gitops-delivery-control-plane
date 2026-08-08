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

for custom_resource_definition in \
  applications.argoproj.io \
  applicationsets.argoproj.io \
  appprojects.argoproj.io; do
  kubectl --context "${KUBE_CONTEXT}" wait \
    --for=condition=Established \
    "customresourcedefinition/${custom_resource_definition}" \
    --timeout=120s
done

kubectl --context "${KUBE_CONTEXT}" wait \
  --namespace argocd \
  --for=condition=Available \
  deployment \
  --all \
  --timeout=300s

kubectl --context "${KUBE_CONTEXT}" rollout status \
  --namespace argocd \
  statefulset/argocd-application-controller \
  --timeout=300s

echo
echo "Argo CD workloads:"
kubectl --context "${KUBE_CONTEXT}" get pods \
  --namespace argocd \
  --output=wide

echo
echo "Argo CD ${ARGO_CD_VERSION} is ready on context ${KUBE_CONTEXT}."
