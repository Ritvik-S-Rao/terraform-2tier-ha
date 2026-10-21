# terraform-2tier-ha

Terraform code that provisions a highly-available, two-tier web application on AWS: a public Application Load Balancer fronting an Auto Scaling Group of EC2 instances in private subnets, backed by a MySQL RDS instance in isolated data subnets. Remote state is managed in a separate bootstrap stack using S3 + DynamoDB, and the core infrastructure is deployed via a fully automated GitHub Actions CI/CD pipeline.

## Architecture

```text
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
│                    RDS MySQL 8.0                        │
└─────────────────────────────────────────────────────────┘
```

- **VPC**: `10.0.0.0/16` split into public, private-app, and private-data subnet tiers across 2 Availability Zones.
- **Networking**: Internet Gateway (`aws_internet_gateway`) attached to the VPC to give public subnets a route to the internet, plus a single NAT Gateway for outbound access from the private app tier (cost-optimized, not per-AZ).
- **Security Groups**: ALB accepts 80/443 from the internet; the app tier only accepts port 80 from the ALB's security group; the database only accepts 3306 from the app tier's security group.
- **Compute**: Application Load Balancer → Target Group → Auto Scaling Group (min 2 / desired 2 / max 4) running Amazon Linux 2023 with Apache (`httpd`), bootstrapped via `user_data` to serve a page showing the instance ID and AZ.
- **Database**: Single-AZ RDS MySQL 8.0 (`db.t3.micro`, 20GB gp3). Multi-AZ is intentionally disabled to keep learning/lab costs down — see note in `modules/database/main.tf`.

## CI/CD Pipeline

Deployments are automated using GitHub Actions (`.github/workflows/terraform.yml`). 

- **Pull Requests:** Any PR modifying the `02-infrastructure` directory triggers a code formatting check (`terraform fmt -check`), validation, and a `terraform plan`.
- **Main Branch Merges:** Merging to `main` triggers the `apply` job.
- **Dynamic Backend:** The pipeline uses the AWS CLI to fetch your AWS Account ID dynamically at runtime, avoiding hardcoded S3 bucket names in the workflow file.
- **Approval Gates:** The deployment is tied to a GitHub Environment named `production`. The pipeline pauses after a successful plan and requires manual approval before executing `terraform apply`.

## Repository structure

```text
terraform-2tier-ha/
├── .github/workflows/
│   └── terraform.yml        # CI/CD pipeline for automated planning and deployment
├── 01-backend/              # Bootstrap stack: remote state backend
│   └── main.tf              # S3 bucket (encrypted, public access blocked) + DynamoDB lock table
│
└── 02-infrastructure/        # Main application stack
    ├── backend.tf            # Empty S3 backend block (configured at init time)
    ├── main.tf               # Root module: wires network/security/compute/database together
    ├── outputs.tf             # website_url, database_endpoint
    ├── init.sh               # Fetches backend config dynamically for local testing
    └── modules/
        ├── network/           # VPC, subnets (public/app/data), IGW, NAT GW, route tables
        ├── security/           # Security groups for ALB, app tier, and database
        ├── compute/            # ALB, target group, listener, launch template, ASG
        └── database/           # DB subnet group + RDS MySQL instance
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5.0
- An AWS account and credentials configured (e.g. via `aws configure` or environment variables)
- **AWS SSM Parameter:** The RDS master password must exist in SSM Parameter Store *before* the pipeline runs. `02-infrastructure/main.tf` reads it via a data source, which is resolved during the plan phase:

  ```bash
  aws ssm put-parameter \
    --name "/devops-2tier/database/master-password" \
    --type "SecureString" \
    --value "<choose-a-strong-password>" \
    --region us-east-1
  ```
- **GitHub Secrets:** Add your AWS CI IAM user credentials to your repository secrets:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
- **GitHub Environments:** Create an environment named `production` in your repository settings and configure yourself as a Required Reviewer to enable the manual deployment gate.

## Usage

### 1. Bootstrap the remote state backend (Local)

The backend must be created locally first so the CI pipeline has a place to store the state file.

```bash
cd 01-backend
terraform init
terraform apply -auto-approve
```

### 2. Deploy the infrastructure (Automated via CI/CD)

1. Create a new branch and push your infrastructure changes to GitHub.
2. Open a Pull Request. The GitHub Actions runner will automatically execute `terraform plan`.
3. Merge the Pull Request to `main`.
4. Navigate to the **Actions** tab in GitHub, review the pending deployment, and click **Approve and deploy** for the `production` environment. 

*(If you need to test changes locally before pushing, run `./init.sh` inside `02-infrastructure` to configure your local backend).*

### 3. Access the app

Once the pipeline completes, you can pull the load balancer URL locally:

```bash
cd 02-infrastructure
./init.sh
terraform output website_url
```

Open the URL in a browser — each refresh may land on a different instance/AZ, shown on the page.

### Tearing down

To avoid lingering AWS charges, destroy the infrastructure in reverse order from your local machine:

```bash
cd 02-infrastructure 
./init.sh
terraform destroy

cd ../01-backend 
terraform destroy
```

## Notes

- Region is hardcoded to `us-east-1` in both stacks.
- The `01-backend` S3 bucket has `force_destroy = true` and RDS uses `skip_final_snapshot = true` — convenient for a lab/demo environment, but you'll want to remove both before using this pattern in production.
- .terraform/ and all *.tfstate*/*.tfvars* files are gitignored and should never be committed. The .terraform.lock.hcl file is committed to ensure consistent provider versions.
