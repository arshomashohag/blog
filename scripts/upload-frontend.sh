#!/bin/bash
# Script to upload frontend files to S3

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT/terraform"

S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null)

if [ -z "$S3_BUCKET" ]; then
    echo "Error: Could not get S3 bucket name. Make sure Terraform has been applied."
    exit 1
fi

echo "Uploading frontend files to s3://$S3_BUCKET..."

aws s3 sync "$PROJECT_ROOT/frontend" "s3://$S3_BUCKET" \
    --delete \
    --exclude ".DS_Store" \
    --exclude "*.map"

echo "Upload complete!"

# Invalidate CloudFront cache
DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null)

if [ -n "$DISTRIBUTION_ID" ]; then
    echo "Invalidating CloudFront cache..."
    aws cloudfront create-invalidation \
        --distribution-id "$DISTRIBUTION_ID" \
        --paths "/*"
    echo "Cache invalidation initiated."
fi

echo ""
echo "Site URL: $(terraform output -raw cloudfront_url)"
