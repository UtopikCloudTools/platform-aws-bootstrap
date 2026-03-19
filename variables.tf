# Variables for GitHub Bootstrap

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ca-central-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "oidc_provider_url" {
  description = "GitHub OIDC Provider URL"
  type        = string
  default     = "https://token.actions.githubusercontent.com"
}

variable "oidc_client_ids" {
  description = "Client IDs for GitHub OIDC Provider"
  type        = list(string)
  default     = ["sts.amazonaws.com"]
}

variable "repositories" {
  description = "GitHub repositories to configure for OIDC. Prefer `environments` for trust-policy scoping; `branches` is a legacy fallback."
  type = list(object({
    owner        = string
    name         = string
    permissions  = optional(string, "deploy")
    environments = optional(list(string), [])
    branches     = optional(list(string), [])
  }))

  validation {
    condition = alltrue([
      for repo in var.repositories :
      contains(["bootstrap", "full", "deploy", "read-only"], repo.permissions)
    ])
    error_message = "All permissions must be one of: bootstrap, full, deploy, read-only"
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Terraform = "true"
  }
}
