#!/bin/bash

# SeeGap Analytics - Terraform Deployment Script
set -e

echo "🚀 SeeGap Analytics Platform - Terraform Deployment"
echo "=================================================="

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed. Please install Terraform first."
    echo "Visit: https://developer.hashicorp.com/terraform/downloads"
    exit 1
fi

# Check if gcloud is installed and authenticated
if ! command -v gcloud &> /dev/null; then
    echo "❌ Google Cloud CLI is not installed. Please install gcloud first."
    echo "Visit: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if user is authenticated with gcloud
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo "❌ Not authenticated with Google Cloud. Please run: gcloud auth login"
    exit 1
fi

# Check if SSH key exists
if [ ! -f ~/.ssh/id_rsa.pub ]; then
    echo "❌ SSH public key not found at ~/.ssh/id_rsa.pub"
    echo "Please generate an SSH key pair:"
    echo "ssh-keygen -t rsa -b 4096 -C 'your_email@example.com'"
    exit 1
fi

# Check if terraform.tfvars exists
if [ ! -f terraform.tfvars ]; then
    echo "❌ terraform.tfvars file not found."
    echo "Please copy terraform.tfvars.example to terraform.tfvars and fill in your values:"
    echo "cp terraform.tfvars.example terraform.tfvars"
    echo "Then edit terraform.tfvars with your configuration."
    exit 1
fi

echo "✅ Prerequisites check passed!"
echo ""

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init

# Validate configuration
echo "🔍 Validating Terraform configuration..."
terraform validate

# Plan deployment
echo "📋 Planning deployment..."
terraform plan -out=tfplan

# Ask for confirmation
echo ""
read -p "🤔 Do you want to proceed with the deployment? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Deploying infrastructure..."
    terraform apply tfplan
    
    echo ""
    echo "✅ Deployment completed!"
    echo ""
    echo "📊 Infrastructure Summary:"
    echo "========================"
    terraform output
    
    echo ""
    echo "🔗 Your SeeGap Analytics Platform URLs:"
    echo "Main Dashboard: $(terraform output -raw main_url)"
    echo "API Endpoint: $(terraform output -raw api_url)"
    echo "Tracking Script: $(terraform output -raw tracking_url)"
    echo ""
    echo "🖥️  SSH Access:"
    echo "$(terraform output -raw ssh_command)"
    echo ""
    echo "⏳ Note: The application may take 5-10 minutes to fully start up."
    echo "SSL certificates will be automatically configured after DNS propagation."
    echo ""
    echo "🎉 SeeGap Analytics Platform is now live!"
    
else
    echo "❌ Deployment cancelled."
    rm -f tfplan
    exit 1
fi
