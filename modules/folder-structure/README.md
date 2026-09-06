# modules/folder-structure

Builds the folder hierarchy: one folder per environment, and one folder per
team inside each environment.

```
organizations/NNN
└── production
    ├── payments
    └── data-platform
└── non-production
    ├── payments
    └── data-platform
```

Environment sits above team. The reasoning is in
[ADR 001](../../docs/decisions/001-folder-hierarchy.md).

## Usage

```hcl
module "folders" {
  source = "../../modules/folder-structure"

  parent       = "folders/123456789012"
  environments = ["production", "non-production"]
  teams        = ["payments", "data-platform"]
}

# folders/456
output "payments_prod" {
  value = module.folders.folder_names["production/payments"]
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `parent` | string | — | `organizations/NNN` or `folders/NNN`. |
| `environments` | list(string) | — | Environment folder names. At least one. |
| `teams` | list(string) | — | Team folder names, repeated under every environment. |

## Outputs

| Name | Description |
|---|---|
| `folder_ids` | Numeric IDs keyed by path (`production/payments`). |
| `folder_names` | `folders/NNN` form, keyed by the same paths. Use this for project parents and org policy targets. |

## Cost

None. Folders are free.

## What this does not cover

No IAM. Bindings at these folders are the project factory's job (Weekend 4),
because the groups that get bound are defined per team.

`deletion_protection` is set to `false` so a demo org can be torn down. That is
the wrong setting for a real org and is not exposed as a variable, so changing
it is an edit someone has to justify in review.
