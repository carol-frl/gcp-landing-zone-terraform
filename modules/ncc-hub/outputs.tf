output "hub_id" {
  description = "Hub resource ID. Interconnect and VPN spokes attach to this."
  value       = google_network_connectivity_hub.hub.id
}

output "hub_name" {
  description = "Hub name."
  value       = google_network_connectivity_hub.hub.name
}

output "vpc_spoke_names" {
  description = "Attached VPC spokes, keyed by the same short name. Each one is billing."
  value       = { for k, s in google_network_connectivity_spoke.vpc : k => s.name }
}
