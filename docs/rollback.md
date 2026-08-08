# Git-Based Rollback

A rollback is a reviewed desired-state change that restores an immutable digest
previously approved in the target environment. CI does not issue a deployment
command, and operators do not use `kubectl rollout undo` as the system of
record.

## Rollback Flow

```text
Current environment digest
        ↓
Select a digest from that environment's Git history
        ↓
Automated workflow opens a rollback pull request
        ↓
Policy confirms the digest was previously approved
        ↓
Reviewer approves and merges
        ↓
Argo CD reconciles the prior known-good artifact
```

## Safety Contract

The rollback workflow permits only:

- A syntactically valid immutable SHA-256 digest.
- A digest found in the selected environment's history on `main`.
- One environment overlay per pull request.
- A change to only the overlay's `digest` field.

This prevents an arbitrary image from being introduced under the label of a
rollback. Normal forward promotions must still match the preceding
environment's current digest.

## Propose a Rollback

1. Open the repository's **Actions** tab.
2. Select **Propose image rollback**.
3. Select **Run workflow**.
4. Choose `dev`, `staging`, or `prod`.
5. Enter a digest previously approved in that environment.
6. Run the workflow and open the pull request from its summary.
7. Require the environment policy check and normal review before merge.

The demonstration can roll production back from:

```text
sha256:c4717a8d1f0134a7444e24f881160e033991f23027c6c5a9a3f8fd22e70d1d44
```

to its prior approved digest:

```text
sha256:200689790a0a0ea48ca45992e0450bc26ccab5307375b41c84dfc4f2475937ab
```

## Local Preparation

On a dedicated branch, contributors can prepare the same rollback locally:

```bash
git switch -c rollback/<environment>-<release>
./scripts/rollback-image.sh <dev|staging|prod> sha256:<prior-digest>
git diff
```

The pull-request policy remains authoritative even when the change is prepared
locally.

## Verification

After merge, require the selected Argo CD application to become `Synced` and
`Healthy`, then verify the Deployment references the expected prior digest.
Development and staging need not be rolled back when production alone requires
recovery.

## Roll Forward

After the incident or demonstration, use the normal promotion workflow to move
production forward to the digest currently approved in staging. This produces
a second reviewed Git change and preserves the complete recovery audit trail.
