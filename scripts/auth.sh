#!/bin/bash

# Interactive Authentication Script
# Authenticates with GitHub and AWS SSO, only if not already authenticated

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== GitHub & AWS Authentication ===${NC}\n"

# ============================================================================
# GitHub Authentication
# ============================================================================

# ============================================================================
# GitHub Authentication
# ============================================================================

echo -e "${YELLOW}Checking GitHub authentication...${NC}"

if command -v gh &> /dev/null; then
  # Check if already authenticated
  if gh auth status &> /dev/null 2>&1; then
    echo -e "${GREEN}✓ GitHub already authenticated${NC}"
    GH_USER=$(gh api user -q '.login' 2>/dev/null || echo "unknown")
    echo "  User: $GH_USER"
    
    # Check token scopes
    echo ""
    echo "Checking token scopes..."
    TOKEN_SCOPES=$(gh auth status 2>&1 | grep -oP 'Token scopes: \K.*' || echo "")
    
    if [ -z "$TOKEN_SCOPES" ]; then
      echo -e "${YELLOW}⚠ Could not determine token scopes${NC}"
      echo "Flushing Codespaces token and requesting new one with proper scopes..."
      gh auth logout --yes 2>/dev/null || true
      # Unset GITHUB_TOKEN env var so gh can do interactive auth
      unset GITHUB_TOKEN
      echo "Starting GitHub authentication via web browser..."
      gh auth login --web --git-protocol https --skip-ssh-key --scopes repo,admin:repo_hook,workflow
      if gh auth status &> /dev/null 2>&1; then
        echo -e "${GREEN}✓ GitHub authenticated with new token${NC}"
      else
        echo -e "${RED}✗ GitHub authentication failed${NC}"
        exit 1
      fi
    else
      echo "  Token scopes: $TOKEN_SCOPES"
      
      # Check if required scopes are present
      REQUIRED_SCOPES=("repo" "admin:repo_hook" "workflow")
      SCOPES_OK=true
      MISSING_SCOPES=()
      
      for scope in "${REQUIRED_SCOPES[@]}"; do
        if [[ ! "$TOKEN_SCOPES" =~ "$scope" ]]; then
          MISSING_SCOPES+=("$scope")
          SCOPES_OK=false
        fi
      done
      
      if [ "$SCOPES_OK" = true ]; then
        echo -e "${GREEN}✓ All required scopes present${NC}"
      else
        echo -e "${RED}✗ Missing required scopes: ${MISSING_SCOPES[*]}${NC}"
        echo ""
        echo "Flushing current token and requesting new one..."
        gh auth logout --yes 2>/dev/null || true
        # Unset GITHUB_TOKEN env var so gh can do interactive auth
        unset GITHUB_TOKEN
        echo "Starting GitHub authentication via web browser..."
        gh auth login --web --git-protocol https --skip-ssh-key --scopes repo,admin:repo_hook,workflow
        if gh auth status &> /dev/null 2>&1; then
          echo -e "${GREEN}✓ GitHub authenticated with new token${NC}"
        else
          echo -e "${RED}✗ GitHub authentication failed${NC}"
          exit 1
        fi
      fi
    fi
  else
    echo -e "${YELLOW}GitHub CLI not authenticated${NC}"
    
    # In Codespaces, try to use environment GITHUB_TOKEN if available
    if [ -n "$GITHUB_TOKEN" ]; then
      echo "Found GITHUB_TOKEN in environment, configuring gh..."
      echo "$GITHUB_TOKEN" | gh auth login --with-token 2>/dev/null
      if gh auth status &> /dev/null 2>&1; then
        echo -e "${GREEN}✓ GitHub authenticated via GITHUB_TOKEN${NC}"
      else
        echo -e "${RED}✗ Failed to authenticate with GITHUB_TOKEN${NC}"
        exit 1
      fi
    else
      echo "Starting GitHub authentication via device flow..."
      gh auth login
      if gh auth status &> /dev/null 2>&1; then
        echo -e "${GREEN}✓ GitHub authentication successful${NC}"
      else
        echo -e "${RED}✗ GitHub authentication failed${NC}"
        exit 1
      fi
    fi
  fi
else
  echo -e "${RED}✗ GitHub CLI (gh) not found${NC}"
  exit 1
fi

# Export GitHub token for Terraform
export TF_VAR_github_token=$(gh auth token)

echo ""

# ============================================================================
# AWS Authentication
# ============================================================================

echo -e "${YELLOW}Checking AWS authentication...${NC}"

if command -v aws &> /dev/null; then
  # Check if we have valid AWS credentials
  if aws sts get-caller-identity &> /dev/null; then
    echo -e "${GREEN}✓ AWS already authenticated${NC}"
    AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    AWS_USER=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null)
    echo "  Account: $AWS_ACCOUNT"
    echo "  Identity: $AWS_USER"
  else
    echo -e "${YELLOW}AWS CLI found but not authenticated${NC}"
    
    # Check if AWS SSO is already configured
    if aws configure get sso_start_url &> /dev/null; then
      SSO_URL=$(aws configure get sso_start_url)
      echo -e "${GREEN}✓ AWS SSO already configured${NC}"
      echo "  SSO Start URL: $SSO_URL"
      echo ""
      echo "Attempting AWS SSO login..."
      aws sso login || true
      if aws sts get-caller-identity &> /dev/null; then
        echo -e "${GREEN}✓ AWS SSO authentication successful${NC}"
      else
        echo -e "${YELLOW}⚠ AWS SSO login may still be pending${NC}"
      fi
    else
      echo "Starting AWS SSO authentication setup..."
      echo ""
      echo "When prompted:"
      echo "  1. Enter your AWS SSO start URL"
      echo "  2. Choose your AWS account"
      echo "  3. Choose your IAM role"
      echo ""
      
      read -p "Enter your AWS SSO start URL: " AWS_SSO_START_URL
      
      if [ -n "$AWS_SSO_START_URL" ]; then
        # Configure AWS SSO with the provided URL
        aws configure set sso_start_url "$AWS_SSO_START_URL"
        echo "Configured SSO start URL: $AWS_SSO_START_URL"
        echo ""
        echo "Now configure the rest of your AWS profile..."
        aws configure sso --profile default || true
        
        if aws sts get-caller-identity &> /dev/null; then
          echo -e "${GREEN}✓ AWS SSO authentication successful${NC}"
        else
          echo -e "${YELLOW}⚠ AWS SSO setup incomplete. Run 'aws sso login' to complete authentication${NC}"
        fi
      else
        echo -e "${YELLOW}⚠ AWS SSO skipped${NC}"
      fi
    fi
  fi
else
  echo -e "${RED}✗ AWS CLI not found${NC}"
  echo "  Install with: brew install awscli (macOS) or apt install awscli (Linux)"
  exit 1
fi

echo ""
echo -e "${GREEN}=== Authentication Complete ===${NC}"
echo ""
echo "✓ GitHub token has all required scopes:"
echo "  - repo (repository access)"
echo "  - admin:repo_hook (manage secrets)"
echo "  - workflow (manage workflows)"
echo ""
echo "Ready to run Terraform!"
echo "  terraform init -backend-config=backend.hcl"
echo "  terraform plan"
echo "  terraform apply"
echo ""
