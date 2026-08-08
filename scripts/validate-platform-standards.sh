#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

for required_command in kubectl jq yq; do
  if ! command -v "${required_command}" >/dev/null 2>&1; then
    echo "Required command not found: ${required_command}" >&2
    exit 1
  fi
done

temporary_directory="$(mktemp -d)"
cleanup() {
  rm -rf -- "${temporary_directory}"
}
trap cleanup EXIT

environment_name() {
  case "$1" in
    dev) printf '%s\n' development ;;
    staging) printf '%s\n' staging ;;
    prod) printf '%s\n' production ;;
  esac
}

for environment in dev staging prod; do
  namespace="apps-${environment}"
  label="$(environment_name "${environment}")"
  rendered_manifest="${temporary_directory}/${environment}.yaml"
  rendered_json="${temporary_directory}/${environment}.json"

  kubectl kustomize \
    "${REPOSITORY_ROOT}/applications/vaipex-demo/overlays/${environment}" \
    > "${rendered_manifest}"
  yq eval-all --output-format json --indent 0 '.' "${rendered_manifest}" \
    > "${rendered_json}"

  if ! jq --slurp --exit-status \
    --arg namespace "${namespace}" \
    --arg environment "${label}" '
      [.[] | select(.kind == "Deployment")] as $deployments |
      [.[] | select(.kind == "Service")] as $services |
      [.[] | select(.kind == "ServiceAccount")] as $service_accounts |
      ($deployments | length) == 1 and
      ($services | length) == 1 and
      ($service_accounts | length) == 1 and
      ($deployments[0].metadata.namespace == $namespace) and
      ($deployments[0].metadata.labels["vaipex.io/environment"] == $environment) and
      ($deployments[0].spec.strategy.type == "RollingUpdate") and
      ($deployments[0].spec.strategy.rollingUpdate.maxUnavailable == 0) and
      ($deployments[0].spec.template.spec.securityContext.runAsNonRoot == true) and
      ($deployments[0].spec.template.spec.securityContext.seccompProfile.type == "RuntimeDefault") and
      all($deployments[0].spec.template.spec.containers[];
        (.image | test("@sha256:[a-f0-9]{64}$")) and
        (.securityContext.allowPrivilegeEscalation == false) and
        (.securityContext.readOnlyRootFilesystem == true) and
        ((.securityContext.capabilities.drop | index("ALL")) != null) and
        (.resources.requests.cpu != null) and
        (.resources.requests.memory != null) and
        (.resources.limits.cpu != null) and
        (.resources.limits.memory != null) and
        (.livenessProbe != null) and
        (.readinessProbe != null)
      ) and
      ($services[0].metadata.namespace == $namespace) and
      ($services[0].spec.type == "ClusterIP") and
      ($service_accounts[0].metadata.namespace == $namespace) and
      ($service_accounts[0].automountServiceAccountToken == false)
    ' "${rendered_json}" >/dev/null; then
    echo "Platform standards failed for ${environment}." >&2
    exit 1
  fi

  echo "Platform standards passed for ${environment}."
done

namespace_json="${temporary_directory}/namespaces.json"
yq eval-all --output-format json --indent 0 '.' \
  "${REPOSITORY_ROOT}/bootstrap/namespaces.yaml" \
  > "${namespace_json}"

if ! jq --slurp --exit-status '
  [.[] | select(
    .kind == "Namespace" and
    (.metadata.name == "apps-dev" or
     .metadata.name == "apps-staging" or
     .metadata.name == "apps-prod")
  )] as $namespaces |
  ($namespaces | length) == 3 and
  all($namespaces[];
    .metadata.labels["pod-security.kubernetes.io/enforce"] == "restricted" and
    .metadata.labels["pod-security.kubernetes.io/audit"] == "restricted" and
    .metadata.labels["pod-security.kubernetes.io/warn"] == "restricted"
  )
' "${namespace_json}" >/dev/null; then
  echo "Application namespaces must retain the restricted Pod Security profile." >&2
  exit 1
fi

echo "Namespace security standards passed."
