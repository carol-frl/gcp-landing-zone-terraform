variable "folder" {
  description = "Folder the host project sits in and the firewall policy attaches to, as folders/NNN."
  type        = string

  validation {
    condition     = can(regex("^folders/[0-9]+$", var.folder))
    error_message = "folder must be folders/NNN."
  }
}

variable "billing_account" {
  description = "Billing account for the host project."
  type        = string
}

variable "host_project_id" {
  description = "Project ID for the Shared VPC host project. Globally unique."
  type        = string
}

variable "network_name" {
  description = "Name of the Shared VPC network. Also prefixes the firewall policy and NAT gateways."
  type        = string
  default     = "shared"
}

variable "regions" {
  description = "Regions a NAT gateway is created in when enable_nat is true. Must cover every region used in subnets."
  type        = list(string)
}

variable "subnets" {
  description = <<-DESC
    Subnets keyed by "team/region". CIDRs are explicit, not calculated —
    an index-based cidrsubnet() renumbers every subnet when a team is added
    to the middle of a list, which is a destroy-and-recreate of live networks.

    Each entry needs a primary range and the two GKE secondary ranges, even if
    no cluster exists yet: secondary ranges cannot be added to a subnet in use
    without disruption, so they are allocated up front.

      "payments/europe-west4" = {
        region   = "europe-west4"
        primary  = "10.0.0.0/20"
        pods     = "10.64.0.0/16"
        services = "10.80.0.0/20"
      }
  DESC

  type = map(object({
    region   = string
    primary  = string
    pods     = string
    services = string
  }))

  validation {
    condition     = alltrue([for k, v in var.subnets : can(regex("^[^/]+/[^/]+$", k))])
    error_message = "Subnet keys must be \"team/region\"."
  }

  validation {
    condition     = alltrue([for k, v in var.subnets : endswith(k, "/${v.region}")])
    error_message = "Each subnet's key must end with its region, so the map cannot drift from the resource."
  }
}

variable "enable_nat" {
  description = "Create Cloud Router and Cloud NAT per region. Costs money whenever it is on — see the cost note in main.tf. False by default."
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs on every subnet. Billed per GB of logs generated. False by default."
  type        = bool
  default     = false
}
