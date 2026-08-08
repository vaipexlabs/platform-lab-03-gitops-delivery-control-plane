# Adoption and Customization

The reference implementation is intentionally small, but its contracts can be
adopted across teams, repositories, clusters, and cloud accounts.

## Adoption Sequence

1. Define the organization’s environment, identity, review, and isolation
   boundaries.
2. Fork or template the repository and replace the demonstration application
   and repository coordinates.
3. Connect a non-production Argo CD instance with read-only repository access.
4. Integrate application CI so it proposes immutable image digests without
   receiving cluster credentials.
5. Configure branch protection, required checks, reviewers, and ownership.
6. Integrate secret management, observability, notifications, and policy
   services appropriate to the organization.
7. Prove promotion, drift recovery, rollback, and controller-failure behavior
   before onboarding production workloads.
8. Onboard teams incrementally and measure the platform service indicators.

## Supported Customization Boundaries

| Area              | Supported customization                                                           | Contract to preserve                                                |
| ----------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| Repository        | Name, hosting organization, branch rules, ownership, and directory composition    | Git remains the reviewed desired-state record                       |
| Application       | Workload type, ports, probes, resources, and reusable base                        | Rendered resources satisfy platform standards                       |
| Artifact registry | Registry provider, repository path, signing, provenance, and retention            | Environments reference immutable digests                            |
| Environments      | Names, count, overlays, clusters, accounts, regions, and approval depth           | Promotion order and destination ownership are explicit              |
| Argo CD topology  | Central, regional, or per-cluster controllers and application sets                | Reconciliation reads approved Git and cannot approve releases       |
| Secrets           | External Secrets, CSI drivers, sealed/encrypted workflows, or cloud secret stores | Plaintext secrets do not enter the repository                       |
| Validation        | Additional schema, security, cost, reliability, or organizational checks          | CI remains credential-free for runtime deployment                   |
| Admission policy  | Kyverno, Gatekeeper, or provider-native controls                                  | Runtime policy complements rather than replaces repository feedback |
| Notifications     | Chat, incident, change-management, and deployment-event integrations              | Notifications do not become an alternate deployment path            |

## Production Hardening

Before production use, replace local namespace isolation with the organization’s
required cluster, account, network, and identity boundaries. Add high
availability, backup and recovery, repository credentials from a secret
manager, controller observability, tested disaster recovery, and protected
administrative access.

The reference project deliberately excludes a bundled secret manager,
organization-wide admission controller, and cloud-specific infrastructure.
Those capabilities should integrate at explicit boundaries instead of being
silently coupled to the promotion contract.

## Non-Goals

Adoption should not turn this repository into:

- An application source-code monorepo.
- A mutable-image deployment mechanism.
- A store for plaintext credentials.
- A CI pipeline with direct production mutation privileges.
- A substitute for incident management, observability, or enterprise policy
  ownership.
