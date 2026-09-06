output "folder_names" {
  description = "Folders created for this environment, keyed by path."
  value       = module.folders.folder_names
}

output "host_project_id" {
  description = "Shared VPC host project for this environment."
  value       = module.network.host_project_id
}

output "network_self_link" {
  description = "Shared VPC network self link. Feed this to environments/network-hub as a vpc_spokes entry."
  value       = module.network.network_self_link
}

output "team_projects" {
  description = "Generated project ID per team."
  value       = { for k, m in module.team : k => m.project_id }
}

output "team_ci_service_accounts" {
  description = "Per-team CI service account emails, for the auth step in each team's own repo."
  value       = { for k, m in module.team : k => m.ci_service_account_email }
}

output "nat_enabled" {
  description = "Whether Cloud NAT is currently billing in this environment."
  value       = module.network.nat_enabled
}
