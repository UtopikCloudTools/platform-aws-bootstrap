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

echo -e "${YELLOW}Checking GitHub authentication...${NC}"

if command -v gh &> /dev/null; then
  if gh auth status &> /dev/null; then
    echo -e "${GREEN}✓ GitHub already authenticated${NC}"
    GH_USER=$(gh api user -q '.login')
    echo "  User: $GH_USER"
  else
    echo -e "${YELLOW}GitHub CLI found but not authenticated${NC}"
    echo "Authenticating with GitHub..."
    gh auth login --web
    if gh auth status &> /dev/null; then
      echo -e "${GREEN}✓ GitHub authentication successful${NC}"
    else
      echo -e "${RED}✗ GitHub authentication failed${NC}"
      exit 1
    fi
  fi
else
  echo -e "${RED}✗ GitHub CLI (gh) not found${NC}"
  echo "  Install with: brew install gh (macOS) or apt install gh (Linux)"
  exit 1
fi

echo ""

# ============================================================================
# AWS Authentication
# ============================================================================

echo -e "${YELLOW}Checking AWS authentication...${NC}"

if command -v aws &> /dev/null; then
  # Check if we have valid AWS credentials
  if aws sts get-caller-identity &> /dev/null; then
    echo -e "${GREEN}✓ AWS already authenticated${NC}"
    AWS_ACCOUNT=$(aws sts get-caller-identity -q '.Account')
    AWS_USER=$(aws sts get-caller-identity -q '.Arn')
    echo "  Account: $AWS_ACCOUNT"
    echo "  Identity: $AWS_USER"
  else
    echo -e "${YELLOW}AWS CLI found but not authenticated${NC}"
    echo "Starting AWS SSO authentication..."
    echo ""
    echo "When prompted:"
    echo "  1. Choose your AWS SSO start URL"
    echo "  2. Choose your AWS account"
    echo "  3. Choose your IAM role"
    echo ""
    
    # Prompt for SSO start URL if not set
    if [ -z "$AWS_SSO_START_URL" ]; then
      read -p "Enter your AWS SSO start URL (or press Enter to skip): " AWS_SSO_START_URL
    fi
    
    if [ -n "$AWS_SSO_START_URL" ]; then
      aws sso login --sso-session default || true
      if aws sts get-caller-identity &> /dev/null; then
        echo -e "${GREEN}✓ AWS SSO authentication successful${NC}"
      else
        echo -e "${YELLOW}⚠ AWS SSO login may still be pending${NC}"
      fi
    else
      echo -e "${YELLOW}⚠ AWS SSO skipped${NC}"
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
echo "Ready to run Terraform! You can now execute:"
echo "  terraform init"
echo "  terraform plan"
echo "  terraform apply"
