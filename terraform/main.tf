terraform {
  required_version = ">= 1.0.0"
  
  # Backend configured via -backend-config flag
  # Use: terraform init -backend-config=backend-dev.hcl (or backend-prod.hcl)
  backend "s3" {}
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# For CloudFront ACM certificate (must be in us-east-1)
provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = var.aws_profile
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Random suffix for unique naming
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  suffix      = random_id.suffix.hex
}

# DynamoDB Table
module "dynamodb" {
  source = "./modules/dynamodb"
  
  table_name = "${local.name_prefix}-table-${local.suffix}"
}

# S3 Bucket for Frontend
module "s3" {
  source = "./modules/s3"
  
  bucket_name = "${local.name_prefix}-frontend-${local.suffix}"
}

# Lambda Function
module "lambda" {
  source = "./modules/lambda"
  
  function_name     = "${local.name_prefix}-api-${local.suffix}"
  dynamodb_table    = module.dynamodb.table_name
  dynamodb_table_arn = module.dynamodb.table_arn
  admin_token       = var.admin_token
  aws_region        = var.aws_region
}

# API Gateway
module "api_gateway" {
  source = "./modules/api-gateway"
  
  api_name              = "${local.name_prefix}-api-${local.suffix}"
  lambda_function_name  = module.lambda.function_name
  lambda_function_arn   = module.lambda.function_arn
  lambda_invoke_arn     = module.lambda.invoke_arn
  aws_region            = var.aws_region
}

# WAF with IP Whitelisting
module "waf" {
  source = "./modules/waf"
  
  providers = {
    aws = aws.us_east_1
  }
  
  name_prefix    = local.name_prefix
  whitelisted_ips = var.ips
}

# CloudFront Distribution
module "cloudfront" {
  source = "./modules/cloudfront"
  
  providers = {
    aws = aws.us_east_1
  }
  
  name_prefix           = local.name_prefix
  s3_bucket_id          = module.s3.bucket_id
  s3_bucket_arn         = module.s3.bucket_arn
  s3_bucket_domain_name = module.s3.bucket_regional_domain_name
  api_gateway_url       = module.api_gateway.api_url
  api_gateway_domain    = module.api_gateway.api_domain
  waf_acl_arn           = module.waf.web_acl_arn
}

# Update S3 bucket policy after CloudFront OAC is created
resource "aws_s3_bucket_policy" "frontend" {
  bucket = module.s3.bucket_id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontOAC"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action    = "s3:GetObject"
        Resource  = "${module.s3.bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = module.cloudfront.distribution_arn
          }
        }
      }
    ]
  })
}
