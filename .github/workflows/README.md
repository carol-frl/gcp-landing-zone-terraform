# Workflows

Two workflows, both authenticating with Workload Identity Federation. There is
no service account key in this repository and no way to add one — org policy
blocks key creation (`iam.disableServiceAccountKeyCreation`).

| Workflow | Trigger | What it does |
|---|---|---|
| `terraform-plan.yml` | PR touching `environments/`, `modules/`, `teams/` | `fmt -check`, then plan every environment and post the output as one PR comment per environment, updated in place. |
| `terraform-apply.yml` | Push to `main`, same paths | Applies each environment behind a GitHub environment approval, one at a time. |

Both discover the environment list from the `environments/` directory rather
than hardcoding it, so adding an environment does not mean editing a workflow.

A root is skipped by placing a `.ci-ignore` file in it, and that file explains
why. Two roots carry one today: `bootstrap`, because it creates the identity CI
authenticates as and so cannot be run by it, and `sandbox`, which needs a
hand-created folder and its own tfvars. Both workflows read the same marker —
if they ever disagree, `main` applies something that was never planned.

## Required repository configuration

The workflows read two repository **variables** (not secrets — neither value is
confidential, and storing them as secrets only makes them harder to audit):

```bash
gh variable set WIF_PROVIDER \
  --body "$(terraform -chdir=../../environments/bootstrap output -raw workload_identity_provider)"

gh variable set CI_SERVICE_ACCOUNT \
  --body "$(terraform -chdir=../../environments/bootstrap output -raw ci_service_account_email)"
```

## The approval gate is not in this repo

`environment: ${{ matrix.environment }}` only enforces something once a GitHub
environment of that name exists **and has required reviewers configured**. An
environment that exists with no reviewers is a green tick that gates nothing.

Create them, then add reviewers in Settings → Environments:

```bash
gh api -X PUT repos/:owner/:repo/environments/production
gh api -X PUT repos/:owner/:repo/environments/non-production
```

This is the weakest link in the chain. The Terraform in this repo is reviewable
in a diff; this configuration is not, and it is what stands between a merge and
an org-wide change. Verify it after any repository settings change.

## What this does not cover

**Plan and apply are separate plans.** The apply workflow re-plans after merge
rather than consuming the artifact the reviewer approved. Between approval and
apply the world can change, so what is applied is not provably what was
reviewed. Closing this means passing the plan file between workflows and
accepting that it goes stale against concurrent merges.

**Plan runs with the same identity as apply.** The CI service account holds
org-level `folderAdmin`, `projectCreator`, `orgpolicy.policyAdmin` and
`compute.xpnAdmin`, and `terraform plan` on a pull request uses all of it to
read. A separate viewer identity for plan would reduce what a malicious PR can
reach. Fork PRs are skipped for exactly this reason, but a collaborator's
branch is not.

**No policy checks.** No `tflint`, no `checkov`, no OPA gate on the plan.
Review is a human reading a diff.

**No drift detection.** Nothing notices if someone changes the org in the
console. A scheduled plan that fails on a non-empty diff would.
