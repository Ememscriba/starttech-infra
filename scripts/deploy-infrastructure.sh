#!/bin/bash
set -e

echo "Deploying infrastructure with Terraform..."

ENVIRONMENT=${1:-production}

echo "Environment: $ENVIRONMENT"

cd terraform

echo "Initializing Terraform..."
terraform init

echo "Validating configuration..."
terraform validate

echo "Planning changes..."
terraform plan -out=tfplan

echo "Applying changes..."
terraform apply tfplan

echo "Infrastructure deployed successfully!"
terraform output
