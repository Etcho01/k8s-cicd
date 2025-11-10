# Backend configuration for remote state management
# Uncomment and configure after creating S3 bucket and DynamoDB table

# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "cicd-k8s/terraform.tfstate"
#     region         = "eu-west-1"
#     encrypt        = true
#     dynamodb_table = "terraform-state-lock"
#   }
# }

# To create the backend infrastructure:
# 1. Create S3 bucket with versioning enabled
# 2. Create DynamoDB table with LockID as partition key
# 3. Uncomment the backend block above
# 4. Run: terraform init -migrate-state