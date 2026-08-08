#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=../versions.env
source "${REPOSITORY_ROOT}/versions.env"

required_commands=(git kubectl)
for required_command in "${required_commands[@]}"; do
  if ! command -v "${required_command}" >/dev/null 2>&1; then
    echo "Required command not found: ${required_command}" >&2
    exit 1
  fi
done

if [[ -n "$(git -C "${REPOSITORY_ROOT}" status --porcelain)" ]]; then
  echo "Repository has uncommitted changes. Commit and push the desired state first." >&2
  exit 1
fi

local_revision="$(git -C "${REPOSITORY_ROOT}" rev-parse HEAD)"
remote_revision="$(git -C "${REPOSITORY_ROOT}" rev-parse origin/main)"
if [[ "${local_revision}" != "${remote_revision}" ]]; then
  echo "Local HEAD does not match origin/main. Push the desired state first." >&2
  exit 1
fi

"${SCRIPT_DIR}/verify-argocd.sh" >/dev/null

echo "Bootstrapping the root Argo CD application..."
kubectl --context "${KUBE_CONTEXT}" apply \
  --namespace argocd \
  --filename "${REPOSITORY_ROOT}/bootstrap/root-application.yaml"

"${SCRIPT_DIR}/verify-reconciliation.sh"
