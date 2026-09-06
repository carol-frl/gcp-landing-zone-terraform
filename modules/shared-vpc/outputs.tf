output "host_project_id" {
  description = "Shared VPC host project. Service projects attach to this."
  value       = google_compute_shared_vpc_host_project.host.project
}

output "network_id" {
  description = "Self link of the Shared VPC network."
  value       = google_compute_network.vpc.id
}

output "network_self_link" {
  description = "Network self link. This is what an NCC VPC spoke's linked_vpc_network.uri wants."
  value       = google_compute_network.vpc.self_link
}

output "subnet_ids" {
  description = "Subnet self links keyed by \"team/region\". The project factory binds subnet IAM against these."
  value       = { for k, s in google_compute_subnetwork.team : k => s.id }
}

output "subnet_self_links" {
  description = "Same subnets keyed by \"team/region\", as region/name pairs for callers that need them separately."
  value = {
    for k, s in google_compute_subnetwork.team : k => {
      name   = s.name
      region = s.region
    }
  }
}

output "firewall_policy_id" {
  description = "Hierarchical firewall policy attached at the folder."
  value       = google_compute_firewall_policy.baseline.id
}

output "nat_enabled" {
  description = "Whether Cloud NAT is currently provisioned. False means no egress to the internet from private VMs."
  value       = var.enable_nat
}
