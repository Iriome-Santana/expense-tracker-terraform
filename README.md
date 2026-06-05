# Expense Tracker — Terraform Infrastructure

![Terraform](https://img.shields.io/badge/Terraform-v1.15-7B42BC?logo=terraform)
![AWS](https://img.shields.io/badge/AWS-eu--west--1-FF9900?logo=amazonaws)
![State](https://img.shields.io/badge/state-S3%20remote-blue)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

---

## What is this?

Infrastructure as Code for the [SRE Expense Tracker](https://github.com/Iriome-Santana/expense-tracker-sre) — a production REST API running on AWS EC2.

This repository defines the complete AWS infrastructure of the expense tracker as Terraform code. Every resource was imported from an existing production environment, meaning no infrastructure was destroyed or recreated during migration. The Terraform state is stored remotely in S3 with locking enabled.

---

## Infrastructure overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    AWS Cloud (eu-west-1)                        │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  VPC 10.0.0.0/16                                         │   │
│  │                                                          │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │  Public Subnet 10.0.1.0/24 (eu-west-1a)            │  │   │
│  │  │                                                    │  │   │
│  │  │  ┌─────────────────────────────────────────────┐   │  │   │
│  │  │  │  EC2 t3.micro                               │   │  │   │
│  │  │  │  ├── sg.app (inbound: 8000, 22 from sg.web) │   │  │   │
│  │  │  │  ├── IAM Instance Profile                   │   │  │   │
│  │  │  │  │   ├── SSM Session Manager                │   │  │   │
│  │  │  │  │   ├── CloudWatch Agent                   │   │  │   │
│  │  │  │  │   └── S3 backup (least privilege)        │   │  │   │
│  │  │  │  └── Elastic IP 52.31.3.15                  │   │  │   │
│  │  │  └─────────────────────────────────────────────┘   │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  │                          │                               │   │
│  │                   Internet Gateway                       │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  S3 Bucket — expense-tracker-backups-iriome-2026         │   │
│  │  ├── Versioning enabled                                  │   │
│  │  ├── Public access blocked                               │   │
│  │  └── Lifecycle: IA (30d) → Glacier (90d) → Delete (365d)│   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Resources managed

| File | Resources |
|---|---|
| `networking.tf` | VPC, public subnet, Internet Gateway, route table, route table association |
| `security.tf` | Security groups: `sg.app`, `sg.database`, `sg.public-web` |
| `iam.tf` | IAM role, custom S3 policy, policy attachments, instance profile |
| `storage.tf` | S3 bucket, versioning, lifecycle configuration, public access block |
| `compute.tf` | EC2 instance, Elastic IP |

**Total: 18 resources under Terraform management.**

---

## Remote state

State is stored in S3 with file locking enabled:

```hcl
backend "s3" {
  bucket       = "terraform-state-iriome-2026"
  key          = "expense-tracker/terraform.tfstate"
  region       = "eu-west-1"
  use_lockfile = true
  encrypt      = true
}
```

The state bucket was created manually before Terraform was initialised — it cannot manage its own backend.

---

## Quick start

**Prerequisites:** Terraform >= 1.5.0, AWS CLI configured with appropriate permissions.

```bash
git clone https://github.com/Iriome-Santana/expense-tracker-terraform.git
cd expense-tracker-terraform

cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

terraform init
terraform plan
```

---

## Variables

| Variable | Description | Default |
|---|---|---|
| `aws_region` | AWS region | `eu-west-1` |
| `project_name` | Project name for tagging | `expense-tracker` |
| `environment` | Environment name | `production` |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` |
| `subnet_cidr` | Public subnet CIDR | `10.0.1.0/24` |
| `instance_type` | EC2 instance type | `t3.micro` |
| `ami_id` | AMI ID (required) | — |
| `backup_bucket_name` | S3 backup bucket name (required) | — |
| `account_id` | AWS account ID (required) | — |
| `db_user` | PostgreSQL user | `expenseuser` |
| `db_password` | PostgreSQL password — sensitive (required) | — |

Variables marked as required have no default and must be set in `terraform.tfvars`. The `db_password` variable is marked `sensitive = true` and will never appear in plan or apply output.

---

## Outputs

```bash
terraform output
```

| Output | Description |
|---|---|
| `instance_id` | EC2 instance ID |
| `public_ip` | Elastic IP address |
| `vpc_id` | VPC ID |
| `backup_bucket_name` | S3 backup bucket name |
| `iam_role_arn` | IAM role ARN |

---

## Architecture Decision Records

### Why import instead of recreate

The expense tracker was already running in production with a real client using it. Destroying and recreating the infrastructure would have caused downtime. Terraform's import capability allows adopting existing resources into state management without disruption. Every resource was imported individually and the plan verified clean (`0 to add, 0 to change, 0 to destroy`) before any apply.

### Why remote state in S3 with file locking

Local state is lost if the machine is reformatted and cannot be shared safely across multiple operators. S3 provides durable, encrypted remote storage. File locking (`use_lockfile = true`) prevents concurrent applies from corrupting the state. The state bucket was provisioned manually once — Terraform cannot manage the backend it depends on to store its own state.

### Why default_tags on the provider

Defining tags once on the provider block ensures every resource created by this configuration carries `Project`, `Environment`, and `ManagedBy = "terraform"` tags automatically. In the AWS console, filtering by `ManagedBy = "terraform"` immediately shows which resources are managed by this configuration and which were created manually.

### Why sensitive = true on db_password

Marking a variable as sensitive prevents Terraform from displaying its value in plan or apply output, in state diffs, and in logs. The actual value lives only in `terraform.tfvars` which is in `.gitignore` and never committed to the repository.

### Known technical debt

**EBS volume not encrypted:** The root EBS volume of the EC2 instance is not encrypted. EBS encryption must be enabled at instance creation and cannot be activated on a running instance without replacing it. Encrypting the volume requires: create snapshot → copy snapshot with encryption → restore new instance. Deferred to avoid production downtime. Tracked here as explicit technical debt.

**IMDSv2 not enforced:** The instance metadata service is running in optional mode rather than required mode. IMDSv2 prevents SSRF attacks that could expose the IAM Instance Profile credentials via the metadata endpoint. Enforcing it requires instance replacement for the same reason as EBS encryption. Deferred alongside EBS encryption — both will be addressed in the same planned maintenance window.

**Credentials in user_data:** Database credentials are passed via user_data template variables. While the credentials are not exposed in the repository, user_data is accessible from within the instance via the metadata endpoint. The correct solution is AWS Secrets Manager — the instance would fetch credentials at runtime rather than receiving them at launch. Deferred pending Secrets Manager integration.

---

## Security scanning

This repository is scanned by the [DevSecOps Security Pipeline](https://github.com/Iriome-Santana/devsecops-expense-tracker) which runs Checkov on every push to detect infrastructure misconfigurations.

---

## Author

Built by **Iriome Santana** as part of a self-taught journey into Site Reliability Engineering and DevOps.

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Iriome%20Santana-0077B5?logo=linkedin)](https://www.linkedin.com/in/iriome-santana-socorro)
