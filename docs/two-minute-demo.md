# Two-Minute Demo

The demonstration provides a concise, read-only view of the complete delivery
control plane. It validates the desired state and proves that Git, Argo CD, and
the Kubernetes runtime agree on the deployed release.

## Prerequisites

The local platform must already be running and reconciled. First-time users
should complete the [local environment](local-environment.md),
[Argo CD bootstrap](argocd-bootstrap.md), and
[reconciliation](reconciliation.md) guides before starting the timed demo.

Install the local validation tools:

```bash
brew install kubectl kubeconform jq yq
```

## Run

From the repository root:

```bash
./scripts/two-minute-demo.sh
```

The command is read-only. It does not patch workloads, trigger a promotion, or
change the active `kubectl` context.

## Demonstration Narrative

| Time      | Evidence                                                        | Platform message                                                 |
| --------- | --------------------------------------------------------------- | ---------------------------------------------------------------- |
| 0:00–0:30 | Kustomize rendering, schema checks, and platform standards pass | Invalid or unsafe desired state is rejected before deployment    |
| 0:30–0:50 | Root and environment applications report `Synced` and `Healthy` | Argo CD continuously reconciles approved Git state               |
| 0:50–1:30 | Git digests match live images and replicas are ready            | The same immutable release identity is observable end to end     |
| 1:30–2:00 | Recent overlay commits are displayed                            | Promotions and rollbacks retain a version-controlled audit trail |

## Expected Result

The final line is:

```text
Demo complete: validated, reconciled, immutable, healthy, and auditable.
```

Any mismatch causes a nonzero exit rather than presenting an ambiguous success.

## Optional Follow-On Demonstrations

The two-minute path intentionally avoids mutations. Use the focused guides for
deeper demonstrations:

- [Pull-request promotion](promotion-workflow.md)
- [Drift detection and self-healing](self-healing.md)
- [Git-based rollback](rollback.md)
