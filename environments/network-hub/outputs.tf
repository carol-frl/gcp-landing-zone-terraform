output "hub_id" {
  description = "Hub resource ID. Interconnect and VPN spokes attach here."
  value       = module.hub.hub_id
}

output "vpc_spoke_names" {
  description = "Attached VPC spokes. Each is billing a spoke-hour."
  value       = module.hub.vpc_spoke_names
}

output "project_id" {
  description = "Hub project."
  value       = google_project.hub.project_id
}
