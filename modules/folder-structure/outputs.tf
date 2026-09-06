# Keyed by path so callers address a folder the way they think about it:
# folder_ids["production/payments"], not folder_ids[3].
output "folder_ids" {
  description = "Numeric folder IDs keyed by path (\"production\", \"production/payments\")."
  value = merge(
    { for env, f in google_folder.environment : env => f.folder_id },
    { for path, f in google_folder.team : path => f.folder_id },
  )
}

output "folder_names" {
  description = "Folder resource names (folders/NNN) keyed by the same paths. This is the form org policy and project parents want."
  value = merge(
    { for env, f in google_folder.environment : env => f.name },
    { for path, f in google_folder.team : path => f.name },
  )
}
