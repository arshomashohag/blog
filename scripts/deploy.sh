#!/bin/bash
# Deployment script for the blog platform
# Usage: ./deploy.sh [dev|prod] [--skip-frontend] [--skip-infra] [--frontend-only]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default environment
ENVIRONMENT="${1:-dev}"
SKIP_FRONTEND=false
SKIP_INFRA=false
FRONTEND_ONLY=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        dev|prod)
            ENVIRONMENT="$arg"
            ;;
        --skip-frontend)
            SKIP_FRONTEND=true
            ;;
        --skip-infra)
            SKIP_INFRA=true
            ;;
        --frontend-only)
            FRONTEND_ONLY=true
            SKIP_INFRA=true
            ;;
        --help|-h)
            echo "Usage: ./deploy.sh [dev|prod] [options]"
            echo ""
            echo "Environments:"
            echo "  dev     Deploy to development environment (default)"
            echo "  prod    Deploy to production environment"
            echo ""
            echo "Options:"
            echo "  --skip-frontend    Skip frontend upload"
            echo "  --skip-infra       Skip infrastructure deployment"
            echo "  --frontend-only    Only upload frontend (alias for --skip-infra)"
            echo "  --help, -h         Show this help message"
            exit 0
            ;;
    esac
done

# Validate environment
if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
    echo -e "${RED}[ERROR]${NC} Invalid environment: $ENVIRONMENT. Use 'dev' or 'prod'."
    exit 1
fi

# Set environment-specific files
BACKEND_CONFIG="backend-${ENVIRONMENT}.hcl"
TFVARS_FILE="terraform.${ENVIRONMENT}.tfvars"

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo_env() {
    echo -e "${BLUE}[${ENVIRONMENT^^}]${NC} $1"
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
    
    cd "$PROJECT_ROOT/terraform"
    
    # Check for required files
    if [ ! -f "$BACKEND_CONFIG" ]; then
        echo_error "Backend config not found: $BACKEND_CONFIG"
        exit 1
    fi
    
    if [ ! -f "$TFVARS_FILE" ]; then
        echo_error "Variables file not found: $TFVARS_FILE"
        echo_warn "Create $TFVARS_FILE with your environment configuration."
        exit 1
    fi
    
    # Get AWS profile from tfvars
    AWS_PROFILE_NAME=$(grep -E "^aws_profile" "$TFVARS_FILE" 2>/dev/null | sed 's/.*=.*"\(.*\)"/\1/' | tr -d ' ')
    
    if [ -n "$AWS_PROFILE_NAME" ]; then
        export AWS_PROFILE="$AWS_PROFILE_NAME"
        echo_env "Using AWS profile: $AWS_PROFILE_NAME"
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
            echo_error "Please configure AWS credentials or set aws_profile in $TFVARS_FILE"
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

# Initialize Terraform with correct backend
init_terraform() {
    echo_env "Initializing Terraform with backend: $BACKEND_CONFIG"
    
    cd "$PROJECT_ROOT/terraform"
    
    terraform init -backend-config="$BACKEND_CONFIG" -reconfigure
    
    echo_info "Terraform initialized."
}

# Deploy infrastructure
deploy_infrastructure() {
    echo_env "Deploying infrastructure..."
    
    cd "$PROJECT_ROOT/terraform"
    
    terraform plan -var-file="$TFVARS_FILE" -out=tfplan
    
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

# Upload frontend files (Vue SPA)
upload_frontend() {
    echo_env "Uploading frontend files..."
    
    cd "$PROJECT_ROOT/terraform"
    
    S3_BUCKET=$(terraform output -raw s3_bucket_name)
    
    if [ -z "$S3_BUCKET" ]; then
        echo_error "Could not get S3 bucket name from Terraform output."
        exit 1
    fi
    
    echo_info "Uploading to bucket: $S3_BUCKET"
    
    # Build Vue frontend
    cd "$PROJECT_ROOT/frontend-vue"
    
    if [ -f "package.json" ]; then
        echo_info "Building Vue frontend..."
        npm install
        npm run build
        
        # Sync Vue dist files
        aws s3 sync "dist" "s3://$S3_BUCKET" \
            --delete \
            --exclude ".DS_Store" \
            --exclude "*.map"
    else
        echo_warn "No package.json found in frontend-vue, uploading static frontend..."
        # Fallback to static frontend
        aws s3 sync "$PROJECT_ROOT/frontend" "s3://$S3_BUCKET" \
            --delete \
            --exclude ".DS_Store" \
            --exclude "*.map"
    fi
    
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
    echo "       Environment: ${ENVIRONMENT^^}"
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
    echo "    Environment: ${ENVIRONMENT^^}"
    echo "======================================"
    echo ""
    
    check_prerequisites
    
    if [ "$FRONTEND_ONLY" = false ] && [ "$SKIP_INFRA" = false ]; then
        install_dependencies
        init_terraform
        deploy_infrastructure
    fi
    
    if [ "$SKIP_FRONTEND" = false ]; then
        # Need to init terraform to get outputs even if skipping infra
        if [ "$SKIP_INFRA" = true ]; then
            init_terraform
        fi
        upload_frontend
        invalidate_cache
    fi
    
    print_info
}

main "$@"
