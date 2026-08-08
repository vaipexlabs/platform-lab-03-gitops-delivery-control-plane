#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APPLICATION_NAME=vaipex-demo-dev
NAMESPACE=apps-dev
DEPLOYMENT_NAME=vaipex-demo
OVERLAY_PATH="${REPOSITORY_ROOT}/applications/vaipex-demo/overlays/dev"

# shellcheck source=../versions.env
source "${REPOSITORY_ROOT}/versions.env"

required_commands=(kubectl)
for required_command in "${required_commands[@]}"; do
  if ! command -v "${required_command}" >/dev/null 2>&1; then
    echo "Required command not found: ${required_command}" >&2
    exit 1
  fi
done

desired_replicas="$(
  kubectl kustomize "${OVERLAY_PATH}" \
    | kubectl create \
      --dry-run=client \
      --validate=false \
      --filename - \
      --output=jsonpath='{.spec.replicas}' \
      2>/dev/null
)"

if [[ ! "${desired_replicas}" =~ ^[1-9][0-9]*$ ]]; then
  echo "Could not determine a positive desired replica count from Git." >&2
  exit 1
fi

sync_status="$(
  kubectl --context "${KUBE_CONTEXT}" get application "${APPLICATION_NAME}" \
    --namespace argocd \
    --output=jsonpath='{.status.sync.status}'
)"
health_status="$(
  kubectl --context "${KUBE_CONTEXT}" get application "${APPLICATION_NAME}" \
    --namespace argocd \
    --output=jsonpath='{.status.health.status}'
)"
live_replicas="$(
  kubectl --context "${KUBE_CONTEXT}" get deployment "${DEPLOYMENT_NAME}" \
    --namespace "${NAMESPACE}" \
    --output=jsonpath='{.spec.replicas}'
)"

if [[ "${sync_status}" != "Synced" || "${health_status}" != "Healthy" ]]; then
  echo "${APPLICATION_NAME} must be Synced and Healthy before the demonstration." >&2
  exit 1
fi

if [[ "${live_replicas}" != "${desired_replicas}" ]]; then
  echo "Live replicas (${live_replicas}) already differ from Git (${desired_replicas})." >&2
  exit 1
fi

drifted_replicas="$((desired_replicas + 2))"
recovery_complete=false

restore_desired_state() {
  if [[ "${recovery_complete}" != "true" ]]; then
    echo "Restoring the safe development replica count after an incomplete demonstration." >&2
    kubectl --context "${KUBE_CONTEXT}" scale deployment "${DEPLOYMENT_NAME}" \
      --namespace "${NAMESPACE}" \
      --replicas "${desired_replicas}" >/dev/null || true
  fi
}
trap restore_desired_state EXIT

echo "Git declares ${desired_replicas} development replica."
echo "Introducing controlled live drift: ${desired_replicas} -> ${drifted_replicas}."
kubectl --context "${KUBE_CONTEXT}" scale deployment "${DEPLOYMENT_NAME}" \
  --namespace "${NAMESPACE}" \
  --replicas "${drifted_replicas}" >/dev/null

observed_live_replicas="$(
  kubectl --context "${KUBE_CONTEXT}" get deployment "${DEPLOYMENT_NAME}" \
    --namespace "${NAMESPACE}" \
    --output=jsonpath='{.spec.replicas}'
)"
if [[ "${observed_live_replicas}" != "${drifted_replicas}" ]]; then
  echo "The controlled drift was not applied." >&2
  exit 1
fi

echo "Live drift confirmed at ${observed_live_replicas} replicas."
kubectl --context "${KUBE_CONTEXT}" annotate application "${APPLICATION_NAME}" \
  --namespace argocd \
  argocd.argoproj.io/refresh=hard \
  --overwrite >/dev/null

out_of_sync_observed=false
for attempt in {1..60}; do
  current_sync_status="$(
    kubectl --context "${KUBE_CONTEXT}" get application "${APPLICATION_NAME}" \
      --namespace argocd \
      --output=jsonpath='{.status.sync.status}'
  )"
  if [[ "${current_sync_status}" == "OutOfSync" ]]; then
    out_of_sync_observed=true
    echo "Argo CD reported the application OutOfSync."
    break
  fi
  sleep 1
done

for attempt in {1..90}; do
  current_replicas="$(
    kubectl --context "${KUBE_CONTEXT}" get deployment "${DEPLOYMENT_NAME}" \
      --namespace "${NAMESPACE}" \
      --output=jsonpath='{.spec.replicas}'
  )"
  current_sync_status="$(
    kubectl --context "${KUBE_CONTEXT}" get application "${APPLICATION_NAME}" \
      --namespace argocd \
      --output=jsonpath='{.status.sync.status}'
  )"
  current_health_status="$(
    kubectl --context "${KUBE_CONTEXT}" get application "${APPLICATION_NAME}" \
      --namespace argocd \
      --output=jsonpath='{.status.health.status}'
  )"

  if [[ "${current_replicas}" == "${desired_replicas}" \
    && "${current_sync_status}" == "Synced" \
    && "${current_health_status}" == "Healthy" ]]; then
    recovery_complete=true
    break
  fi
  sleep 2
done

if [[ "${recovery_complete}" != "true" ]]; then
  echo "Argo CD did not restore the desired state within 180 seconds." >&2
  exit 1
fi

trap - EXIT

if [[ "${out_of_sync_observed}" != "true" ]]; then
  echo "Argo CD healed the drift before the OutOfSync state could be sampled."
fi

echo "Self-healing succeeded: Git and the live Deployment both declare ${desired_replicas} replica."
kubectl --context "${KUBE_CONTEXT}" get application "${APPLICATION_NAME}" \
  --namespace argocd \
  --output=wide
kubectl --context "${KUBE_CONTEXT}" get deployment,pods \
  --namespace "${NAMESPACE}"
