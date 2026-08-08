# Local Kubernetes Environment

The local environment provides a reproducible Kubernetes control plane for the
GitOps demonstration. It uses one `kind` cluster with a control-plane node, a
worker node, and four platform namespaces.

## Pinned Runtime

| Component       | Version                                                                                        |
| --------------- | ---------------------------------------------------------------------------------------------- |
| kind            | `v0.32.0`                                                                                      |
| Kubernetes      | `v1.36.1`                                                                                      |
| Node image      | `kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5` |
| Cluster name    | `vaipex-gitops`                                                                                |
| kubectl context | `kind-vaipex-gitops`                                                                           |

The node image is pinned by digest so the same configuration does not silently
select different image content over time.

## Prerequisites

- Docker Desktop or another Docker-compatible runtime
- [`kind` v0.32.0](https://github.com/kubernetes-sigs/kind/releases/tag/v0.32.0)
- `kubectl`

## Create the Cluster

```bash
./scripts/create-cluster.sh
```

The script:

1. Verifies required commands and the pinned `kind` version.
2. Confirms the Docker daemon is available.
3. Creates the `vaipex-gitops` cluster from `kind/cluster.yaml`.
4. Applies the platform namespace contract.
5. Waits for every node to become ready.
6. Runs the cluster verification workflow.

The command is idempotent. If the cluster already exists, it verifies the
existing cluster without replacing it. During creation, `kind` temporarily
selects the new cluster. The script records and restores the previously selected
`kubectl` context before it exits.

## Namespace Contract

| Namespace      | Purpose                         | Pod Security admission                             |
| -------------- | ------------------------------- | -------------------------------------------------- |
| `argocd`       | GitOps control-plane components | Baseline enforcement; restricted audit and warning |
| `apps-dev`     | Development workloads           | Restricted enforcement                             |
| `apps-staging` | Staging workloads               | Restricted enforcement                             |
| `apps-prod`    | Production workloads            | Restricted enforcement                             |

Pod Security admission versions are pinned to the local Kubernetes minor
version instead of using the moving `latest` alias.

## Verify the Cluster

```bash
./scripts/verify-cluster.sh
```

Every cluster operation uses the explicit `kind-vaipex-gitops` context. The
scripts do not depend on the currently selected context.

## Validated Outcome

The workflow has been validated with one ready control-plane node, one ready
worker node, and all four platform namespaces active.

## Delete the Cluster

```bash
./scripts/delete-cluster.sh
```

This deletes only the cluster named `vaipex-gitops`. The complete desired state
remains in Git and can be recreated with the create script.

## Troubleshooting

If cluster creation reports that Docker is unavailable, start Docker Desktop
and confirm it is ready:

```bash
docker info
```

If the installed `kind` version differs from `versions.env`, install the pinned
release before creating the cluster. Node images are only guaranteed to be
compatible with the `kind` releases for which they were published.
