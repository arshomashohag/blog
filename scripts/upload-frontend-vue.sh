#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FRONTEND_DIR="$PROJECT_DIR/frontend-vue"

# Get S3 bucket and CloudFront distribution from Terraform
cd "$PROJECT_DIR/terraform"
S3_BUCKET=$(terraform output -raw frontend_bucket_name 2>/dev/null || echo "")
CF_DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")

if [ -z "$S3_BUCKET" ] || [ -z "$CF_DISTRIBUTION_ID" ]; then
    echo "Error: Could not get S3 bucket or CloudFront distribution from Terraform"
    exit 1
fi

echo -e "${GREEN}Building Vue frontend...${NC}"
cd "$FRONTEND_DIR"

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}Installing dependencies...${NC}"
    npm install
fi

# Build
npm run build

echo -e "${GREEN}Uploading to S3: $S3_BUCKET${NC}"
aws s3 sync dist/ "s3://$S3_BUCKET" --delete --profile dev

# Set cache headers for HTML files (no cache for SPA routing)
aws s3 cp "s3://$S3_BUCKET/index.html" "s3://$S3_BUCKET/index.html" \
    --metadata-directive REPLACE \
    --cache-control "no-cache, no-store, must-revalidate" \
    --content-type "text/html" \
    --profile dev

# Invalidate CloudFront cache
echo -e "${GREEN}Invalidating CloudFront cache...${NC}"
aws cloudfront create-invalidation \
    --distribution-id "$CF_DISTRIBUTION_ID" \
    --paths "/*" \
    --profile dev \
    --query 'Invalidation.Id' \
    --output text

echo -e "${GREEN}✓ Frontend deployed successfully!${NC}"
echo -e "URL: https://$(terraform output -raw cloudfront_domain_name 2>/dev/null)"
