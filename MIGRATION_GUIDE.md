# CDK to Terraform Migration Guide

This document outlines the changes made converting the AWS CDK project to Terraform.

## Changes Made

### Removed Files (CDK)
- ❌ `bin/app.ts` - CDK app entry point
- ❌ `lib/core-bootstrap-stack.ts` - CDK stack composition
- ❌ `lib/github-oidc-stack.ts` - CDK OIDC provider
- ❌ `lib/github-roles-stack.ts` - CDK role definitions
- ❌ `package.json` - Node.js dependencies
- ❌ `tsconfig.json` - TypeScript configuration
- ❌ `cdk.json` - CDK configuration
- ❌ `node_modules/` - Node.js packages
- ❌ `package-lock.json` - Dependency lock file

### Added Files (Terraform)
- ✅ `main.tf` - Root module configuration
- ✅ `variables.tf` - Input variables
- ✅ `outputs.tf` - Module outputs
- ✅ `terraform.tf` - Provider requirements
- ✅ `terraform.tfvars.example` - Example variables
- ✅ `modules/github-oidc/main.tf` - OIDC provider module
- ✅ `modules/github-oidc/variables.tf` - OIDC module variables
- ✅ `modules/github-oidc/outputs.tf` - OIDC module outputs
- ✅ `modules/github-roles/main.tf` - Roles module
- ✅ `modules/github-roles/variables.tf` - Roles module variables
- ✅ `modules/github-roles/outputs.tf` - Roles module outputs

### Updated Files
- 📝 `README.md` - Complete rewrite for Terraform
- 📝 `bootstrap.sh` - Updated for Terraform initialization
- 📝 `set-github-secrets.sh` - Updated for Terraform setup
- 📝 `docs/EXAMPLE_WORKFLOW.md` - Updated with Terraform examples
- 📝 `docs/example-deploy.yml` - Changed from Node.js/CDK to Terraform
- 📝 `.gitignore` - Updated for Terraform artifacts
- 📝 `repositories.json` - Structure slightly updated with owner field

## Key Differences

### Configuration
| Aspect | CDK | Terraform |
|--------|-----|-----------|
| Entry Point | `bin/app.ts` | `main.tf` |
| Variables | TypeScript interfaces | `variables.tf` |
| Outputs | TypeScript class exports | `outputs.tf` |
| State Management | `cdk.out/` | `terraform.tfstate` |
| Configuration | `cdk.json` + `repositories.json` | `terraform.tfvars` + `repositories.json` |

### Modules
| Component | CDK | Terraform |
|-----------|-----|-----------|
| OIDC Provider | `GitHubOIDCStack` class | `modules/github-oidc/` |
| Roles | `GitHubRolesStack` class | `modules/github-roles/` |
| Composition | `CoreBootstrapStack` | `modules` + root config |

### Permissions
The permission level system is preserved exactly:
- `bootstrap` - Infrastructure management
- `full` - All permissions
- `deploy` - Application deployment
- `read-only` - Monitoring only

### Functionality
All IAM policies, trust policies, and configurations are identical to the CDK version.

## Migration Path for Users

### Step 1: Update Local Environment
```bash
# Remove old CDK files
rm -rf bin lib package.json tsconfig.json cdk.json node_modules package-lock.json

# Initialize Terraform
terraform init
```

### Step 2: Set Up Configuration
```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your AWS account ID and repositories
vim terraform.tfvars
```

### Step 3: Plan & Apply
```bash
# Review changes
terraform plan

# Apply configuration
terraform apply
```

### Step 4: Update GitHub Workflows

Change from:
```yaml
run: npx cdk deploy --require-approval=never
```

To:
```yaml
run: terraform apply -auto-approve
```

## Feature Parity

All features from the CDK version are maintained:

✅ GitHub OIDC Provider creation and management
✅ Per-repository IAM role creation
✅ Permission level support (bootstrap, full, deploy, read-only)
✅ SSM Parameter Store exports
✅ CloudFormation output compatibility
✅ Trust policy management
✅ Role policy attachment
✅ Support for multiple repositories

## Benefits of Terraform

1. **Universal IaC**: Works across all cloud providers
2. **Simpler Syntax**: HCL is more declarative than CDK code
3. **Smaller Dependencies**: No Node.js/npm required
4. **Modular**: Clear separation of concerns with modules
5. **Wide Adoption**: Larger community and more resources
6. **State Management**: Clear state tracking and remote state options

## State Migration (If Needed)

If you have an existing CDK-deployed stack:

```bash
# Export existing stack information
aws cloudformation describe-stacks --stack-name CoreBootstrapStack

# Import existing resources into Terraform state
terraform import module.github_oidc.aws_iam_openid_connect_provider.github \
  arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com

# Import roles
terraform import 'module.github_roles.aws_iam_role.github["repo-name"]' \
  github-OWNER-repo-name
```

## Reverting to CDK

If you need to keep both CDK and Terraform:
1. Use the git history to recover CDK files
2. Run both `cdk` and `terraform` in separate branches
3. Coordinate deployments to avoid conflicts

## Troubleshooting

### Terraform Plan Shows Errors
Ensure `terraform.tfvars` is configured with valid values

### Role Names Don't Match
Verify repository names and owners match exactly (case-sensitive) in `terraform.tfvars`

### Need to Import Existing Resources
Use `terraform import` to bring existing AWS resources into state

## Support

Refer to main [README.md](../README.md) for Terraform usage and examples.
