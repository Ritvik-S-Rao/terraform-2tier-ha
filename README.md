# terraform-2tier-ha

Terraform code that provisions a highly-available, two-tier web application on AWS: a public Application Load Balancer fronting an Auto Scaling Group of EC2 instances in private subnets, backed by a MySQL RDS instance in isolated data subnets. Remote state is managed in a separate bootstrap stack using S3 + DynamoDB.

## Architecture

```
                         Internet                          
                             │                             
                             ▼                             
                  ┌─────────────────────┐
                  │  Internet Gateway   │
                  └──────────┬──────────┘
                             │                             
                             ▼                             
┌─────────────────────────────────────────────────────────┐
│                 PUBLIC SUBNETS (2 AZs)                  │
│                                                         │
│           ALB                    NAT Gateway            │
└────────────────────────────┴────────────────────────────┘
                             │                             
                             ▼                             
┌─────────────────────────────────────────────────────────┐
│               PRIVATE APP SUBNETS (2 AZs)               │
│                                                         │
│                 EC2 Auto Scaling Group                  │
│               (Amazon Linux 2023, httpd)                │
└────────────────────────────┴────────────────────────────┘
                             │                             
                             ▼                             
┌─────────────────────────────────────────────────────────┐
│              PRIVATE DATA SUBNETS (2 AZs)               │
│                                                         │
│                      RDS MySQL 8.0                      │
└─────────────────────────────────────────────────────────┘
```

- **VPC**: `10.0.0.0/16` split into public, private-app, and private-data subnet tiers across 2 Availability Zones.
- **Networking**: Internet Gateway (`aws_internet_gateway`) attached to the VPC to give public subnets a route to the internet, plus a single NAT Gateway for outbound access from the private app tier (cost-optimized, not per-AZ).
- **Security Groups**: ALB accepts 80/443 from the internet; the app tier only accepts port 80 from the ALB's security group; the database only accepts 3306 from the app tier's security group.
- **Compute**: Application Load Balancer → Target Group → Auto Scaling Group (min 2 / desired 2 / max 4) running Amazon Linux 2023 with Apache (`httpd`), bootstrapped via `user_data` to serve a page showing the instance ID and AZ.
- **Database**: Single-AZ RDS MySQL 8.0 (`db.t3.micro`, 20GB gp3). Multi-AZ is intentionally disabled to keep learning/lab costs down — see note in `modules/database/main.tf`.

## Repository structure

```
terraform-2tier-ha/
├── 01-backend/              # Bootstrap stack: remote state backend
│   └── main.tf              # S3 bucket (encrypted, public access blocked) + DynamoDB lock table
│
└── 02-infrastructure/        # Main application stack
    ├── backend.tf            # Empty S3 backend block (configured at init time)
    ├── main.tf                # Root module: wires network/security/compute/database together
    ├── outputs.tf             # website_url, database_endpoint
    ├── init.sh                # Fetches backend config from 01-backend and runs terraform init
    └── modules/
        ├── network/           # VPC, subnets (public/app/data), IGW, NAT GW, route tables
        ├── security/           # Security groups for ALB, app tier, and database
        ├── compute/            # ALB, target group, listener, launch template, ASG
        └── database/           # DB subnet group + RDS MySQL instance
```

This is a two-stage setup: `01-backend` must be applied first to create the S3/DynamoDB backend that `02-infrastructure` then uses to store its own state remotely.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5.0
- An AWS account and credentials configured (e.g. via `aws configure` or environment variables)
- **The RDS master password must exist in SSM Parameter Store *before* you run `terraform plan`.** `02-infrastructure/main.tf` reads it via a data source (`data.aws_ssm_parameter`), and data sources are resolved during plan, not apply — so a missing parameter fails the very first `terraform plan`, not just the deploy step:

  ```bash
  aws ssm put-parameter \
    --name "/devops-2tier/database/master-password" \
    --type "SecureString" \
    --value "<choose-a-strong-password>" \
    --region us-east-1
  ```

  The IAM identity running Terraform needs `ssm:GetParameter` on this path (and `kms:Decrypt` if the parameter is encrypted with a customer-managed KMS key rather than the default `aws/ssm` key).

## Usage

### 1. Bootstrap the remote state backend

```bash
cd 01-backend
terraform init
terraform apply
```

Note the `s3_bucket_name` and `dynamodb_table_name` outputs — the next step reads these automatically.

### 2. Deploy the infrastructure

```bash
cd ../02-infrastructure
./init.sh          # configures the S3 backend using outputs from 01-backend
terraform plan
terraform apply
```

### 3. Access the app

```bash
terraform output website_url
```

Open the URL in a browser — each refresh may land on a different instance/AZ, shown on the page.

### Tearing down

Destroy in reverse order:

```bash
cd 02-infrastructure && terraform destroy
cd ../01-backend && terraform destroy
```

## Notes

- Region is hardcoded to `us-east-1` in both stacks.
- The `01-backend` S3 bucket has `force_destroy = true` and RDS uses `skip_final_snapshot = true` — convenient for a lab/demo environment, but you'll want to remove both before using this pattern in production.
- .terraform/ and all *.tfstate*/*.tfvars* files are gitignored and should never be committed. The .terraform.lock.hcl file is committed to ensure consistent provider versions.
