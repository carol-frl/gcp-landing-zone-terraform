# modules/org-policies

Applies a set of org policy constraints at one node. Boolean and list
constraints are separate variables because they take different shapes, and the
whole set is caller-supplied so a sandbox folder can run looser rules than
production without a second copy of this module.

Uses org policy v2 (`google_org_policy_policy`). The v1
`google_organization_policy` resource is not used.

## Usage

```hcl
module "org_policies" {
  source = "../../modules/org-policies"

  parent = "folders/123456789012"

  # boolean_constraints defaults to the baseline three; override to differ.

  list_constraints = {
    "iam.allowedPolicyMemberDomains" = { allowed_values = ["C01abc234"] }
    "compute.vmExternalIpAccess"     = { deny_all = true }
    "gcp.resourceLocations"          = { allowed_values = ["in:eu-locations"] }
  }
}
```

## The baseline set

| Constraint | Type | What it prevents |
|---|---|---|
| `iam.disableServiceAccountKeyCreation` | boolean | Downloadable JSON keys — credentials with no expiry and no device binding. |
| `compute.requireOsLogin` | boolean | SSH via project metadata keys, which survive a role being revoked. |
| `compute.skipDefaultNetworkCreation` | boolean | Every new project silently getting a VPC with default firewall rules nobody reviewed. |
| `iam.allowedPolicyMemberDomains` | list | Any Google account outside your Cloud Identity being granted a role. |
| `compute.vmExternalIpAccess` | list | Unreviewed inbound paths; egress goes through Cloud NAT instead. |
| `gcp.resourceLocations` | list | Data landing in regions you have not assessed. |

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `parent` | string | — | `organizations/NNN` or `folders/NNN`. |
| `inherit_from_parent` | bool | `true` | Merge with the ancestor's policy. A child can tighten, never loosen. |
| `boolean_constraints` | map(bool) | the three booleans above | Constraint name → enforce. |
| `list_constraints` | map(object) | `{}` | Constraint name → `deny_all` or `allowed_values`/`denied_values`. Validated as mutually exclusive. |

## Outputs

| Name | Description |
|---|---|
| `applied_constraints` | Sorted names of every constraint set at `parent`. |

## Cost

None. Org policy is free. It is not free operationally: each constraint here
will eventually block something a team wants to do, which is the point, but it
means an exception path has to exist before this reaches production.

## What this does not cover

No custom constraints, no tag-based conditional rules, no dry-run policies.
A real rollout would run `gcp.resourceLocations` in dry-run first and read the
violation logs before enforcing.
