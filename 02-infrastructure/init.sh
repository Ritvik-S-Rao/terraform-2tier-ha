#!/bin/bash
# Dynamically fetch backend details from the 01-backend state vault
STATE_BUCKET=$(cd ../01-backend && terraform output -raw s3_bucket_name)
STATE_TABLE=$(cd ../01-backend && terraform output -raw dynamodb_table_name)

echo "Initializing Terraform with dynamic backend..."

terraform init -reconfigure\
  -backend-config="bucket=${STATE_BUCKET}" \
  -backend-config="key=infrastructure/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=${STATE_TABLE}" \
  -backend-config="encrypt=true"
