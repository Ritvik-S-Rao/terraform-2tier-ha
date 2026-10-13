#!/bin/bash

# Query AWS to get your account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
STATE_BUCKET="devops-2tier-tfstate-${ACCOUNT_ID}"
STATE_TABLE="devops-2tier-tfstate-locks"

echo "Initializing Terraform with predicted backend: ${STATE_BUCKET}..."

terraform init -reconfigure \
  -backend-config="bucket=${STATE_BUCKET}" \
  -backend-config="key=02-infrastructure/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=${STATE_TABLE}"
