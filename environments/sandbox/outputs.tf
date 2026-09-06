output "folder_ids" {
  description = "Numeric folder IDs keyed by path."
  value       = module.folders.folder_ids
}

output "folder_names" {
  description = "Folder resource names keyed by path, for use as project parents."
  value       = module.folders.folder_names
}

output "applied_constraints" {
  description = "Constraints enforced at the sandbox parent."
  value       = module.org_policies.applied_constraints
}
