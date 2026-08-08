# Sample Application

The reference workload demonstrates how one immutable Go service is composed
for development, staging, and production without copying its Kubernetes
resources between environments.

## Artifact

The implementation currently uses
[`traefik/whoami` v1.11.0](https://github.com/traefik/whoami), a small
Apache-licensed Go HTTP service. It is pinned to the multi-architecture image
digest:

```text
docker.io/traefik/whoami@sha256:200689790a0a0ea48ca45992e0450bc26ccab5307375b41c84dfc4f2475937ab
```

The public image keeps the demonstration immediately reproducible while the
GitOps mechanics remain independent of the application language. A platform
adopter can replace the image name and digest with an artifact from its own
application delivery workflow.

## Composition

```text
applications/vaipex-demo/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── service-account.yaml
│   └── kustomization.yaml
└── overlays/
    ├── dev/kustomization.yaml
    ├── staging/kustomization.yaml
    └── prod/kustomization.yaml
```

The base owns the shared workload contract: identity, service discovery,
health probes, rollout behavior, resource controls, and container security.
Each overlay selects a namespace, adds an environment label, and records the
approved image digest. Production also demonstrates an explicit replica
difference.

| Environment | Namespace      | Replicas | Image identity             |
| ----------- | -------------- | -------- | -------------------------- |
| Development | `apps-dev`     | 1        | Explicit immutable digest  |
| Staging     | `apps-staging` | 1        | Same initial image digest  |
| Production  | `apps-prod`    | 2        | Same initial image digest  |

Future promotions will change one environment overlay at a time. The image is
not rebuilt as it moves between environments.

## Security Defaults

The pod contract supports the Kubernetes restricted Pod Security profile:

- Runs as a fixed non-root user and group.
- Uses the runtime-default seccomp profile.
- Disables privilege escalation.
- Drops every Linux capability.
- Uses a read-only root filesystem.
- Does not mount a Kubernetes API token.
- Declares CPU and memory requests and limits.

## Render

Render any environment without modifying a cluster:

```bash
kubectl kustomize applications/vaipex-demo/overlays/dev
kubectl kustomize applications/vaipex-demo/overlays/staging
kubectl kustomize applications/vaipex-demo/overlays/prod
```

These overlays are desired state only. They must not be applied manually. The
next delivery increment will configure Argo CD to reconcile them from Git.
