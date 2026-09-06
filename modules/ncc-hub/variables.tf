variable "project_id" {
  description = "Project the hub and its spokes live in. Separate from the host projects, so that attaching a spoke is not a change made by whoever owns one environment's network."
  type        = string
}

variable "hub_name" {
  description = "Name of the NCC hub. Prefixes every spoke."
  type        = string
  default     = "lz-hub"
}

variable "vpc_spokes" {
  description = <<-DESC
    VPC networks to attach, keyed by a short name used in the spoke name.

    Empty by default. Every entry here is a billed spoke-hour for as long as it
    exists, so adding one is a deliberate change, not a consequence of adding a
    team. Team growth adds subnets inside an existing spoke's VPC and costs
    nothing extra — that is the reason for keeping Shared VPC underneath.

      "prd" = {
        network               = "projects/acme-host-prd/global/networks/shared-prd"
        include_export_ranges = ["10.0.0.0/12"]
      }
  DESC

  type = map(object({
    network               = string
    include_export_ranges = optional(list(string))
    exclude_export_ranges = optional(list(string))
  }))

  default = {}
}
