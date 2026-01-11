#!/bin/bash
# Script to create S3 bucket for Terraform state
# Usage: ./create-state-bucket.sh [dev|prod] [--profile <aws-profile>]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Default values
ENVIRONMENT="${1:-dev}"
AWS_PROFILE="devadmin"
REGION="us-east-1"
ACCOUNT_ID=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        dev|prod)
            ENVIRONMENT="$1"
            shift
            ;;
        --profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: ./create-state-bucket.sh [dev|prod] [--profile <aws-profile>]"
            echo ""
            echo "Creates an S3 bucket for Terraform state with:"
            echo "  - Versioning enabled"
            echo "  - Server-side encryption (AES256)"
            echo "  - Public access blocked"
            echo ""
            echo "Options:"
            echo "  dev|prod              Environment (default: dev)"
            echo "  --profile <profile>   AWS profile to use (default: devadmin)"
            echo "  --help, -h            Show this help message"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# Get AWS account ID
echo_info "Getting AWS account ID..."
ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query 'Account' --output text)

if [ -z "$ACCOUNT_ID" ]; then
    echo_error "Failed to get AWS account ID. Check your AWS credentials."
    exit 1
fi

BUCKET_NAME="terraform-state-${ACCOUNT_ID}-${ENVIRONMENT}"

echo ""
echo "======================================"
echo "  CREATE TERRAFORM STATE BUCKET"
echo "======================================"
echo ""
echo "Environment: $ENVIRONMENT"
echo "Bucket Name: $BUCKET_NAME"
echo "Region:      $REGION"
echo "AWS Profile: $AWS_PROFILE"
echo ""

# Check if bucket already exists
if aws s3api head-bucket --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE" 2>/dev/null; then
    echo_warn "Bucket '$BUCKET_NAME' already exists."
    read -p "Do you want to update its configuration? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo_info "Exiting without changes."
        exit 0
    fi
else
    # Create bucket
    echo_info "Creating S3 bucket: $BUCKET_NAME"
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --profile "$AWS_PROFILE"
    else
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION" \
            --profile "$AWS_PROFILE"
    fi
    echo_info "Bucket created successfully."
fi

# Enable versioning
echo_info "Enabling versioning..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled \
    --profile "$AWS_PROFILE"

# Enable server-side encryption
echo_info "Enabling server-side encryption (AES256)..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            },
            "BucketKeyEnabled": true
        }]
    }' \
    --profile "$AWS_PROFILE"

# Block public access
echo_info "Blocking public access..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration '{
        "BlockPublicAcls": true,
        "IgnorePublicAcls": true,
        "BlockPublicPolicy": true,
        "RestrictPublicBuckets": true
    }' \
    --profile "$AWS_PROFILE"

# Add bucket policy to enforce SSL
echo_info "Adding bucket policy to enforce SSL..."
aws s3api put-bucket-policy \
    --bucket "$BUCKET_NAME" \
    --policy "{
        \"Version\": \"2012-10-17\",
        \"Statement\": [{
            \"Sid\": \"EnforceSSL\",
            \"Effect\": \"Deny\",
            \"Principal\": \"*\",
            \"Action\": \"s3:*\",
            \"Resource\": [
                \"arn:aws:s3:::${BUCKET_NAME}\",
                \"arn:aws:s3:::${BUCKET_NAME}/*\"
            ],
            \"Condition\": {
                \"Bool\": {
                    \"aws:SecureTransport\": \"false\"
                }
            }
        }]
    }" \
    --profile "$AWS_PROFILE"

echo ""
echo "======================================"
echo "  BUCKET CREATED SUCCESSFULLY!"
echo "======================================"
echo ""
echo "Bucket: $BUCKET_NAME"
echo ""
echo "Configuration:"
echo "  ✅ Versioning enabled"
echo "  ✅ Server-side encryption (AES256)"
echo "  ✅ Public access blocked"
echo "  ✅ SSL enforced"
echo ""
echo "Use in backend-${ENVIRONMENT}.hcl:"
echo ""
echo "  bucket  = \"$BUCKET_NAME\""
echo "  key     = \"blog/terraform.tfstate\""
echo "  region  = \"$REGION\""
echo "  profile = \"${ENVIRONMENT}\""
echo "  encrypt = true"
echo ""
echo "======================================"
