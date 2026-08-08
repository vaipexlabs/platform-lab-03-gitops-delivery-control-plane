# GitOps Validation

The repository validates desired state before it can become an approved GitOps
change. These checks run without cluster credentials and do not deploy
resources. Argo CD remains the only component responsible for reconciliation.

## Validation Layers

| Layer       | Validation                                                                       |
| ----------- | -------------------------------------------------------------------------------- |
| Repository  | Shell syntax and Git whitespace are valid                                        |
| Composition | Every application overlay renders successfully with Kustomize                    |
| Schema      | Rendered application resources conform to the pinned Kubernetes schema           |
| Artifact    | Every workload image uses an immutable SHA-256 digest                            |
| Security    | Workloads run as non-root with restricted privileges and filesystems             |
| Resources   | Every container defines CPU and memory requests and limits                       |
| Operations  | Deployments use safe rollout behavior, readiness probes, and liveness probes     |
| Identity    | Service account tokens are not mounted when the workload does not need them      |
| Namespace   | Application namespaces retain the restricted Pod Security profile                |
| Promotion   | A separate check validates environment order, rollback history, and change scope |

## Pull-Request Gate

The `GitOps validation` workflow runs for pull requests that change platform
configuration, application manifests, validation scripts, or pinned versions.
It installs the repository-pinned Kubernetes, kubeconform, and yq versions,
verifies their downloaded checksums, and runs the same validation entry point
available to contributors. Manifest policy evaluation is fully offline and
does not attempt Kubernetes API discovery.

The workflow has read-only repository permission. It does not receive a
kubeconfig, registry credential, or production secret.

## Run Locally

Install the prerequisites:

```bash
brew install kubectl kubeconform jq yq
```

Run the complete validation:

```bash
./scripts/validate-manifests.sh
```

Run only the Vaipex platform standards:

```bash
./scripts/validate-platform-standards.sh
```

The standards command is useful while authoring manifests because it avoids
network-dependent schema downloads. The complete command is the authoritative
local equivalent of the GitHub Actions gate.

## Responsibility Boundary

These checks provide fast feedback and protect the configuration repository.
They do not replace Kubernetes admission control. Organization-wide admission
policy, exception governance, and runtime policy reporting belong in a
dedicated policy platform rather than this GitOps delivery implementation.
