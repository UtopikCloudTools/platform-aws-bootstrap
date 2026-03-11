#!/bin/bash

# AWS CDK Bootstrap Script
# This script bootstraps the AWS environment for CDK deployments
# Run this ONCE before your first 'cdk deploy'

# Don't exit on error immediately - we want to handle errors gracefully
set +e

echo "========================================"
echo "AWS CDK Bootstrap Script"
echo "========================================"
echo ""

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first."
    echo "   See: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials are not configured."
    echo "   Please configure your AWS credentials using 'aws configure'"
    exit 1
fi

# Get AWS account ID and region
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
# Default to ca-central-1, can be overridden with AWS_REGION or AWS_DEFAULT_REGION env var
REGION=${AWS_REGION:-${AWS_DEFAULT_REGION:-ca-central-1}}

echo "✓ AWS Credentials Found"
echo "  Account ID: $ACCOUNT_ID"
echo "  Region: $REGION"
echo ""
echo "Note: Deploying to $REGION"
echo ""

# Check if Node.js and CDK are available
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed."
    exit 1
fi

echo "✓ Node.js is installed"
echo ""

# Install CDK CLI if not already installed globally
if ! command -v cdk &> /dev/null; then
    echo "📦 Installing AWS CDK CLI globally..."
    npm install -g aws-cdk
    echo "✓ AWS CDK CLI installed"
else
    echo "✓ AWS CDK CLI is already installed"
fi

echo ""
echo "========================================"
echo "Bootstrapping AWS Environment"
echo "========================================"
echo "Running: cdk bootstrap aws://$ACCOUNT_ID/$REGION"
echo ""

# Run cdk bootstrap with error handling
cdk bootstrap aws://$ACCOUNT_ID/$REGION
BOOTSTRAP_EXIT_CODE=$?

if [ $BOOTSTRAP_EXIT_CODE -ne 0 ]; then
    echo ""
    echo "⚠️  Bootstrap returned an error code"
    echo "   This might be because bootstrap has already been completed."
    echo "   Proceeding with deployment..."
else
    echo ""
    echo "✓ Bootstrap complete!"
    echo ""
fi

# Verify bootstrap was successful - the CDK toolkit should exist
echo "Verifying bootstrap..."
sleep 5  # Wait a moment for AWS to propagate

# Check if the CDKToolkit stack exists
if aws cloudformation describe-stacks --stack-name CDKToolkit --region "$REGION" &> /dev/null; then
    echo "✓ CDKToolkit stack verified in $REGION"
else
    echo "⚠️  CDKToolkit stack not found. Waiting and retrying..."
    sleep 10
    if ! aws cloudformation describe-stacks --stack-name CDKToolkit --region "$REGION" &> /dev/null; then
        echo "❌ CDKToolkit stack verification failed."
        echo "   The bootstrap stack may not have deployed correctly."
        echo "   Try running: cdk bootstrap aws://$ACCOUNT_ID/$REGION"
        exit 1
    fi
    echo "✓ CDKToolkit stack verified in $REGION"
fi

echo ""
echo "========================================"
echo "Configuring S3 Bucket Permissions"
echo "========================================"

# Check if jq is available (required for JSON merging)
if ! command -v jq &> /dev/null; then
    echo "❌ jq is not installed. Installing jq..."
    apt-get update && apt-get install -y jq > /dev/null 2>&1 || {
        echo "❌ Failed to install jq. Please install it manually."
        exit 1
    }
    echo "✓ jq installed"
fi

ASSETS_BUCKET="cdk-hnb659fds-assets-$ACCOUNT_ID-$REGION"

# Create a temporary policy file
POLICY_FILE=$(mktemp)

# Get the existing bucket policy or create a new one
EXISTING_POLICY=$(aws s3api get-bucket-policy --bucket "$ASSETS_BUCKET" --region "$REGION" 2>/dev/null)

if [ $? -eq 0 ]; then
    # Policy exists, parse it (note: get-bucket-policy returns policy as JSON string in .Policy field)
    echo "$EXISTING_POLICY" | jq -r '.Policy' 2>/dev/null > "$POLICY_FILE" || echo "$EXISTING_POLICY" > "$POLICY_FILE"
else
    # No policy exists, create a new one
    cat > "$POLICY_FILE" << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": []
}
EOF
fi

# Add S3 access statement for GitHub roles using jq to properly merge JSON
# Note: S3 bucket policies don't support wildcards in Principal ARNs
# Use account root principal instead - access is controlled by IAM role permissions
READ_STATEMENT=$(cat << EOF
{
  "Sid": "AllowCDKAssetAccess",
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::$ACCOUNT_ID:root"
  },
  "Action": [
    "s3:GetObject",
    "s3:PutObject",
    "s3:DeleteObject",
    "s3:ListBucket",
    "s3:GetObjectVersion",
    "s3:GetBucketVersioning",
    "s3:PutBucketVersioning",
    "s3:GetBucketPolicy",
    "s3:GetBucketAcl",
    "s3:GetBucketLocation"
  ],
  "Resource": [
    "arn:aws:s3:::$ASSETS_BUCKET",
    "arn:aws:s3:::$ASSETS_BUCKET/*"
  ]
}
EOF
)

# Merge the statement into the policy using jq
# Remove any existing statement with the same Sid first, then add the new one
jq --argjson newStmt "$READ_STATEMENT" \
   '.Statement |= map(select(.Sid != "AllowCDKAssetAccess")) + [$newStmt]' \
   "$POLICY_FILE" > "$POLICY_FILE.new" 2>/dev/null

if [ $? -ne 0 ]; then
    echo "❌ Failed to merge bucket policy"
    echo "Policy file contents:"
    cat "$POLICY_FILE"
    rm -f "$POLICY_FILE" "$POLICY_FILE.new"
    exit 1
fi

# Debug: show the policy being applied
echo "Applying bucket policy..."
echo "Bucket: $ASSETS_BUCKET"
echo "Account ID: $ACCOUNT_ID"
echo "Region: $REGION"
echo ""

# Apply the new policy
aws s3api put-bucket-policy --bucket "$ASSETS_BUCKET" --policy file://"$POLICY_FILE.new" --region "$REGION" 2>&1
POLICY_RESULT=$?

if [ $POLICY_RESULT -eq 0 ]; then
    echo "✓ S3 bucket policy updated successfully"
    echo ""
    # Verify the policy was applied
    echo "Verifying bucket policy..."
    aws s3api get-bucket-policy --bucket "$ASSETS_BUCKET" --region "$REGION" 2>/dev/null | jq -r '.Policy' | jq . 2>/dev/null | head -30
    echo ""
else
    echo "⚠️  Failed to update bucket policy"
    echo "Error output above. Continuing anyway..."
    echo ""
    echo "Note: Current AWS credentials may not have s3:PutBucketPolicy permission."
    echo "Current caller:"
    aws sts get-caller-identity
    echo ""
fi

# Cleanup temp files
rm -f "$POLICY_FILE" "$POLICY_FILE.new"

# Verify bucket is accessible
echo "Verifying S3 bucket access..."
if aws s3 ls "s3://$ASSETS_BUCKET" --region "$REGION" &> /dev/null; then
    echo "✓ S3 bucket is accessible"
else
    echo "⚠️  Cannot access S3 bucket with current credentials"
    echo "  This may cause issues with 'cdk deploy'"
    echo "  Ensure your IAM user/role has S3 permissions in its IAM policy"
fi

echo "========================================"
echo "✓ Bootstrap Complete!"
echo "========================================"
echo ""
echo "CDKToolkit has been deployed."
echo ""
echo "Next steps:"
echo "  1. Commit and push this code to your repository"
echo "  2. GitHub Actions will automatically:"
echo "     • Install dependencies"
echo "     • Build the project"
echo "     • Deploy the CDK stack"
echo ""
