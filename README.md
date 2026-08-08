# Vaipex GitOps Delivery Control Plane

An open reference implementation for promoting immutable application releases
across Kubernetes environments through Git-based change control, continuous
reconciliation, and explicit platform guardrails.

Developed by **Vaipex Labs** for the developer and platform engineering
community.

![GitOps](https://img.shields.io/badge/Delivery-GitOps-326CE5)
![Kubernetes](https://img.shields.io/badge/Runtime-Kubernetes-326CE5?logo=kubernetes&logoColor=white)
![Argo CD](https://img.shields.io/badge/Reconciliation-Argo%20CD-EF7B4D?logo=argo&logoColor=white)
![License](https://img.shields.io/badge/License-Apache%202.0-blue)

## Project at a Glance

| Area                 | Intended capability                                                             |
| -------------------- | ------------------------------------------------------------------------------- |
| Desired state        | Git records the approved application and environment configuration              |
| Reconciliation       | Argo CD continuously compares Git with each Kubernetes environment              |
| Promotion            | The same immutable release moves through development, staging, and production   |
| Governance           | Pull requests, reviews, and automated policy checks protect environment changes |
| Drift control        | Out-of-band cluster changes are detected and corrected                          |
| Recovery             | Git history provides an auditable path to a known-good state                    |
| Developer experience | Teams receive a consistent release path without direct production access        |

## Why This Project Exists

Traditional deployment pipelines often combine artifact creation, environment
configuration, production credentials, and imperative deployment commands in
one workflow. That makes it harder to determine the approved state of an
environment, identify configuration drift, and reproduce or reverse a change.

This project demonstrates a GitOps operating model in which CI produces an
immutable artifact, Git records the desired environment state, and Argo CD
reconciles Kubernetes to that state. Production changes become reviewable,
auditable, and recoverable through the same version-control workflow used for
software changes.

## Intended Delivery Flow

<p align="center">
  <img
    src="https://raw.githubusercontent.com/vaipexlabs/platform-lab-03-gitops-delivery-control-plane/main/docs/images/vaipex-gitops-delivery-control-plane-flow.png"
    alt="Vaipex GitOps Delivery Control Plane flow"
    width="100%"
  />
</p>

CI will not deploy directly to Kubernetes. Its responsibility ends after
building, verifying, and identifying the immutable release. Argo CD owns
deployment reconciliation from the approved state stored in Git.

## Architecture and Contracts

The [Reference Architecture](docs/reference-architecture.md) defines the
system components, repository boundaries, environment topology, Argo CD
control model, trust relationships, secret boundary, and failure behavior.

The [Environment Promotion Contract](docs/promotion-contract.md) defines the
immutable release identity, minimum promotion gates, validation rules, drift
behavior, rollback path, and ownership model.

The [Local Kubernetes Environment](docs/local-environment.md) documents the
pinned runtime, namespace security contract, lifecycle scripts, and local
verification workflow.

The [Argo CD Bootstrap](docs/argocd-bootstrap.md) documents the pinned
installation, verification contract, and boundary between cluster bootstrap
and application configuration.

The [Sample Application](docs/sample-application.md) documents the immutable
Go demonstration artifact, reusable Kubernetes base, environment overlays, and
secure workload contract.

The [Automated Reconciliation](docs/reconciliation.md) guide documents the root
application, project guardrails, environment generation, activation, and
health-verification workflow.

## Delivery Roadmap

- [x] Initialize the public repository with Apache License 2.0, a GitOps-aware
      `.gitignore`, and the project delivery contract.
- [x] Define the reference architecture, repository boundaries, trust model,
      and environment-promotion contract.
- [x] Create a reproducible local Kubernetes environment with `kind`.
- [x] Bootstrap Argo CD from version-controlled configuration.
- [x] Define a sample application using reusable Kubernetes bases and
      environment overlays.
- [ ] Configure automated reconciliation and health reporting for development,
      staging, and production.
- [ ] Implement pull-request-based promotion of the same immutable image digest
      between environments.
- [ ] Demonstrate drift detection and automated self-healing.
- [ ] Demonstrate rollback by reverting the desired state in Git.
- [ ] Add policy guardrails for security, resources, and deployment standards.
- [ ] Add automated validation for manifests, configuration, and promotion
      rules.
- [ ] Document the two-minute demo, operating model, adoption guidance, and
      supported customization boundaries.

## Planned Repository Structure

```text
.
├── bootstrap/              # Argo CD installation and root configuration
├── clusters/               # Environment entry points
│   ├── dev/
│   ├── staging/
│   └── prod/
├── applications/           # Reusable application definitions
├── policies/               # Platform validation and admission policies
├── scripts/                # Reproducible local workflows
└── docs/                   # Architecture, operations, and adoption guidance
```

The structure will evolve only when an implementation increment establishes a
clear ownership or deployment boundary.

## Core Principles

- **Git is the desired-state record.** Approved environment configuration is
  version controlled and reviewable.
- **Artifacts are immutable.** Environments promote the same image digest
  rather than rebuilding application code.
- **CI and deployment are separated.** CI validates and publishes; Argo CD
  reconciles.
- **Production access is minimized.** Application delivery does not require CI
  to hold production cluster credentials.
- **Drift is visible.** Manual cluster changes are detected rather than silently
  becoming the new standard.
- **Rollback is declarative.** Recovery restores a known-good Git state and lets
  reconciliation converge the cluster.
- **Exceptions are explicit.** Policy deviations require a documented review
  path.

## Scope

The initial implementation focuses on one application promoted through three
logical Kubernetes environments. It is not intended to provide a general
multi-cloud control plane, replace an artifact registry, or demonstrate every
Argo ecosystem capability.

## Contributing

Community feedback and contributions are welcome. Changes should preserve the
declarative operating model, immutable promotion contract, environment
boundaries, and auditable change history—or document a narrowly scoped
exception.

## License

Licensed under the [Apache License 2.0](LICENSE).

Copyright 2026 Vaipex Labs.

## About Vaipex Labs

**Vaipex Labs** develops open reference implementations, engineering patterns,
and practical tools that help the developer community build reliable, secure,
and scalable software platforms.
