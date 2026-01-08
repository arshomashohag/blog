# Blog Platform

A serverless blog platform built with:
- **Backend**: Python/Flask with PynamoDB on AWS Lambda
- **Frontend**: Static HTML/CSS/JS with Quill.js editor
- **Infrastructure**: AWS (DynamoDB, Lambda, API Gateway, CloudFront, S3, WAF)
- **IaC**: Terraform

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CloudFront + WAF                                │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  /admin/*       → S3 (IP Whitelisted via WAF)                          ││
│  │  /api/admin/*   → API Gateway → Lambda (IP Whitelisted via WAF)        ││
│  │  /api/public/*  → API Gateway → Lambda (Cached)                        ││
│  │  /*             → S3 Static Website                                     ││
│  └─────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
                    ┌─────────────────────────────────────┐
                    │         DynamoDB (Single Table)     │
                    └─────────────────────────────────────┘
```

## Features

### Public Site
- Home page with latest blog post featured
- All posts listing with category filter
- Individual post pages with clean typography
- Responsive, artistic design

### Admin Panel (IP Restricted)
- Dashboard with post statistics
- Create/Edit/Delete blog posts
- Rich text editor (Quill.js) with:
  - Headers (H1, H2, H3)
  - Bold, italic, underline, strikethrough
  - Text colors and backgrounds
  - Bullet and numbered lists
  - Code blocks and blockquotes
  - Links and images
- Save as draft or publish immediately
- Category management
- Auto-save while editing

### Security
- WAF IP whitelisting for admin access
- Rate limiting (2000 requests/5min per IP)
- AWS Managed Rules (Common + SQLi protection)
- Token-based admin authentication
- HTML sanitization to prevent XSS
- HTTPS only
- S3 bucket fully private (OAC access only)

## Prerequisites

- [Terraform](https://terraform.io/) >= 1.0.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- Python 3.11+
- jq (for deployment scripts)

## Deployment

### 1. Configure Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
aws_region   = "us-east-1"
project_name = "blog"
environment  = "prod"

# Generate a strong random token
admin_token = "your-secure-admin-token-here"

# Your IP addresses for admin access (CIDR notation)
ips = [
  "YOUR_IP_ADDRESS/32",
]
```

### 2. Deploy

```bash
chmod +x scripts/*.sh
./scripts/deploy.sh
```

This will:
1. Install Python dependencies
2. Deploy all AWS infrastructure
3. Upload frontend files to S3
4. Invalidate CloudFront cache

### 3. Access Your Blog

After deployment, you'll see:
- **Public Site**: `https://<cloudfront-domain>/`
- **Admin Panel**: `https://<cloudfront-domain>/admin/`

Login to admin with your configured `admin_token`.

## Development

### Local Backend Development

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Set environment variables
export DYNAMODB_TABLE=local-blog
export ADMIN_TOKEN=dev-token
export AWS_REGION=us-east-1

# Run locally (requires local DynamoDB or AWS access)
python handler.py
```

### Frontend Development

Simply open the HTML files in a browser or use a local server:

```bash
cd frontend
python -m http.server 8080
```

## Updating

### Update Frontend Only

```bash
./scripts/upload-frontend.sh
```

### Update Infrastructure

```bash
cd terraform
terraform plan
terraform apply
```

### Update Lambda Code

Re-run deployment or:

```bash
cd terraform
terraform apply -target=module.lambda
```

## Costs

Estimated monthly cost for low-traffic blog:
- **DynamoDB**: ~$0 (on-demand, pay per request)
- **Lambda**: ~$0 (free tier: 1M requests/month)
- **API Gateway**: ~$0 (free tier: 1M requests/month)
- **CloudFront**: ~$0-1 (free tier: 1TB/month)
- **S3**: ~$0.02 (storage + requests)
- **WAF**: ~$5 (base cost + rules)

**Total**: ~$5-10/month

## Project Structure

```
blog/
├── backend/
│   ├── app/
│   │   ├── __init__.py         # Flask app factory
│   │   ├── models/
│   │   │   └── blog.py         # PynamoDB models
│   │   ├── routes/
│   │   │   ├── public.py       # Public API routes
│   │   │   └── admin.py        # Admin API routes
│   │   └── utils/
│   │       ├── auth.py         # Authentication
│   │       └── sanitizer.py    # HTML sanitization
│   ├── handler.py              # Lambda entry point
│   └── requirements.txt
├── frontend/
│   ├── index.html              # Home page
│   ├── blogs.html              # All posts
│   ├── blog.html               # Single post
│   ├── admin/
│   │   ├── index.html          # Admin dashboard
│   │   ├── editor.html         # Post editor
│   │   └── admin.css
│   ├── css/
│   │   └── style.css
│   └── js/
│       ├── api.js              # API client
│       └── app.js              # Utilities
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── api-gateway/
│       ├── cloudfront/
│       ├── dynamodb/
│       ├── lambda/
│       ├── s3/
│       └── waf/
└── scripts/
    ├── deploy.sh
    ├── upload-frontend.sh
    └── destroy.sh
```

## Cleanup

To destroy all resources:

```bash
./scripts/destroy.sh
```

## License

MIT
