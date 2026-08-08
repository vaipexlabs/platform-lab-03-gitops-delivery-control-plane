#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=../versions.env
source "${REPOSITORY_ROOT}/versions.env"

if ! command -v kind >/dev/null 2>&1; then
  echo "Required command not found: kind" >&2
  exit 1
fi

kind delete cluster --name "${CLUSTER_NAME}"
