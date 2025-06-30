#!/bin/bash

# SeeGap Analytics Platform - Deployment Setup Script
# This script helps set up the deployment environment for GCP

set -e

echo "🚀 SeeGap Analytics Platform - Deployment Setup"
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if required tools are installed
check_dependencies() {
    print_step "Checking dependencies..."
    
    local missing_deps=()
    
    if ! command -v gcloud &> /dev/null; then
        missing_deps+=("gcloud")
    fi
    
    if ! command -v terraform &> /dev/null; then
        missing_deps+=("terraform")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    if ! command -v node &> /dev/null; then
        missing_deps+=("node")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        echo "Please install the missing dependencies and run this script again."
        exit 1
    fi
    
    print_status "All dependencies are installed ✓"
}

# Setup GCP authentication
setup_gcp_auth() {
    print_step "Setting up GCP authentication..."
    
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        print_warning "No active GCP authentication found"
        echo "Please run: gcloud auth login"
        echo "Then run: gcloud auth application-default login"
        exit 1
    fi
    
    # Set the project
    gcloud config set project eminent-subset-462023-f9
    
    print_status "GCP authentication configured ✓"
}

# Enable required GCP APIs
enable_gcp_apis() {
    print_step "Enabling required GCP APIs..."
    
    local apis=(
        "compute.googleapis.com"
        "cloudresourcemanager.googleapis.com"
        "iamcredentials.googleapis.com"
        "iam.googleapis.com"
    )
    
    for api in "${apis[@]}"; do
        print_status "Enabling $api..."
        gcloud services enable "$api"
    done
    
    print_status "GCP APIs enabled ✓"
}

# Generate SSH keys if they don't exist
generate_ssh_keys() {
    print_step "Setting up SSH keys..."
    
    if [ ! -f ~/.ssh/id_rsa ]; then
        print_status "Generating SSH key pair..."
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
    else
        print_status "SSH keys already exist ✓"
    fi
    
    # Display public key for GitHub secrets
    echo ""
    print_warning "Add the following public key to your GitHub repository secrets as SSH_PUBLIC_KEY:"
    echo "----------------------------------------"
    cat ~/.ssh/id_rsa.pub
    echo "----------------------------------------"
    echo ""
    print_warning "Add the following private key to your GitHub repository secrets as SSH_PRIVATE_KEY:"
    echo "----------------------------------------"
    cat ~/.ssh/id_rsa
    echo "----------------------------------------"
    echo ""
}

# Create service account for GitHub Actions
create_service_account() {
    print_step "Creating service account for GitHub Actions..."
    
    local sa_name="github-actions-sa"
    local sa_email="${sa_name}@eminent-subset-462023-f9.iam.gserviceaccount.com"
    
    # Check if service account exists
    if gcloud iam service-accounts describe "$sa_email" &> /dev/null; then
        print_status "Service account already exists ✓"
    else
        print_status "Creating service account..."
        gcloud iam service-accounts create "$sa_name" \
            --display-name="GitHub Actions Service Account" \
            --description="Service account for GitHub Actions CI/CD"
    fi
    
    # Assign required roles
    local roles=(
        "roles/compute.admin"
        "roles/iam.serviceAccountUser"
        "roles/resourcemanager.projectIamAdmin"
        "roles/storage.admin"
    )
    
    for role in "${roles[@]}"; do
        print_status "Assigning role: $role"
        gcloud projects add-iam-policy-binding eminent-subset-462023-f9 \
            --member="serviceAccount:$sa_email" \
            --role="$role"
    done
    
    # Create and download key
    local key_file="github-actions-key.json"
    if [ ! -f "$key_file" ]; then
        print_status "Creating service account key..."
        gcloud iam service-accounts keys create "$key_file" \
            --iam-account="$sa_email"
    fi
    
    echo ""
    print_warning "Add the following service account key to your GitHub repository secrets as GCP_SERVICE_ACCOUNT_KEY:"
    echo "----------------------------------------"
    cat "$key_file"
    echo "----------------------------------------"
    echo ""
}

# Setup Terraform backend
setup_terraform_backend() {
    print_step "Setting up Terraform backend..."
    
    local bucket_name="seegap-terraform-state-$(date +%s)"
    
    # Create bucket for Terraform state
    if ! gsutil ls -b gs://"$bucket_name" &> /dev/null; then
        print_status "Creating Terraform state bucket..."
        gsutil mb gs://"$bucket_name"
        gsutil versioning set on gs://"$bucket_name"
    fi
    
    # Update Terraform configuration
    if [ ! -f terraform/backend.tf ]; then
        print_status "Creating Terraform backend configuration..."
        cat > terraform/backend.tf << EOF
terraform {
  backend "gcs" {
    bucket = "$bucket_name"
    prefix = "terraform/state"
  }
}
EOF
    fi
    
    print_status "Terraform backend configured ✓"
}

# Validate environment configuration
validate_environment() {
    print_step "Validating environment configuration..."
    
    if [ ! -f .env ]; then
        print_status "Creating .env file from template..."
        cp .env.example .env
        print_warning "Please update the .env file with your configuration"
    fi
    
    # Check if required environment variables are set
    local required_vars=(
        "CLOUDFLARE_API_TOKEN"
        "CLOUDFLARE_ZONE_ID"
    )
    
    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if ! grep -q "^$var=" .env || grep -q "^$var=$" .env; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -ne 0 ]; then
        print_warning "Missing environment variables in .env: ${missing_vars[*]}"
        echo "Please update the .env file with the required values"
    else
        print_status "Environment configuration validated ✓"
    fi
}

# Test Docker setup
test_docker() {
    print_step "Testing Docker setup..."
    
    if docker info &> /dev/null; then
        print_status "Docker is running ✓"
    else
        print_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
}

# Initialize Terraform
init_terraform() {
    print_step "Initializing Terraform..."
    
    cd terraform
    terraform init
    terraform validate
    cd ..
    
    print_status "Terraform initialized ✓"
}

# Display next steps
show_next_steps() {
    echo ""
    echo "🎉 Setup completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Add the displayed keys to your GitHub repository secrets"
    echo "2. Update the .env file with your Cloudflare configuration"
    echo "3. Commit and push your changes to trigger the deployment"
    echo ""
    echo "GitHub Secrets to configure:"
    echo "- GCP_SERVICE_ACCOUNT_KEY"
    echo "- SSH_PRIVATE_KEY"
    echo "- SSH_PUBLIC_KEY"
    echo "- CLOUDFLARE_API_TOKEN"
    echo "- CLOUDFLARE_ZONE_ID"
    echo ""
    echo "Deployment URLs:"
    echo "- Main: https://loyalty.seegap.com"
    echo "- API: https://api.loyalty.seegap.com"
    echo "- Tracking: https://track.loyalty.seegap.com"
    echo ""
}

# Main execution
main() {
    check_dependencies
    setup_gcp_auth
    enable_gcp_apis
    generate_ssh_keys
    create_service_account
    setup_terraform_backend
    validate_environment
    test_docker
    init_terraform
    show_next_steps
}

# Run main function
main "$@"
