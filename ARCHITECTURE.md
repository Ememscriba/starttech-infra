# System Architecture

## Overview

StartTech runs on AWS using a three tier architecture. The frontend
is served from S3 via CloudFront. The backend runs on EC2 instances
behind an Application Load Balancer. Redis handles caching and
sessions. MongoDB Atlas handles data persistence.

## Architecture Diagram

## Network Design

The VPC uses the CIDR block 10.0.0.0/16 and spans two
availability zones for high availability.

Public subnets (10.0.1.0/24 and 10.0.2.0/24) host the
ALB and NAT Gateway.

Private subnets (10.0.10.0/24 and 10.0.11.0/24) host
EC2 instances and Redis.

## Security Design

Traffic flow is strictly controlled:

- Internet can only reach the ALB on ports 80 and 443
- ALB can only talk to EC2 on port 8080
- EC2 can only talk to Redis on port 6379
- EC2 instances have no public IP addresses

## Auto Scaling

The ASG maintains a minimum of 1 and maximum of 2 EC2
instances. It scales up when CPU exceeds 80% and scales
down when CPU drops below 20%.

## CI/CD Flow

Infrastructure changes go through a two stage pipeline.
The plan stage runs on every push and pull request.
The apply stage runs only on merges to Main.

## Monitoring

CloudWatch collects logs from three log groups:

- /starttech/backend
- /starttech/frontend
- /starttech/alb

Three alarms watch for high CPU, low CPU, and ALB errors.
