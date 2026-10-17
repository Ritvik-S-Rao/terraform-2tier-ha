terraform {
	required_version = ">=1.5.0"
	required_providers {
		aws = {
			source = "hashicorp/aws"
			version = "~>6.0"
		}
		random = {
			source = "hashicorp/random"
			version = "~>3.0"
		}
	}
}


provider "aws"{
	region = "us-east-1"
}


# Unique suffix to guarantee global S3 bucket name uniqueness
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Fetch your AWS Account ID dynamically
data "aws_caller_identity" "current" {}

# 1. S3 Bucket for Remote State Storage
resource "aws_s3_bucket" "state_bucket" {
  bucket        = "devops-2tier-tfstate-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # Allows clean teardown during project deletion

  tags = {
    Name        = "Terraform State Storage"
    Environment = "Dev"
  }
}

# Enable Server-Side Encryption (Protects secrets at rest in state)
resource "aws_s3_bucket_server_side_encryption_configuration" "state_encryption" {
  bucket = aws_s3_bucket.state_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all Public Access
resource "aws_s3_bucket_public_access_block" "state_public_block" {
  bucket = aws_s3_bucket.state_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 2. DynamoDB Table for State Locking
resource "aws_dynamodb_table" "state_locks" {
  name         = "terraform-2tier-state-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "Terraform State Lock Table"
  }
}

# 3. Outputs needed for 02-infrastructure
output "s3_bucket_name" {
  description = "Name of the S3 bucket to configure in 02-infrastructure/backend.tf"
  value       = aws_s3_bucket.state_bucket.id
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for locking in 02-infrastructure/backend.tf"
  value       = aws_dynamodb_table.state_locks.name
}
