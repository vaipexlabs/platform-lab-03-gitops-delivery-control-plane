# Drift Detection and Self-Healing

Git remains authoritative after deployment. If a live Kubernetes resource
differs from its approved manifest, Argo CD detects the difference and restores
the desired state recorded on `main`.

## Demonstration Boundary

The demonstration changes only the replica count of the development
`vaipex-demo` Deployment. It does not touch staging, production, image digests,
credentials, or Git history.

```text
Git: development replicas = 1
              ↓
Operator changes live replicas to 3
              ↓
Argo CD compares live state with Git
              ↓
Application becomes OutOfSync
              ↓
Self-healing restores replicas to 1
              ↓
Application returns to Synced / Healthy
```

## Run

Begin with a clean, healthy environment, then execute:

```bash
./scripts/demonstrate-self-healing.sh
```

The script:

1. Renders the development overlay and reads its desired replica count.
2. Requires the live application to be `Synced` and `Healthy`.
3. Requires the live replica count to match Git before starting.
4. Introduces a controlled live-only replica change.
5. Requests an immediate Argo CD comparison.
6. Observes drift and waits for automatic reconciliation.
7. Requires the Deployment and application to return to their approved state.

If the demonstration does not finish successfully, an exit safeguard restores
the development replica count. This cleanup is a safety mechanism; a successful
run relies entirely on Argo CD self-healing.

## What This Proves

- A manual cluster edit does not redefine the approved environment.
- Drift becomes visible through Argo CD application status.
- Reconciliation removes the need for an operator to redeploy the service.
- The recovery target comes from Git rather than from an undocumented command.
- Production access is not required for a safe local demonstration.

## Production Considerations

Organizations should alert on unexpected drift, retain audit events, restrict
direct mutation through Kubernetes RBAC, and define a controlled emergency
access path. Self-healing should complement preventive controls rather than
serve as permission for routine manual changes.
