# modules/project-factory

Turns one entry in [`teams/teams.yaml`](../../teams/teams.yaml) into everything
a team needs in one environment: a project, group IAM at the team folder,
Shared VPC service project attachment, subnet IAM, a budget with alert
thresholds, and a CI service account federated to that team's repository.

The module handles **one team in one environment**. The environment roots loop.
It has no idea other teams exist, which is what keeps a malformed team entry
from affecting anyone else's plan.

## Adding a team

Add a block to `teams/teams.yaml`. That is the whole change.

```yaml
  search:
    display_name: Search
    cost_centre: CC-9001
    github_repo: carol-frl/search-infra
    groups:
      admins: gcp-search-admins@example.com
      developers: gcp-search-devs@example.com
    region: europe-west4
    networks:
      production:     { primary: 10.0.32.0/20, pods: 10.66.0.0/16, services: 10.80.32.0/20 }
      non-production: { primary: 10.1.32.0/20, pods: 10.98.0.0/16, services: 10.112.32.0/20 }
    budget_usd:
      production: 300
      non-production: 50
```

Then `terraform plan` in `environments/production` and
`environments/non-production`. Each produces one team folder, one project, one
subnet, the IAM to use it, a budget and a CI identity.

## What one entry produces

| Resource | Scope | Note |
|---|---|---|
| Team folder | per environment | Created by `modules/folder-structure` from the same team list. |
| Project | per environment | `<prefix>-<team>-<env code>`; `PREVENT` deletion in production, `DELETE` elsewhere. |
| Group role bindings | team folder | Predefined roles only, never basic roles. |
| Shared VPC attachment | host project | Service project attaches to the environment's host. |
| Subnet IAM | one subnet | `networkUser` for both groups and the required service agents. |
| Budget | billing account | 50 / 90 / 100% actual, plus a forecast alert. |
| CI service account | team project | WIF-bound to that team's repo only. |

## Decisions worth knowing

**Group IAM binds at the folder, not the project.** A second project for the
same team in the same environment inherits access without another binding. The
cost is that folder-level grants are easy to over-read: `roles/compute.admin`
at a folder is broader than it looks once the folder has several projects in it.

**No basic roles.** `roles/editor` covers every service in GCP, including ones
released after this module was written, which makes it a grant nobody can
describe the scope of at review time. The predefined lists are longer, and they
are the reason `folder_roles` is a variable — production withholds
`roles/resourcemanager.projectIamAdmin` so that granting yourself more access
in production has to go through this repository.

**Subnet IAM, not host-project IAM.** `networkUser` is bound on the team's own
subnet, so a team can use its range and cannot see or attach to another's.
Host-project-wide `networkUser` would be one binding instead of four and would
give every team the whole network.

**The GKE bindings are conditional.** The container service agent does not
exist until the container API is enabled, and binding a principal that does not
exist fails the apply. They are created only when `container.googleapis.com` is
in `project_apis`, which it is not by default.

**Deletion policy differs by environment.** Production projects are `PREVENT`;
everywhere else is `DELETE` so the demo can be torn down. This is why
`terraform destroy` against production will fail, which is the intent.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `team` | string | — | Team key from `teams.yaml`. |
| `config` | object | — | That team's decoded entry: `display_name`, `cost_centre`, `github_repo`, `groups`, `budget_usd`. |
| `environment` | string | — | Must match a key in the team's `budget_usd`. |
| `environment_code` | string | — | Short form used in project IDs (`prd`, `nonprd`). |
| `project_prefix` | string | — | Org-wide project ID prefix. |
| `folder` | string | — | `folders/NNN` for this team in this environment. |
| `billing_account` | string | — | Billing account for project and budget. |
| `host_project_id` | string | — | Shared VPC host for this environment. |
| `subnet_name` | string | — | Delegated subnet name. |
| `subnet_region` | string | — | Its region. |
| `workload_identity_pool_name` | string | — | Pool from `environments/bootstrap`. |
| `project_apis` | list(string) | compute, logging, monitoring | Adding `container.googleapis.com` enables the GKE host bindings. |
| `folder_roles` | map(list(string)) | see variables.tf | Group → roles at the team folder. |
| `ci_project_roles` | list(string) | compute.admin, serviceAccountUser, storage.admin | Team CI roles, project-scoped only. |

## Outputs

| Name | Description |
|---|---|
| `project_id` | Generated project ID. |
| `project_number` | For anything binding service agents. |
| `ci_service_account_email` | For the auth step in the team's own repo. |

## Cost

The factory itself provisions nothing billable: projects, IAM bindings, service
accounts, budgets and Shared VPC attachment are all free. What a team then
builds inside the project is not, which is what the budget is for.

The budget is also the weakest part of this module. With no notification
channel configured it emails billing account administrators, who are generally
not the people who can act on a team's overspend. Routing alerts to the team's
own channel via Pub/Sub is real work that has not been done here.

## What this does not cover

No per-team DNS zones, no Artifact Registry, no log sinks, no VPC Service
Controls perimeter. Overlapping CIDRs between teams are not detected — the
ranges in `teams.yaml` are reviewed by a human reading the diff, and nothing
in the code will catch an overlap before `apply` does.
