# Sandbox root: proves the folder hierarchy and the org policy set against a
# throwaway folder before either goes anywhere near the org root.

module "folders" {
  source = "../../modules/folder-structure"

  parent       = var.parent
  environments = var.environments
  teams        = var.teams
}

module "org_policies" {
  source = "../../modules/org-policies"

  # Applied at the sandbox parent so every folder below inherits. Moving this
  # to organizations/NNN is the promotion step, and it is deliberately a
  # one-line change you have to make on purpose.
  parent = var.parent

  # Booleans take the module's baseline. The list constraints cannot: each
  # needs a value that is specific to this org.
  list_constraints = {
    "iam.allowedPolicyMemberDomains" = {
      allowed_values = var.allowed_customer_ids
    }
    "compute.vmExternalIpAccess" = {
      deny_all = true
    }
    "gcp.resourceLocations" = {
      allowed_values = var.allowed_locations
    }
  }
}
