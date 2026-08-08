# Argo CD Bootstrap

Argo CD is the reconciliation engine for the local GitOps control plane. The
bootstrap installs a pinned upstream release and verifies its APIs and runtime
components before application configuration is introduced.

## Version Contract

The repository pins Argo CD `v3.4.2` in two places:

- `versions.env` declares the supported release.
- `bootstrap/argocd/kustomization.yaml` references that exact upstream
  installation manifest.

The bootstrap script refuses to proceed if these values differ. It never
follows the moving `stable` branch.

## Install

Create the local cluster first, then run:

```bash
./scripts/bootstrap-argocd.sh
```

The script:

1. Confirms that `kind` and `kubectl` are available.
2. Confirms that the `vaipex-gitops` cluster and `argocd` namespace exist.
3. Validates that the declared version matches the Kustomize source.
4. Applies the official non-HA manifests using server-side apply.
5. Runs the independent verification workflow.

Every cluster operation uses the explicit `kind-vaipex-gitops` context. The
currently selected `kubectl` context is not changed.

The command is declarative and can be run again. Kubernetes updates resources
whose desired configuration changed and leaves matching resources in place.

## Verify

```bash
./scripts/verify-argocd.sh
```

Verification confirms that the `Application`, `ApplicationSet`, and
`AppProject` custom resource definitions are established. It then waits for all
Argo CD deployments and the application-controller StatefulSet to become
available and displays the resulting pods.

This proves that the reconciliation control plane is operational. It does not
yet configure a Git repository or authorize application destinations; those
responsibilities will be added as version-controlled Argo CD resources.

## Installation Choice

The standard non-HA manifest is appropriate for a local demonstration that
deploys into the same cluster. Production adoption should evaluate high
availability, external identity, ingress, network policy, least-privilege
cluster access, secret management, backup, and disaster recovery requirements.

## References

- [Argo CD v3.4.2 release](https://github.com/argoproj/argo-cd/releases/tag/v3.4.2)
- [Argo CD installation guidance](https://argo-cd.readthedocs.io/en/latest/operator-manual/installation/)
