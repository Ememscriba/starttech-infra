# StartTech Infrastructure

AWS infrastructure managed with Terraform.

## Repository Structure

## Prerequisites

- Terraform 1.5+
- AWS CLI configured
- AWS account with appropriate permissions

## Infrastructure Components

| Component | Description |
|-----------|-------------|
| VPC | Private network with public and private subnets |
| ALB | Application Load Balancer for traffic distribution |
| ASG | Auto Scaling Group managing EC2 instances |
| S3 | Frontend static file hosting |
| ElastiCache | Redis cluster for caching and sessions |
| CloudWatch | Centralized logging and monitoring |

## Deployment

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Terraform Outputs

After applying you will see:

- vpc_id
- alb_dns_name
- s3_bucket_name

## Remote State

Terraform state is stored in S3 bucket:
starttech-terraform-state-954692413962

## Security

- EC2 instances run in private subnets
- Only ALB is publicly accessible
- Redis only accepts traffic from EC2 security group
- IAM roles follow least privilege principle

## Monitoring

CloudWatch dashboards and alarms are configured for:

- CPU utilization
- ALB request count
- ALB 5XX errors
- Redis CPU
