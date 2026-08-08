#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=../versions.env
source "${REPOSITORY_ROOT}/versions.env"

for required_command in git jq kubectl kubeconform yq; do
  if ! command -v "${required_command}" >/dev/null 2>&1; then
    echo "Required command not found: ${required_command}" >&2
    exit 1
  fi
done

echo "Vaipex GitOps Delivery Control Plane"
echo "===================================="
echo
echo "1/4 Validate the desired-state repository"
"${SCRIPT_DIR}/validate-manifests.sh"

echo
echo "2/4 Verify Argo CD reconciliation"
expected_applications=(vaipex-root vaipex-demo-dev vaipex-demo-staging vaipex-demo-prod)
for application in "${expected_applications[@]}"; do
  sync_status="$(
    kubectl --context "${KUBE_CONTEXT}" \
      --namespace argocd \
      get "application/${application}" \
      --output jsonpath='{.status.sync.status}'
  )"
  health_status="$(
    kubectl --context "${KUBE_CONTEXT}" \
      --namespace argocd \
      get "application/${application}" \
      --output jsonpath='{.status.health.status}'
  )"

  if [[ "${sync_status}" != "Synced" || "${health_status}" != "Healthy" ]]; then
    echo "${application} is ${sync_status}/${health_status}; expected Synced/Healthy." >&2
    exit 1
  fi
done

kubectl --context "${KUBE_CONTEXT}" \
  --namespace argocd \
  get applications \
  --output custom-columns='APPLICATION:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REVISION:.status.sync.revision'

echo
echo "3/4 Compare Git desired state with the live runtime"
printf '%-10s %-12s %-12s %-8s %s\n' ENVIRONMENT SYNC HEALTH REPLICAS DIGEST

for environment in dev staging prod; do
  desired_digest="$(
    awk '$1 == "digest:" { print $2 }' \
      "${REPOSITORY_ROOT}/applications/vaipex-demo/overlays/${environment}/kustomization.yaml"
  )"
  application="vaipex-demo-${environment}"
  namespace="apps-${environment}"
  sync_status="$(
    kubectl --context "${KUBE_CONTEXT}" \
      --namespace argocd \
      get "application/${application}" \
      --output jsonpath='{.status.sync.status}'
  )"
  health_status="$(
    kubectl --context "${KUBE_CONTEXT}" \
      --namespace argocd \
      get "application/${application}" \
      --output jsonpath='{.status.health.status}'
  )"
  live_image="$(
    kubectl --context "${KUBE_CONTEXT}" \
      --namespace "${namespace}" \
      get deployment/vaipex-demo \
      --output jsonpath='{.spec.template.spec.containers[0].image}'
  )"
  ready_replicas="$(
    kubectl --context "${KUBE_CONTEXT}" \
      --namespace "${namespace}" \
      get deployment/vaipex-demo \
      --output jsonpath='{.status.readyReplicas}'
  )"
  desired_replicas="$(
    kubectl --context "${KUBE_CONTEXT}" \
      --namespace "${namespace}" \
      get deployment/vaipex-demo \
      --output jsonpath='{.spec.replicas}'
  )"

  if [[ "${live_image}" != *@"${desired_digest}" ]]; then
    echo "${environment} runtime image does not match Git desired state." >&2
    echo "Git:  ${desired_digest}" >&2
    echo "Live: ${live_image}" >&2
    exit 1
  fi

  printf '%-10s %-12s %-12s %-8s %s\n' \
    "${environment}" \
    "${sync_status}" \
    "${health_status}" \
    "${ready_replicas}/${desired_replicas}" \
    "${desired_digest}"
done

echo
echo "4/4 Show the auditable desired-state history"
git -C "${REPOSITORY_ROOT}" log \
  --max-count=5 \
  --oneline \
  -- applications/vaipex-demo/overlays

echo
echo "Demo complete: validated, reconciled, immutable, healthy, and auditable."
