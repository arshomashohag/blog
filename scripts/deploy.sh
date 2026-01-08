#!/bin/bash
# Deployment script for the blog platform

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    echo_info "Checking prerequisites..."
    
    if ! command -v terraform &> /dev/null; then
        echo_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        echo_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Get AWS profile from tfvars
    cd "$PROJECT_ROOT/terraform"
    AWS_PROFILE_NAME=$(grep -E "^aws_profile" terraform.tfvars 2>/dev/null | sed 's/.*=.*"\(.*\)"/\1/' | tr -d ' ')
    
    if [ -n "$AWS_PROFILE_NAME" ]; then
        export AWS_PROFILE="$AWS_PROFILE_NAME"
        echo_info "Using AWS profile: $AWS_PROFILE_NAME"
    fi
    
    # Check if SSO session is valid
    if ! aws sts get-caller-identity &> /dev/null; then
        echo_warn "AWS credentials expired or not configured."
        
        if [ -n "$AWS_PROFILE_NAME" ]; then
            echo_info "Attempting SSO login for profile: $AWS_PROFILE_NAME"
            aws sso login --profile "$AWS_PROFILE_NAME"
            
            if ! aws sts get-caller-identity &> /dev/null; then
                echo_error "SSO login failed. Please check your profile configuration."
                exit 1
            fi
        else
            echo_error "Please configure AWS credentials or set aws_profile in terraform.tfvars"
            exit 1
        fi
    fi
    
    echo_info "AWS identity: $(aws sts get-caller-identity --query 'Arn' --output text)"
    echo_info "All prerequisites met."
}

# Install Python dependencies
install_dependencies() {
    echo_info "Installing Python dependencies..."
    
    cd "$PROJECT_ROOT/backend"
    
    # Lambda uses Python 3.11 - ensure we use the same version
    PYTHON_CMD="python3.11"
    if ! command -v $PYTHON_CMD &> /dev/null; then
        echo_warn "python3.11 not found, trying python3..."
        PYTHON_CMD="python3"
        PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f1,2)
        if [ "$PYTHON_VERSION" != "3.11" ]; then
            echo_warn "Warning: Using Python $PYTHON_VERSION but Lambda uses 3.11"
        fi
    fi
    
    echo_info "Using Python: $($PYTHON_CMD --version)"
    
    # Clean build directory for Lambda packaging
    BUILD_DIR="$PROJECT_ROOT/backend/.build"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    
    # Install dependencies into build directory using Python 3.11
    $PYTHON_CMD -m pip install -r requirements.txt -t "$BUILD_DIR" --upgrade --platform manylinux2014_x86_64 --only-binary=:all:
    
    # Copy application code to build directory
    cp -r app "$BUILD_DIR/"
    cp handler.py "$BUILD_DIR/"
    
    echo_info "Dependencies installed to .build/ directory."
}

# Deploy infrastructure
deploy_infrastructure() {
    echo_info "Deploying infrastructure..."
    
    cd "$PROJECT_ROOT/terraform"
    
    # Check for tfvars file
    if [ ! -f "terraform.tfvars" ]; then
        echo_error "terraform.tfvars not found!"
        echo_warn "Copy terraform.tfvars.example to terraform.tfvars and update the values."
        exit 1
    fi
    
    terraform init
    terraform plan -out=tfplan
    
    echo ""
    read -p "Do you want to apply this plan? (y/n) " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        terraform apply tfplan
        rm tfplan
    else
        echo_warn "Deployment cancelled."
        rm tfplan
        exit 0
    fi
    
    echo_info "Infrastructure deployed."
}

# Upload frontend files
upload_frontend() {
    echo_info "Uploading frontend files..."
    
    cd "$PROJECT_ROOT/terraform"
    
    S3_BUCKET=$(terraform output -raw s3_bucket_name)
    
    if [ -z "$S3_BUCKET" ]; then
        echo_error "Could not get S3 bucket name from Terraform output."
        exit 1
    fi
    
    echo_info "Uploading to bucket: $S3_BUCKET"
    
    # Sync frontend files
    aws s3 sync "$PROJECT_ROOT/frontend" "s3://$S3_BUCKET" \
        --delete \
        --exclude ".DS_Store" \
        --exclude "*.map"
    
    # Set correct content types
    aws s3 cp "s3://$S3_BUCKET" "s3://$S3_BUCKET" --recursive \
        --exclude "*" --include "*.html" \
        --content-type "text/html" \
        --metadata-directive REPLACE
    
    aws s3 cp "s3://$S3_BUCKET" "s3://$S3_BUCKET" --recursive \
        --exclude "*" --include "*.css" \
        --content-type "text/css" \
        --metadata-directive REPLACE
    
    aws s3 cp "s3://$S3_BUCKET" "s3://$S3_BUCKET" --recursive \
        --exclude "*" --include "*.js" \
        --content-type "application/javascript" \
        --metadata-directive REPLACE
    
    echo_info "Frontend files uploaded."
}

# Invalidate CloudFront cache
invalidate_cache() {
    echo_info "Invalidating CloudFront cache..."
    
    cd "$PROJECT_ROOT/terraform"
    
    DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id)
    
    if [ -z "$DISTRIBUTION_ID" ]; then
        echo_warn "Could not get CloudFront distribution ID. Skipping cache invalidation."
        return
    fi
    
    aws cloudfront create-invalidation \
        --distribution-id "$DISTRIBUTION_ID" \
        --paths "/*"
    
    echo_info "Cache invalidation initiated."
}

# Print deployment info
print_info() {
    echo ""
    echo "======================================"
    echo "       DEPLOYMENT COMPLETE!"
    echo "======================================"
    echo ""
    
    cd "$PROJECT_ROOT/terraform"
    
    echo "CloudFront URL: $(terraform output -raw cloudfront_url)"
    echo "Admin URL: $(terraform output -raw admin_url)"
    echo ""
    echo "Whitelisted IPs:"
    terraform output -json whitelisted_ips | jq -r '.[]'
    echo ""
    echo "======================================"
}

# Main
main() {
    echo ""
    echo "======================================"
    echo "    BLOG PLATFORM DEPLOYMENT"
    echo "======================================"
    echo ""
    
    check_prerequisites
    install_dependencies
    deploy_infrastructure
    upload_frontend
    invalidate_cache
    print_info
}

main "$@"
