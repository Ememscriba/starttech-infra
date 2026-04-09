# Building a Production-Grade CI/CD Infrastructure on AWS

A complete guide to building, deploying, and managing a full-stack application on AWS using Terraform, GitHub Actions, and Docker.

---

## What This Project Solves

Most engineering teams waste hours on manual deployments. A developer finishes a feature, then someone has to SSH into a server, pull the code, restart the app, and hope nothing breaks. That process is slow, error-prone, and impossible to scale.

This project eliminates that entirely. A developer pushes code to GitHub. Everything after that — testing, building, packaging, and deploying — happens automatically. The infrastructure itself is also code, meaning you can rebuild your entire AWS environment from scratch in under 30 minutes.

This is the foundation of how serious engineering teams ship software.

---

## What You Will Build

```
React Frontend    → S3 + CloudFront (static file hosting with global CDN)
Go Backend        → EC2 + Auto Scaling Group + Application Load Balancer
Caching           → ElastiCache Redis
Database          → MongoDB Atlas
Monitoring        → CloudWatch logs, alarms, and dashboards
CI/CD             → GitHub Actions pipelines for all three tiers
Infrastructure    → Terraform modules managing everything on AWS
```

---

## Tools You Need

| Tool | Purpose | Version |
|------|---------|---------|
| Terraform | Infrastructure as code | 1.5+ |
| AWS CLI | Talk to AWS from terminal | v2 |
| Docker | Package the backend app | Any recent |
| Git | Version control | Any |
| Node.js | Build the React frontend | 18+ |
| Go | Run and test the backend | 1.21+ |
| GitHub CLI (gh) | Manage GitHub from terminal | Any |

---

## Part 1 — Setting Up Your Machine

### Install Terraform on Linux

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

### Install AWS CLI v2

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install
```

### Install Docker

```bash
sudo apt update
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
newgrp docker
```

### Install Go

```bash
wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc
```

### Install Node.js

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install nodejs
```

### Install GitHub CLI

```bash
sudo apt install gh
gh auth login
```

### Verify everything installed

```bash
terraform --version
aws --version
docker --version
go version
node --version
gh --version
```

---

## Part 2 — AWS Account Setup

### Why you need a dedicated IAM user

Never use your root AWS account for day-to-day work. Create a dedicated user so that if credentials are ever exposed, you delete that user and your main account stays safe.

### Create the IAM user

1. Log into https://console.aws.amazon.com
2. Search for IAM and click it
3. Click Users on the left sidebar
4. Click Create user
5. Name it starttech-deployer
6. Click Next
7. Select Attach policies directly
8. Search for AdministratorAccess and tick it
9. Click Next then Create user

### Generate access keys

1. Click on starttech-deployer in the users list
2. Click the Security credentials tab
3. Scroll to Access keys and click Create access key
4. Select Command Line Interface
5. Tick the confirmation checkbox
6. Click Create access key
7. Download the CSV immediately — the secret key never appears again

### Connect your terminal to AWS

```bash
aws configure
```

Enter your keys when prompted. Set region to us-east-1 and format to json.

Verify the connection:

```bash
aws sts get-caller-identity
```

You should see your account details printed out.

---

## Part 3 — GitHub Repository Setup

You need two repositories. One holds all your infrastructure code. The other holds your application code.

```bash
gh repo create starttech-infra --public --clone
gh repo create starttech-application --public --clone
```

### Create the folder structure for starttech-infra

```bash
cd starttech-infra
mkdir -p .github/workflows
mkdir -p terraform/modules/networking
mkdir -p terraform/modules/compute
mkdir -p terraform/modules/storage
mkdir -p terraform/modules/monitoring
mkdir -p scripts monitoring

touch .github/workflows/infrastructure-deploy.yml
touch terraform/main.tf terraform/variables.tf terraform/outputs.tf
touch terraform/terraform.tfvars.example
touch terraform/modules/networking/main.tf
touch terraform/modules/networking/variables.tf
touch terraform/modules/networking/outputs.tf
touch terraform/modules/compute/main.tf
touch terraform/modules/compute/variables.tf
touch terraform/modules/compute/outputs.tf
touch terraform/modules/storage/main.tf
touch terraform/modules/storage/variables.tf
touch terraform/modules/storage/outputs.tf
touch terraform/modules/monitoring/main.tf
touch terraform/modules/monitoring/variables.tf
touch terraform/modules/monitoring/outputs.tf
touch scripts/deploy-infrastructure.sh
touch monitoring/cloudwatch-dashboard.json
touch monitoring/alarm-definitions.json
touch monitoring/log-insights-queries.txt
touch README.md
```

### Create the folder structure for starttech-application

```bash
cd ~/starttech-application
mkdir -p .github/workflows frontend backend scripts

touch .github/workflows/frontend-ci-cd.yml
touch .github/workflows/backend-ci-cd.yml
touch scripts/deploy-frontend.sh
touch scripts/deploy-backend.sh
touch scripts/health-check.sh
touch scripts/rollback.sh
touch README.md
```

### Create a .gitignore for the infra repo

```bash
cd ~/starttech-infra
nano .gitignore
```

Add this content:

```
.terraform/
.terraform.lock.hcl
terraform.tfstate
terraform.tfstate.backup
*.tfvars
.DS_Store
```

Push both repos:

```bash
cd ~/starttech-infra
git add .
git commit -m "chore: scaffold repository structure"
git push --set-upstream origin Main

cd ~/starttech-application
git add .
git commit -m "chore: scaffold repository structure"
git push --set-upstream origin Main
```

---

## Part 4 — Terraform Infrastructure

Terraform lets you describe your AWS infrastructure as code. Instead of clicking around the AWS console, you write files that describe exactly what you want. Run one command and Terraform builds everything.

### Understanding modules

Instead of putting all code in one file, you split it into modules. Each module handles one concern. This makes code reusable and easy to understand.

```
terraform/
└── modules/
    ├── networking/   handles VPC, subnets, security groups
    ├── compute/      handles EC2, ALB, Auto Scaling
    ├── storage/      handles S3, ElastiCache
    └── monitoring/   handles CloudWatch
```

### terraform/main.tf

This is the entry point. It tells Terraform which providers to use and calls each module.

```hcl
terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "production/terraform.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "networking" {
  source       = "./modules/networking"
  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
}

module "compute" {
  source                = "./modules/compute"
  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  public_subnets        = module.networking.public_subnet_ids
  private_subnets       = module.networking.private_subnet_ids
  ec2_security_group_id = module.networking.ec2_security_group_id
  alb_security_group_id = module.networking.alb_security_group_id
}

module "storage" {
  source                  = "./modules/storage"
  project_name            = var.project_name
  environment             = var.environment
  private_subnets         = module.networking.private_subnet_ids
  redis_security_group_id = module.networking.redis_security_group_id
}

module "monitoring" {
  source       = "./modules/monitoring"
  project_name = var.project_name
  environment  = var.environment
  asg_name     = module.compute.asg_name
  alb_arn      = module.compute.alb_arn
}
```

### terraform/variables.tf

```hcl
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "starttech"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}
```

### The Networking Module

The VPC is your private network on AWS. Think of it as a walled city. Everything inside can talk to each other. Nothing outside can get in unless you explicitly allow it.

Public subnets hold resources that face the internet — the load balancer and NAT gateway.
Private subnets hold resources that should never be directly reachable — your EC2 servers and Redis.

```hcl
# terraform/modules/networking/main.tf

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
  }
}

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${var.project_name}-private-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name        = "${var.project_name}-nat-gateway"
    Environment = var.environment
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-private-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for the load balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-alb-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-ec2-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "redis" {
  name        = "${var.project_name}-redis-sg"
  description = "Security group for Redis"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-redis-sg"
    Environment = var.environment
  }
}
```

### The Compute Module

The compute module creates the EC2 instances, the load balancer, and the auto scaling group.

The Auto Scaling Group watches your EC2 instances. If CPU goes above 80% it adds a new server. If CPU drops below 20% it removes one. This means your infrastructure scales with your traffic automatically.

The Application Load Balancer sits in front of all your EC2 instances. It receives every request and distributes them across your servers. If one server goes down the ALB stops sending it traffic.

```hcl
# terraform/modules/compute/main.tf

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "${var.project_name}-ec2-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.ec2_security_group_id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y amazon-cloudwatch-agent
    systemctl start amazon-cloudwatch-agent
    systemctl enable amazon-cloudwatch-agent
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-server"
      Environment = var.environment
    }
  }
}

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnets

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project_name}-tg"
    Environment = var.environment
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-asg"
  desired_capacity    = 1
  min_size            = 1
  max_size            = 2
  target_group_arns   = [aws_lb_target_group.app.arn]
  vpc_zone_identifier = var.private_subnets

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project_name}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}
```

### The Storage Module

S3 stores your React frontend files. CloudFront distributes those files globally so users anywhere in the world get fast load times. ElastiCache gives your backend a Redis server for caching and session management.

```hcl
# terraform/modules/storage/main.tf

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-frontend-${random_id.suffix.hex}"

  tags = {
    Name        = "${var.project_name}-frontend"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document { suffix = "index.html" }
  error_document { key = "index.html" }
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-redis-subnet-group"
  subnet_ids = var.private_subnets

  tags = {
    Name        = "${var.project_name}-redis-subnet-group"
    Environment = var.environment
  }
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.project_name}-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [var.redis_security_group_id]

  tags = {
    Name        = "${var.project_name}-redis"
    Environment = var.environment
  }
}
```

### Running Terraform

Create a remote state bucket first. This stores your Terraform state in S3 so both your laptop and GitHub Actions can access it:

```bash
aws s3api create-bucket \
  --bucket your-project-terraform-state \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket your-project-terraform-state \
  --versioning-configuration Status=Enabled
```

Then initialize and apply:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Type yes when prompted. The full build takes 10 to 20 minutes. ElastiCache takes the longest at around 8 minutes.

---

## Part 5 — The Application Code

### React Frontend

```bash
cd ~/starttech-application/frontend
npx create-react-app . --template cra-template
```

Replace src/App.js with:

```javascript
import React, { useState, useEffect } from 'react';
import './App.css';

function App() {
  const [health, setHealth] = useState('checking...');

  useEffect(() => {
    fetch('/health')
      .then(res => res.json())
      .then(data => setHealth(data.status))
      .catch(() => setHealth('offline'));
  }, []);

  return (
    <div className="App">
      <header className="App-header">
        <h1>StartTech</h1>
        <p>Full Stack Application</p>
        <div className="status">
          <span>API Status: </span>
          <span className={health === 'ok' ? 'online' : 'offline'}>
            {health}
          </span>
        </div>
      </header>
    </div>
  );
}

export default App;
```

### Go Backend

```bash
cd ~/starttech-application/backend
go mod init github.com/yourusername/starttech-backend
```

Create main.go:

```go
package main

import (
  "encoding/json"
  "fmt"
  "log"
  "net/http"
  "os"
  "time"
)

type HealthResponse struct {
  Status    string `json:"status"`
  Timestamp string `json:"timestamp"`
  Version   string `json:"version"`
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
  w.Header().Set("Content-Type", "application/json")
  w.WriteHeader(http.StatusOK)
  json.NewEncoder(w).Encode(HealthResponse{
    Status:    "ok",
    Timestamp: time.Now().UTC().Format(time.RFC3339),
    Version:   "1.0.0",
  })
}

func homeHandler(w http.ResponseWriter, r *http.Request) {
  w.Header().Set("Content-Type", "application/json")
  json.NewEncoder(w).Encode(map[string]string{
    "message": "StartTech API is running",
  })
}

func main() {
  port := os.Getenv("PORT")
  if port == "" {
    port = "8080"
  }

  http.HandleFunc("/health", healthHandler)
  http.HandleFunc("/", homeHandler)

  fmt.Printf("StartTech backend starting on port %s\n", port)
  log.Fatal(http.ListenAndServe(":"+port, nil))
}
```

Create Dockerfile:

```dockerfile
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/main .
EXPOSE 8080
CMD ["./main"]
```

---

## Part 6 — GitHub Actions Pipelines

GitHub Actions runs your pipelines on fresh Ubuntu machines in GitHub's cloud. You never manage those machines. You write a YAML file describing the steps, push it to GitHub, and it runs automatically.

### Adding secrets to GitHub

Your pipelines need AWS credentials and Docker credentials. Never put these in code. Store them as GitHub Secrets.

```bash
gh secret set AWS_ACCESS_KEY_ID --repo yourusername/starttech-application
gh secret set AWS_SECRET_ACCESS_KEY --repo yourusername/starttech-application
gh secret set AWS_REGION --repo yourusername/starttech-application
gh secret set S3_BUCKET_NAME --repo yourusername/starttech-application
gh secret set DOCKER_USERNAME --repo yourusername/starttech-application
gh secret set DOCKER_TOKEN --repo yourusername/starttech-application
```

Each command prompts you to enter the value. The terminal hides what you type.

Verify they saved:

```bash
gh secret list --repo yourusername/starttech-application
```

### Frontend Pipeline

This pipeline triggers when files inside the frontend folder change. It installs dependencies, runs tests, builds the React app, and uploads the build folder to S3.

```yaml
# .github/workflows/frontend-ci-cd.yml

name: Frontend CI/CD

on:
  push:
    branches:
      - Main
    paths:
      - 'frontend/**'
  workflow_dispatch:

jobs:
  build-and-deploy:
    name: Build and Deploy Frontend
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json

      - name: Install dependencies
        working-directory: frontend
        run: npm ci

      - name: Run tests
        working-directory: frontend
        run: npm test -- --watchAll=false --passWithNoTests

      - name: Build React app
        working-directory: frontend
        run: npm run build
        env:
          CI: false

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Deploy to S3
        working-directory: frontend
        run: |
          aws s3 sync build/ s3://${{ secrets.S3_BUCKET_NAME }} --delete
```

### Backend Pipeline

This pipeline has three jobs that run in sequence. Tests must pass before Docker builds. Docker must build before deployment runs.

```yaml
# .github/workflows/backend-ci-cd.yml

name: Backend CI/CD

on:
  push:
    branches:
      - Main
    paths:
      - 'backend/**'
  workflow_dispatch:

jobs:
  test:
    name: Test Backend
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.22'

      - name: Run tests
        working-directory: backend
        run: go test ./... -v

  build-and-push:
    name: Build and Push Docker Image
    runs-on: ubuntu-latest
    needs: test

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_TOKEN }}

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: ./backend
          push: true
          tags: ${{ secrets.DOCKER_USERNAME }}/starttech-backend:latest

  deploy:
    name: Deploy to EC2
    runs-on: ubuntu-latest
    needs: build-and-push

    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Deploy to EC2 via SSM
        run: |
          aws ssm send-command \
            --document-name "AWS-RunShellScript" \
            --targets "Key=tag:aws:autoscaling:groupName,Values=starttech-asg" \
            --parameters commands=["docker pull ${{ secrets.DOCKER_USERNAME }}/starttech-backend:latest","docker stop starttech-backend || true","docker rm starttech-backend || true","docker run -d --name starttech-backend -p 8080:8080 ${{ secrets.DOCKER_USERNAME }}/starttech-backend:latest"] \
            --region ${{ secrets.AWS_REGION }}
```

### Infrastructure Pipeline

This pipeline runs Terraform automatically. On pull requests it only plans — showing what will change. On pushes to Main it applies those changes.

```yaml
# .github/workflows/infrastructure-deploy.yml

name: Infrastructure Deploy

on:
  push:
    branches:
      - Main
    paths:
      - 'terraform/**'
  pull_request:
    branches:
      - Main
  workflow_dispatch:

jobs:
  terraform-plan:
    name: Terraform Plan
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: '1.5.0'

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Terraform Init
        working-directory: terraform
        run: terraform init

      - name: Terraform Plan
        working-directory: terraform
        run: terraform plan -out=tfplan

      - name: Upload plan
        uses: actions/upload-artifact@v4
        with:
          name: tfplan
          path: terraform/tfplan

  terraform-apply:
    name: Terraform Apply
    runs-on: ubuntu-latest
    needs: terraform-plan
    if: github.ref == 'refs/heads/Main' && github.event_name == 'push'

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: '1.5.0'

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Terraform Init
        working-directory: terraform
        run: terraform init

      - name: Download plan
        uses: actions/download-artifact@v4
        with:
          name: tfplan
          path: terraform

      - name: Terraform Apply
        working-directory: terraform
        run: terraform apply -auto-approve tfplan
```

---

## Part 7 — Monitoring

CloudWatch is AWS's built-in monitoring system. You do not pay for a third-party tool. Everything your application logs goes into CloudWatch automatically.

### Log Groups

Three log groups collect all application output:

```
/starttech/backend   Go application logs
/starttech/frontend  Frontend access logs
/starttech/alb       Load balancer access logs
```

### Alarms

Three alarms watch your system health:

| Alarm | Condition | Action |
|-------|-----------|--------|
| High CPU | CPU above 80% for 4 minutes | Scale up |
| Low CPU | CPU below 20% for 4 minutes | Scale down |
| ALB Errors | More than 10 5XX errors in 5 minutes | Investigate |

### Useful Log Insights Queries

Run these in AWS Console under CloudWatch, Logs, Insights.

Find all errors:
```
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 50
```

Find slow requests:
```
fields @timestamp, @message, @duration
| filter @duration > 1000
| sort @duration desc
| limit 20
```

---

## Part 8 — Security Practices

Every security decision in this project follows one principle: give each component the minimum access it needs and nothing more.

**Network security** — EC2 instances have no public IP addresses. The only way to reach them is through the load balancer. Redis only accepts connections from EC2 instances. Nothing else can talk to it.

**Credentials** — AWS keys and Docker tokens never appear in code. They live in GitHub Secrets. Terraform state lives in S3 with versioning enabled so you can recover from mistakes.

**IAM** — EC2 instances get only the permissions they need: write to CloudWatch logs. Nothing else.

**Scanning** — The backend pipeline runs govulncheck before building. The frontend pipeline runs npm audit before building. Both will fail and block deployment if critical vulnerabilities are found.

---

## Common Errors and Fixes

### vCPU limit exceeded

New AWS accounts have a limit of 1 vCPU for t3 instances. Switch to t2.micro which uses a different bucket with no such limit on new accounts.

### CloudFront access denied

New AWS accounts need verification before using CloudFront. Submit a support ticket to AWS requesting account verification. Takes a few hours.

### Terraform state conflict

If two people run terraform apply at the same time the state file gets corrupted. Always use a remote backend in S3 with DynamoDB locking for team environments.

### GitHub Actions secret not found

Secrets are case sensitive. AWS_ACCESS_KEY_ID and aws_access_key_id are different names. Always use uppercase for secret names.

### Docker push unauthorized

Docker Hub personal access tokens expire or get revoked if exposed in chat or logs. Delete the token, generate a new one, update the GitHub Secret.

---

## Destroying Everything

When you finish the project and want to stop AWS charges:

```bash
cd terraform
terraform destroy
```

Type yes when prompted. This deletes everything Terraform created. Note that the S3 state bucket and the Terraform state bucket must be emptied manually before they can be deleted.

---

## Architecture Summary

```
Internet users
      |
CloudFront CDN
      |
S3 Bucket (React static files)

Internet users
      |
Application Load Balancer (public subnet, us-east-1a and us-east-1b)
      |
Auto Scaling Group
      |
EC2 instances (private subnet, t2.micro, Amazon Linux 2)
      |
ElastiCache Redis (private subnet, cache.t3.micro, Redis 7)
      |
MongoDB Atlas (external, free tier)

All EC2 logs → CloudWatch /starttech/backend
ALB logs     → CloudWatch /starttech/alb
Alarms       → CloudWatch high-cpu, low-cpu, alb-errors
Dashboard    → CloudWatch starttech-dashboard
```

---

Built with Terraform, GitHub Actions, Docker, AWS, Go, and React.
