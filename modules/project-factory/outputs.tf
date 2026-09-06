output "project_id" {
  description = "Generated project ID for this team and environment."
  value       = google_project.team.project_id
}

output "project_number" {
  description = "Project number, needed by anything that binds service agents."
  value       = google_project.team.number
}

output "ci_service_account_email" {
  description = "Team CI service account. Pass to google-github-actions/auth in the team's own repo."
  value       = google_service_account.ci.email
}
