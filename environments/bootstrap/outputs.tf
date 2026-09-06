output "project_id" {
  description = "Bootstrap project ID."
  value       = google_project.bootstrap.project_id
}

output "state_bucket" {
  description = "State bucket name. Put this in the backend block of every other root."
  value       = google_storage_bucket.state.name
}

output "ci_service_account_email" {
  description = "Service account GitHub Actions impersonates. Pass as service_account to google-github-actions/auth."
  value       = google_service_account.ci.email
}

output "workload_identity_provider" {
  description = "Full provider resource name. Pass as workload_identity_provider to google-github-actions/auth."
  value       = google_iam_workload_identity_pool_provider.github.name
}
