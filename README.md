# platform-aws-core-bootstrap

AWS CDK project for setting up GitHub OpenID Connect (OIDC) integration and IAM roles for secure, credential-free deployments from GitHub Actions.

## Overview

This repository establishes the foundational AWS infrastructure required for GitHub Actions workflows to securely assume AWS IAM roles using OpenID Connect (OIDC) authentication. This eliminates the need for long-lived AWS access keys and secrets stored in GitHub.

### Key Components

- **GitHub OIDC Provider**: An AWS OpenID Connect Provider configured to trust GitHub's token.actions.githubusercontent.com
- **IAM Roles**: Repository-specific roles that each GitHub repository can assume with appropriate conditions
- **Role Outputs**: CloudFormation exports for downstream repositories to reference

## Architecture

```
GitHub Actions Workflow
        ↓
    JWT Token from GitHub
        ↓
    AWS STS AssumeRoleWithWebIdentity
        ↓
    GitHub OIDC Provider (validates token)
        ↓
    Repository-specific IAM Role
        ↓
    AWS Permissions
```

## Project Structure

```
├── bin/
│   └── app.ts                    # CDK app entry point
├── lib/
│   ├── github-oidc-stack.ts      # OIDC provider configuration
│   ├── github-roles-stack.ts     # Repository-specific role definitions
│   └── core-bootstrap-stack.ts   # Stack composition and orchestration
├── package.json                  # Dependencies
├── tsconfig.json                 # TypeScript configuration
└── cdk.json                      # CDK configuration
```

## Prerequisites

- AWS Account (this repo will set up the GitHub OIDC provider and IAM roles)
- AWS CLI configured with credentials to deploy CDK
- Node.js 18+ and npm
- AWS CDK CLI (`npm install -g aws-cdk`)

## Configuration

### Repository Configuration

The list of repositories is managed in [repositories.json](repositories.json). This JSON file contains:

- `githubOwner`: Default GitHub organization name
- `repositories`: Array of repository configurations

#### Editing repositories.json

To add, remove, or modify repositories, edit `repositories.json`:

```json
{
  "githubOwner": "your-org",
  "repositories": [
    {
      "name": "repository-name",
      "environments": ["prod"]
    }
  ]
}
```

#### Environment Variable Override

You can override the GitHub organization without editing the file:

```bash
export GITHUB_ORG=my-org
npx cdk deploy
```

## Setup Instructions

### 1. Update Organization Name

Edit [repositories.json](repositories.json) and set your GitHub organization:

```json
{
  "githubOwner": "your-actual-org"
}
```

Or use environment variable:
```bash
export GITHUB_ORG=your-actual-org
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Build TypeScript

```bash
npm run build
```

### 4. Review the Stack

```bash
npx cdk synth
```

### 5. Deploy to AWS

```bash
npx cdk deploy
```

The CDK will:
1. Create the GitHub OIDC Provider
2. Create IAM roles for each configured repository
3. Output the role ARNs as CloudFormation exports

### 6. Store Role ARNs in GitHub

After deployment, the role ARNs will be displayed as outputs. Store these as GitHub repository secrets:

For each repository, add a secret like:
- **Secret Name**: `AWS_ROLE_TO_ASSUME`
- **Secret Value**: The role ARN output (e.g., `arn:aws:iam::ACCOUNT:role/github-your-org-repository-name`)

### 7. Update GitHub Actions Workflow

In your GitHub Actions workflow, update the credentials configuration:

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
    aws-region: us-east-1
```

## Managed Repositories

This bootstrap configures OIDC roles for the following 23 repositories:

### AWS Platform Services
- `platform-aws-lza-config`
- `platform-aws-aft-account-requests`
- `platform-aws-aft-account-customizations`
- `platform-aws-aft-provisioning`
- `platform-aws-tf-modules`

### AWS Infrastructure
- `infra-aws-shared-network`
- `infra-aws-eks-platform`
- `infra-aws-app-erp`
- `infra-aws-app-crm`

### Azure Platform Services
- `platform-azure-landingzone`
- `platform-azure-policy`
- `platform-azure-management`
- `platform-azure-tf-modules`

### Azure Infrastructure
- `infra-azure-shared-network`
- `infra-azure-aks-platform`
- `infra-azure-app-erp`

### Tools & Automation
- `tools-ci-templates`
- `tools-terraform-linters`
- `tools-security-policies`
- `automation-cloud-reports`

### Applications
- `app-identity-service`
- `app-erp-api`
- `app-erp-frontend`

## Role Permissions

The automatically created roles include:
- Basic OIDC trust policy scoped to the specific repository
- Permission to assume other `github-*` prefixed roles (for role chaining)

### Customizing Role Permissions

To add specific permissions to a role, modify the role in [lib/github-roles-stack.ts](lib/github-roles-stack.ts) after the role is created. Example:

```typescript
role.addInlinePolicy(
  new iam.Policy(this, `CustomPolicy-${repo.name}`, {
    statements: [
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: ['s3:GetObject'],
        resources: ['arn:aws:s3:::my-bucket/*'],
      }),
    ],
  })
);
```

## GitHub OIDC Trust Policy

The roles trust the GitHub OIDC provider with the following conditions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:MyOrg/REPOSITORY_NAME:*"
        }
      }
    }
  ]
}
```

## CDK Commands

```bash
# Build TypeScript
npm run build

# Watch TypeScript for changes
npm run watch

# Synthesize the CDK app (generates CloudFormation)
npm run synth

# Deploy to AWS
npm run deploy

# Destroy the stack
npm run destroy

# Compare with deployed version
npm run cdk -- diff
```



## References

- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/v2/guide/)
- [GitHub OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [GitHub OIDC AWS Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)

## License

See LICENSE file for details.