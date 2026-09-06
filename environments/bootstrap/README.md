# environments/bootstrap

Creates the things every other root depends on: the state bucket, the CI
service account, and the Workload Identity pool that lets GitHub Actions
impersonate it without a key.

This root is applied once, by a human, with their own credentials. It is the
only root that starts on local state.

## Order of operations

```bash
cp terraform.tfvars.example terraform.tfvars   # fill in your values
terraform init
terraform plan                                 # read every line
terraform apply                                # review the plan first
```

Then move this root's own state into the bucket it just made:

1. Copy the `state_bucket` output into the `backend "gcs"` block in `versions.tf`.
2. Uncomment that block.
3. `terraform init -migrate-state`

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `org_id` | string | — | Numeric org ID. CI roles are granted here. |
| `billing_account` | string | — | Billing account linked to the bootstrap project. |
| `project_id` | string | — | Bootstrap project ID; also the state bucket prefix. |
| `github_repo` | string | — | `owner/name`. The only repo the WIF provider trusts. |
| `region` | string | `europe-west4` | State bucket location. Permanent. |
| `terraform_admin_group` | string | — | `group:` principal with human access to state. |

## Outputs

| Name | Description |
|---|---|
| `project_id` | Bootstrap project ID. |
| `state_bucket` | Backend bucket for every other root. |
| `ci_service_account_email` | Impersonated by GitHub Actions. |
| `workload_identity_provider` | Full provider resource name for the auth action. |

## Cost

The state bucket is the only billed resource: standard storage, a few MB,
under $0.05/month. Everything else — service accounts, IAM bindings, the
identity pool — is free. Enabling APIs costs nothing on its own.

## What this does not cover

No folders, no org policy, no network. Those land in Weekends 2 and 3. The CI
service account is granted org-level roles here so those later roots can run,
which means this root defines the blast radius of the entire pipeline.
