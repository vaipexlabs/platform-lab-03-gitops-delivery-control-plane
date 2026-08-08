# Operating Model

The control plane treats application delivery as a platform product with
explicit responsibilities, service boundaries, and recovery paths.

## Roles and Responsibilities

| Role                   | Owns                                                                             | Does not require                             |
| ---------------------- | -------------------------------------------------------------------------------- | -------------------------------------------- |
| Application team       | Application quality, release candidate, and promotion request                    | Direct production-cluster credentials        |
| Platform team          | GitOps contract, reusable manifests, validation, Argo CD, and paved-road support | Approval of every development release        |
| Environment reviewer   | Risk review and production change approval                                       | Imperative deployment access                 |
| Security or governance | Organization-wide policy and exception criteria                                  | Ownership of application delivery workflows  |
| Argo CD                | Continuous comparison, sync, pruning, self-healing, and health reporting         | Permission to approve releases or modify Git |

## Standard Release Flow

1. Application CI tests and publishes one immutable image digest.
2. Automation proposes that digest for development through a pull request.
3. Repository validation checks schema, security, resources, and change scope.
4. The same digest advances through staging and production after the applicable
   reviews.
5. Argo CD detects each merged desired-state change and reconciles the target
   environment.
6. Sync, health, workload readiness, and Git history provide delivery evidence.

## Operational Events

| Event                       | Response                                                                                         |
| --------------------------- | ------------------------------------------------------------------------------------------------ |
| Validation failure          | Correct the proposed Git change; do not bypass the gate                                          |
| Argo CD reports `OutOfSync` | Determine whether Git changed or the cluster drifted; allow reconciliation to converge           |
| Argo CD reports `Degraded`  | Inspect workload health and Kubernetes events while preserving Git as the desired-state record   |
| Bad approved release        | Propose a rollback to a digest previously approved in that environment                           |
| Reconciliation unavailable  | Existing workloads continue; restore the controller before processing new delivery changes       |
| Policy exception            | Record scope, owner, rationale, expiry, and compensating control outside an ad hoc manifest edit |

## Platform Service Indicators

Adopting teams should measure:

- Promotion lead time from approved artifact to healthy environment.
- Percentage of applications reporting `Synced` and `Healthy`.
- Validation failure rate and most common developer feedback.
- Drift frequency and automated recovery time.
- Rollback frequency and time to restore a known-good release.
- Age and ownership of approved policy exceptions.

These indicators evaluate the delivery product without equating deployment
frequency alone with platform success.
