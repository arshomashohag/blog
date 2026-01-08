#!/bin/bash
# Script to destroy all infrastructure

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT/terraform"

echo "WARNING: This will destroy all blog infrastructure!"
echo ""
read -p "Are you sure? Type 'yes' to confirm: " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

# Empty S3 bucket first (required before deletion)
S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")

if [ -n "$S3_BUCKET" ]; then
    echo "Emptying S3 bucket: $S3_BUCKET"
    aws s3 rm "s3://$S3_BUCKET" --recursive || true
    
    # Also delete versions if versioning is enabled
    aws s3api delete-objects \
        --bucket "$S3_BUCKET" \
        --delete "$(aws s3api list-object-versions --bucket "$S3_BUCKET" --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" 2>/dev/null || true
fi

echo "Destroying infrastructure..."
terraform destroy

echo "Infrastructure destroyed."
