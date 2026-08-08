# Pull-Request Promotion Workflow

Application promotion is a Git change. The workflow proposes one immutable
image digest for one environment, validates its provenance in the preceding
environment, and relies on the existing review and merge controls before Argo
CD sees a new desired state.

## Promotion Order

```text
Published image digest
        ↓
Development pull request
        ↓
Staging pull request using the development digest
        ↓
Production pull request using the staging digest
```

Development accepts a new syntactically valid digest. A normal staging change
must match development, and a normal production change must match staging. A
rollback may instead select a digest previously approved in the target
environment. Each pull request changes exactly one overlay, and only its
`digest` field may change.

## Repository Setup

The proposal workflow uses the repository-scoped `GITHUB_TOKEN` with explicit
`contents: write` and `pull-requests: write` permissions. A repository owner
must enable:

1. Open **Settings → Actions → General**.
2. Find **Workflow permissions**.
3. Enable **Allow GitHub Actions to create and approve pull requests**.
4. Save the setting.

The workflow creates pull requests but does not approve or merge them. Branch
protection and required reviewers remain the approval boundary.

## Propose a Promotion

1. Open the repository's **Actions** tab.
2. Select **Propose image promotion**.
3. Select **Run workflow**.
4. Choose `dev`, `staging`, or `prod`.
5. Enter the full immutable digest in `sha256:<64 lowercase hex>` form.
6. Run the workflow and open the pull request URL from its summary.

The proposal job creates a dedicated branch, changes one overlay, commits as
`github-actions[bot]`, pushes the branch, and opens a pull request. The
`Promotion policy` workflow independently checks the proposed change.

GitHub may require a maintainer to approve the policy workflow on a pull
request created with `GITHUB_TOKEN`. This is an intentional platform security
boundary, not an Argo CD requirement.

## Policy Checks

[`scripts/validate-promotion.sh`](../scripts/validate-promotion.sh) verifies:

- Exactly one environment overlay changed.
- The digest uses the required SHA-256 format.
- The digest actually changed.
- No other content in the selected overlay changed.
- Staging matches the currently approved development digest.
- Production matches the currently approved staging digest.
- A rollback digest previously existed in the selected environment.

The checkout action is pinned to an immutable commit rather than a moving tag.
The PR validation job receives read-only repository permission.

## Local Proposal

Contributors can prepare the same change locally on a dedicated branch:

```bash
git switch -c promotion/<environment>-<release>
./scripts/promote-image.sh <dev|staging|prod> sha256:<digest>
git diff
git add applications/vaipex-demo/overlays/<environment>/kustomization.yaml
git commit -m "promote: <environment> to <short-digest>"
git push -u origin HEAD
gh pr create --base main
```

The helper enforces digest format and predecessor order before changing the
overlay. The pull-request policy remains authoritative.

## After Merge

Argo CD detects the new commit on `main`, reconciles only the selected
environment, and reports its sync and health state. CI does not receive cluster
credentials and does not run `kubectl` or `argocd` deployment commands.

## References

- [GitHub Actions workflow permissions](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository)
- [GitHub `GITHUB_TOKEN` behavior](https://docs.github.com/en/actions/concepts/security/github_token)
- [actions/checkout v6.0.2](https://github.com/actions/checkout/releases/tag/v6.0.2)
