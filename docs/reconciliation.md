# Automated Reconciliation

Argo CD converts the approved state on `main` into continuously reconciled
development, staging, and production workloads.

## Control Hierarchy

```text
bootstrap/root-application.yaml
└── watches clusters/local
    ├── AppProject: vaipex-applications
    └── ApplicationSet: vaipex-demo-environments
        ├── Application: vaipex-demo-dev
        ├── Application: vaipex-demo-staging
        └── Application: vaipex-demo-prod
```

Only the root `Application` is applied imperatively. It points Argo CD to the
version-controlled control-plane configuration. Argo CD then creates and owns
the project and application set, and the application set generates one
`Application` per environment.

## Project Guardrails

The `vaipex-applications` project permits:

- One explicit public source repository.
- Only namespaces matching `apps-*` in the local cluster.
- Only `Deployment`, `Service`, and `ServiceAccount` desired-state resources.
- No cluster-scoped resources.

This prevents an application definition from using the project to target an
unrelated namespace or introduce a cluster-wide resource.

## Environment Generation

The list generator records three explicit mappings:

| Generated application  | Source overlay                                      | Destination    |
| ---------------------- | --------------------------------------------------- | -------------- |
| `vaipex-demo-dev`      | `applications/vaipex-demo/overlays/dev`             | `apps-dev`     |
| `vaipex-demo-staging`  | `applications/vaipex-demo/overlays/staging`         | `apps-staging` |
| `vaipex-demo-prod`     | `applications/vaipex-demo/overlays/prod`            | `apps-prod`    |

Every generated application uses automated sync, pruning, and self-healing.
Argo CD therefore creates approved resources, removes resources deleted from
Git, and reverses out-of-band changes.

## Activate

The desired state must be committed and pushed before activation because Argo
CD reads the public repository, not the local working tree.

```bash
./scripts/configure-reconciliation.sh
```

The script refuses to continue if the working tree is dirty or local `HEAD`
does not match `origin/main`. It verifies Argo CD, applies the root application,
and waits for the root and all three generated applications to become synced
and healthy.

## Verify

```bash
./scripts/verify-reconciliation.sh
```

The verification displays Argo CD application status and the workloads in all
three namespaces. It uses the explicit `kind-vaipex-gitops` context and does not
change the currently selected `kubectl` context.

## Ownership Boundary

The bootstrap script creates the first pointer from the cluster to Git. After
that point, Git owns the project, application set, environment applications,
and application workloads. Manual `kubectl apply` commands are not part of the
application delivery path.
