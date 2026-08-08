# Vaipex GitOps Delivery Control Plane

An open reference implementation for promoting immutable application releases
across Kubernetes environments through pull-request governance, automated
validation, and continuous reconciliation with Argo CD.

Developed by **Vaipex Labs** for the developer and platform engineering
community.

![GitOps](https://img.shields.io/badge/Delivery-GitOps-326CE5)
![Kubernetes](https://img.shields.io/badge/Runtime-Kubernetes-326CE5?logo=kubernetes&logoColor=white)
![Argo CD](https://img.shields.io/badge/Reconciliation-Argo%20CD-EF7B4D?logo=argo&logoColor=white)
![Validation](https://img.shields.io/badge/Validation-Kubeconform-2E8B57)
![License](https://img.shields.io/badge/License-Apache%202.0-blue)

## What This Project Delivers

| Capability                       | What it demonstrates                                                                                         |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Git as desired state             | Every approved environment configuration is version controlled and auditable                                 |
| Three-environment delivery       | One immutable release moves through development, staging, and production                                     |
| Pull-request promotion           | GitHub Actions proposes digest-only environment changes for review                                           |
| Governed rollback                | Automation can restore only a digest previously approved in the target environment                           |
| Continuous reconciliation        | Argo CD detects merged Git changes and converges Kubernetes automatically                                    |
| Drift detection and self-healing | Out-of-band cluster changes are surfaced and reversed                                                        |
| Automated quality gates          | Kustomize rendering, Kubernetes schemas, promotion order, and change scope are validated                     |
| Secure workload defaults         | Non-root execution, restricted privileges, read-only filesystems, probes, and resource controls are enforced |
| Constrained deployment authority | Argo CD projects restrict repositories, namespaces, and permitted resource kinds                             |
| Credential separation            | CI proposes changes without credentials that can mutate production clusters                                  |
| Reproducible local platform      | Pinned `kind`, Kubernetes, Argo CD, and validation versions create a repeatable demonstration                |
| Operational evidence             | One command proves validation, reconciliation, release identity, readiness, and Git history                  |

## Why It Matters

Traditional delivery pipelines often combine artifact creation, environment
configuration, production credentials, and imperative deployment commands.
That makes it difficult to identify the approved state, detect drift, and
recover consistently.

This project separates those responsibilities:

- Application CI produces an immutable artifact.
- Git records which artifact is approved for each environment.
- Pull requests and automated checks govern desired-state changes.
- Argo CD—not CI—owns deployment and ongoing reconciliation.
- Git history provides the audit and recovery path.

## Delivery Flow

<p align="center">
  <img
    src="https://raw.githubusercontent.com/vaipexlabs/platform-lab-03-gitops-delivery-control-plane/main/docs/images/vaipex-gitops-delivery-control-plane-flow.png"
    alt="Vaipex GitOps Delivery Control Plane flow"
    width="100%"
  />
</p>

1. Application CI tests and publishes an image identified by a SHA-256 digest.
2. Automation proposes that digest for an environment through a pull request.
3. Repository checks validate schemas, platform standards, promotion order,
   rollback history, and change scope.
4. An authorized reviewer approves and merges the desired-state change.
5. Argo CD detects the new Git revision and reconciles the target environment.
6. Kubernetes health and Argo CD status provide operational feedback.

CI never deploys directly to Kubernetes. Its responsibility ends after
verification and change proposal.

## See It in Two Minutes

> **Important:** The two-minute timer starts after the local platform is
> running. Creating the platform requires **Docker, kind, and kubectl**. The
> timed demonstration also requires **kubeconform, jq, and yq**. Follow
> [First-Time Local Setup](#first-time-local-setup) before running the demo on a
> new workstation.

The timed demo assumes the `vaipex-gitops` kind cluster is already bootstrapped
with Argo CD and all applications are reconciled.

### 1. Install the demo tools

```bash
brew install kubectl kubeconform jq yq
```

The first schema-validation run requires internet access so kubeconform can
retrieve the pinned Kubernetes schemas.

### 2. Run the demonstration

```bash
./scripts/two-minute-demo.sh
```

### 3. Follow the four proof points

The script is read-only and walks through the platform in this order:

#### Step 1 — Validate desired state

- Renders the development, staging, and production Kustomize overlays.
- Validates every rendered resource against the pinned Kubernetes schema.
- Checks immutable image digests, security contexts, resource requests and
  limits, health probes, service-account behavior, and Pod Security labels.

Expected evidence:

```text
GitOps manifest validation passed.
```

#### Step 2 — Verify reconciliation

- Reads the root Argo CD application and all three environment applications.
- Requires each application to report `Synced` and `Healthy`.
- Displays the Git revision currently observed by each application.

#### Step 3 — Compare Git with the runtime

- Reads the approved digest from each environment overlay.
- Reads the image and replica state from the live Kubernetes deployment.
- Fails if Git and the runtime disagree.

The output provides one row each for `dev`, `staging`, and `prod`, including
sync, health, ready replicas, and the deployed digest.

#### Step 4 — Show the audit trail

- Displays recent desired-state commits.
- Makes promotions and rollbacks visible as ordinary Git history.

Successful completion ends with:

```text
Demo complete: validated, reconciled, immutable, healthy, and auditable.
```

The command does not patch workloads, trigger a promotion, or change the
active `kubectl` context. See the [complete demo guide](docs/two-minute-demo.md)
for the presentation narrative and deeper follow-on demonstrations.

## First-Time Local Setup

### Prerequisites

- macOS with Homebrew
- Docker Desktop or another Docker-compatible runtime
- Git

Install the required CLIs:

```bash
brew install kind kubectl kubeconform jq yq
```

The repository intentionally pins a supported `kind` version. If Homebrew
installs a different version, follow the
[local environment guide](docs/local-environment.md) before creating the
cluster.

### Create the platform

```bash
./scripts/create-cluster.sh
./scripts/bootstrap-argocd.sh
```

Commit and push any desired-state changes before enabling reconciliation. Argo
CD reads `origin/main`, not an uncommitted local working tree.

```bash
./scripts/configure-reconciliation.sh
./scripts/two-minute-demo.sh
```

### Clean up

```bash
./scripts/delete-cluster.sh
```

The cleanup script deletes only the `vaipex-gitops` kind cluster. Git retains
the complete desired state.

## Explore the Platform

| Workflow                 | Command or entry point                                                                                                                          | Evidence                                       |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| Validate desired state   | `./scripts/validate-manifests.sh`                                                                                                               | Rendered schemas and platform standards pass   |
| Verify reconciliation    | `./scripts/verify-reconciliation.sh`                                                                                                            | Argo CD applications and workloads are healthy |
| Propose promotion        | [Propose image promotion](https://github.com/vaipexlabs/platform-lab-03-gitops-delivery-control-plane/actions/workflows/propose-promotion.yaml) | A digest-only promotion PR is created          |
| Propose rollback         | [Propose image rollback](https://github.com/vaipexlabs/platform-lab-03-gitops-delivery-control-plane/actions/workflows/propose-rollback.yaml)   | A historical-digest rollback PR is created     |
| Demonstrate self-healing | `./scripts/demonstrate-self-healing.sh`                                                                                                         | Development drift is detected and corrected    |
| Run the complete demo    | `./scripts/two-minute-demo.sh`                                                                                                                  | Git, Argo CD, and Kubernetes agree end to end  |

## Repository Map

```text
.
├── .github/workflows/       # Validation, promotion, and rollback automation
├── applications/
│   └── vaipex-demo/
│       ├── base/            # Secure reusable Kubernetes resources
│       └── overlays/        # Development, staging, and production state
├── bootstrap/               # Namespaces, Argo CD installation, and root app
├── clusters/local/          # Argo CD project and environment ApplicationSet
├── docs/                    # Architecture, operations, recovery, and adoption
├── kind/                    # Reproducible local cluster topology
├── scripts/                 # Lifecycle, validation, promotion, and demo tools
└── versions.env             # Supported tool and runtime versions
```

## Security and Governance Controls

- Images must use immutable SHA-256 digests.
- Workloads run as a non-root user with the runtime-default seccomp profile.
- Containers disable privilege escalation, drop all Linux capabilities, and
  use a read-only root filesystem.
- CPU and memory requests and limits are mandatory.
- Liveness and readiness probes are mandatory.
- Application namespaces enforce the restricted Pod Security profile.
- Service-account tokens are not mounted when the workload does not need them.
- Argo CD application projects restrict source repositories, destination
  namespaces, and resource kinds.
- CI has read-only validation access and no Kubernetes deployment credentials.
- Production rollback targets must already exist in production history.

These repository controls provide fast developer feedback. Organization-wide
admission policy belongs in a dedicated policy platform and can complement
this implementation at the documented boundary.

## Design Principles

- **Git is authoritative.** Manual cluster state never becomes desired state.
- **Artifacts are immutable.** Environments promote identity, not mutable tags.
- **Approval precedes deployment.** Production intent is reviewed in Git.
- **CI and reconciliation are separate.** CI validates; Argo CD deploys.
- **Drift is visible and recoverable.** Self-healing restores approved state.
- **Rollback is declarative.** Recovery is another reviewed Git change.
- **Exceptions are explicit.** Deviations require ownership, rationale, and an
  expiry path.

## Documentation

| Guide                                                        | Purpose                                                                   |
| ------------------------------------------------------------ | ------------------------------------------------------------------------- |
| [Reference architecture](docs/reference-architecture.md)     | Components, boundaries, trust model, topology, and failure behavior       |
| [Environment promotion contract](docs/promotion-contract.md) | Artifact identity, gates, ownership, drift, and rollback rules            |
| [Local Kubernetes environment](docs/local-environment.md)    | Pinned runtime, namespace security, creation, verification, and cleanup   |
| [Argo CD bootstrap](docs/argocd-bootstrap.md)                | Installation, version contract, and control-plane verification            |
| [Sample application](docs/sample-application.md)             | Reusable base, overlays, secure workload contract, and artifact choice    |
| [Automated reconciliation](docs/reconciliation.md)           | Root application, project constraints, ApplicationSet, and activation     |
| [Promotion workflow](docs/promotion-workflow.md)             | Automated PR proposal, sequencing policy, review, and reconciliation      |
| [Self-healing](docs/self-healing.md)                         | Controlled drift demonstration and operational safeguards                 |
| [Git-based rollback](docs/rollback.md)                       | Historical-digest validation, rollback PR, verification, and roll-forward |
| [GitOps validation](docs/gitops-validation.md)               | Schema checks, platform standards, CI controls, and local feedback        |
| [Two-minute demo](docs/two-minute-demo.md)                   | Demonstration narrative, expected evidence, and optional extensions       |
| [Operating model](docs/operating-model.md)                   | Roles, release flow, operational events, and service indicators           |
| [Adoption and customization](docs/adoption.md)               | Rollout sequence, production hardening, and supported extension points    |

## Adoption Boundaries

This repository demonstrates one application across three logical environments
in a local cluster. Production adopters should replace namespace-only isolation
with the appropriate cluster, account, network, identity, and regional
boundaries.

The following contracts should remain intact while implementations evolve:

- Git remains the reviewed desired-state record.
- Releases are promoted by immutable digest.
- CI does not receive direct production mutation privileges.
- Argo CD reconciles only approved repositories and destinations.
- Plaintext secrets do not enter the GitOps repository.
- Runtime admission policy complements repository validation rather than
  replacing developer feedback.

See [Adoption and Customization](docs/adoption.md) for supported extension
points and production-hardening guidance.

## Contributing

Community feedback and contributions are welcome. Changes should preserve the
declarative operating model, immutable promotion contract, environment
boundaries, and auditable history—or document a narrowly scoped exception.

## License

Licensed under the [Apache License 2.0](LICENSE).

Copyright 2026 Vaipex Labs.

## About Vaipex Labs

**Vaipex Labs** develops open reference implementations, engineering patterns,
and practical tools that help the developer community build reliable, secure,
and scalable software platforms.
