#!/bin/bash
# Script to create S3 bucket and DynamoDB table for Terraform state backend
# Run this BEFORE uncommenting the backend configuration in terraform.tf

set -e

# Configuration
REGION="eu-west-1"
BUCKET_NAME="cicd-k8s-terraform-state-$(date +%s)"  # Unique bucket name with timestamp
DYNAMODB_TABLE="terraform-state-lock"
PROJECT_TAG="cicd-k8s"

echo "=============================================="
echo "Terraform Backend Setup Script"
echo "=============================================="
echo ""
echo "Region: $REGION"
echo "S3 Bucket: $BUCKET_NAME"
echo "DynamoDB Table: $DYNAMODB_TABLE"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check AWS credentials
echo "Checking AWS credentials..."
aws sts get-caller-identity > /dev/null 2>&1 || {
    echo "ERROR: AWS credentials not configured. Run 'aws configure' first."
    exit 1
}
echo "✓ AWS credentials validated"
echo ""

# Create S3 bucket for Terraform state
echo "Creating S3 bucket: $BUCKET_NAME"
aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"

echo "✓ S3 bucket created"

# Enable versioning on S3 bucket
echo "Enabling versioning on S3 bucket..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --versioning-configuration Status=Enabled

echo "✓ Versioning enabled"

# Enable encryption on S3 bucket
echo "Enabling default encryption on S3 bucket..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            },
            "BucketKeyEnabled": true
        }]
    }'

echo "✓ Encryption enabled"

# Block public access
echo "Blocking public access to S3 bucket..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "✓ Public access blocked"

# Add tags to S3 bucket
echo "Adding tags to S3 bucket..."
aws s3api put-bucket-tagging \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --tagging "TagSet=[
        {Key=Project,Value=$PROJECT_TAG},
        {Key=Purpose,Value=TerraformState},
        {Key=ManagedBy,Value=Script}
    ]"

echo "✓ Tags added"
echo ""

# Create DynamoDB table for state locking
echo "Creating DynamoDB table: $DYNAMODB_TABLE"
aws dynamodb create-table \
    --table-name "$DYNAMODB_TABLE" \
    --region "$REGION" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --tags \
        Key=Project,Value="$PROJECT_TAG" \
        Key=Purpose,Value=TerraformStateLock \
        Key=ManagedBy,Value=Script

echo "✓ DynamoDB table created"

# Wait for table to be active
echo "Waiting for DynamoDB table to be active..."
aws dynamodb wait table-exists \
    --table-name "$DYNAMODB_TABLE" \
    --region "$REGION"

echo "✓ DynamoDB table is active"
echo ""

# Verify resources
echo "=============================================="
echo "Verifying created resources..."
echo "=============================================="
echo ""

# Verify S3 bucket
echo "S3 Bucket Details:"
aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null && echo "✓ Bucket exists and is accessible"
aws s3api get-bucket-versioning --bucket "$BUCKET_NAME" --region "$REGION" | grep -q "Enabled" && echo "✓ Versioning is enabled"
echo ""

# Verify DynamoDB table
echo "DynamoDB Table Details:"
aws dynamodb describe-table \
    --table-name "$DYNAMODB_TABLE" \
    --region "$REGION" \
    --query 'Table.{Name:TableName,Status:TableStatus,BillingMode:BillingModeSummary.BillingMode}' \
    --output table

echo ""
echo "=============================================="
echo "Setup Complete!"
echo "=============================================="
echo ""
echo "Next steps:"
echo "1. Update terraform.tf with the following backend configuration:"
echo ""
echo "terraform {"
echo "  backend \"s3\" {"
echo "    bucket         = \"$BUCKET_NAME\""
echo "    key            = \"cicd-k8s/terraform.tfstate\""
echo "    region         = \"$REGION\""
echo "    encrypt        = true"
echo "    dynamodb_table = \"$DYNAMODB_TABLE\""
echo "  }"
echo "}"
echo ""
echo "2. Run: terraform init -migrate-state"
echo ""
echo "=============================================="

# Save configuration to file
cat > terraform-backend-config.txt <<EOF
# Terraform Backend Configuration
# Generated on: $(date)

Bucket Name: $BUCKET_NAME
DynamoDB Table: $DYNAMODB_TABLE
Region: $REGION

Add this to your terraform.tf:

terraform {
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "cicd-k8s/terraform.tfstate"
    region         = "$REGION"
    encrypt        = true
    dynamodb_table = "$DYNAMODB_TABLE"
  }
}
EOF

echo "Configuration saved to: terraform-backend-config.txt"
echo ""