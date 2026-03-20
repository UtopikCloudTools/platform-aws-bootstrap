output "env_secrets" {
  description = "Map of managed environment secrets by resource key"
  value       = github_actions_environment_secret.env_secrets
  sensitive   = true
}

output "env_variables" {
  description = "Map of managed environment variables by resource key"
  value       = github_actions_environment_variable.env_variables
}

output "repo_secrets" {
  description = "Map of managed repository secrets by resource key"
  value       = github_actions_secret.repo_secrets
  sensitive   = true
}

output "repo_variables" {
  description = "Map of managed repository variables by resource key"
  value       = github_actions_variable.repo_variables
}
