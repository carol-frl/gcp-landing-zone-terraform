variable "parent" {
  description = "Node these policies apply to, as organizations/NNN or folders/NNN. Prefer a sandbox folder over the org root until the set is proven."
  type        = string

  validation {
    condition     = can(regex("^(organizations|folders)/[0-9]+$", var.parent))
    error_message = "parent must be organizations/NNN or folders/NNN."
  }
}

variable "inherit_from_parent" {
  description = "Whether these policies merge with the ancestor's rather than replacing them. True means a child can tighten but never loosen."
  type        = bool
  default     = true
}

variable "boolean_constraints" {
  description = <<-DESC
    Boolean constraints, constraint name -> enforce. The default is the
    baseline; override the map to run a different set somewhere else.

      iam.disableServiceAccountKeyCreation
        Blocks downloadable JSON keys. A leaked key is a credential with no
        expiry and no device binding; Workload Identity Federation replaces it.

      compute.requireOsLogin
        Forces SSH through IAM-checked OS Login instead of metadata SSH keys,
        so access is revoked by removing a role rather than editing metadata.

      compute.skipDefaultNetworkCreation
        Stops every new project auto-creating a VPC with permissive default
        firewall rules that nobody reviewed.
  DESC
  type        = map(bool)

  default = {
    "iam.disableServiceAccountKeyCreation" = true
    "compute.requireOsLogin"               = true
    "compute.skipDefaultNetworkCreation"   = true
  }
}

variable "list_constraints" {
  description = <<-DESC
    List constraints, constraint name -> values. Set deny_all, or set
    allowed_values/denied_values, not both.

    No default: every one of these needs a value specific to your org.

      iam.allowedPolicyMemberDomains
        allowed_values = your Cloud Identity customer ID(s). Without it, any
        Google account on earth can be granted a role in your org.

      compute.vmExternalIpAccess
        deny_all = true. VMs reach the internet through Cloud NAT, so an
        external IP is an unreviewed inbound path rather than a requirement.

      gcp.resourceLocations
        allowed_values = location groups such as in:eu-locations. Keeps data
        inside the regions you have actually assessed.
  DESC

  type = map(object({
    deny_all       = optional(bool, false)
    allowed_values = optional(list(string))
    denied_values  = optional(list(string))
  }))

  validation {
    condition = alltrue([
      for name, c in var.list_constraints :
      c.deny_all != (c.allowed_values != null || c.denied_values != null)
    ])
    error_message = "Each list constraint must set either deny_all or value lists, not both and not neither."
  }
}
