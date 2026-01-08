# CloudFront Module

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "s3_bucket_id" {
  description = "S3 bucket ID"
  type        = string
}

variable "s3_bucket_arn" {
  description = "S3 bucket ARN"
  type        = string
}

variable "s3_bucket_domain_name" {
  description = "S3 bucket regional domain name"
  type        = string
}

variable "api_gateway_url" {
  description = "API Gateway URL"
  type        = string
}

variable "api_gateway_domain" {
  description = "API Gateway domain"
  type        = string
}

variable "waf_acl_arn" {
  description = "WAF Web ACL ARN"
  type        = string
}

# CloudFront Function to handle SPA routing
resource "aws_cloudfront_function" "url_rewrite" {
  name    = "${var.name_prefix}-url-rewrite"
  runtime = "cloudfront-js-2.0"
  comment = "SPA routing - serve index.html for non-file requests"
  publish = true
  code    = <<-EOF
function handler(event) {
    var request = event.request;
    var uri = request.uri;
    
    // Don't rewrite API requests
    if (uri.startsWith('/api/')) {
        return request;
    }
    
    // Don't rewrite requests with file extensions (assets)
    if (uri.includes('.')) {
        return request;
    }
    
    // Rewrite all other requests to index.html for SPA routing
    request.uri = '/index.html';
    
    return request;
}
EOF
}

# Origin Access Control for S3
resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "${var.name_prefix}-s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "${var.name_prefix} distribution"
  price_class         = "PriceClass_100"  # US, Canada, Europe only for cost savings
  web_acl_id          = var.waf_acl_arn
  
  # S3 Origin for static files
  origin {
    domain_name              = var.s3_bucket_domain_name
    origin_id                = "S3Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }
  
  # API Gateway Origin
  origin {
    domain_name = replace(replace(var.api_gateway_url, "https://", ""), "/", "")
    origin_id   = "APIGatewayOrigin"
    
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  
  # Default behavior - S3 static files
  default_cache_behavior {
    target_origin_id       = "S3Origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    
    cache_policy_id          = aws_cloudfront_cache_policy.static.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.static.id
    
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.url_rewrite.arn
    }
  }
  
  # Public API behavior
  ordered_cache_behavior {
    path_pattern           = "/api/public/*"
    target_origin_id       = "APIGatewayOrigin"
    viewer_protocol_policy = "https-only"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    
    cache_policy_id          = aws_cloudfront_cache_policy.api_public.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.api.id
  }
  
  # Admin API behavior - no caching, forward all headers including Authorization
  ordered_cache_behavior {
    path_pattern           = "/api/admin/*"
    target_origin_id       = "APIGatewayOrigin"
    viewer_protocol_policy = "https-only"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    
    # Use legacy cache settings to forward Authorization header
    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type", "Origin", "Access-Control-Request-Method", "Access-Control-Request-Headers"]
      
      cookies {
        forward = "none"
      }
    }
    
    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }
  
  # Note: Custom error responses removed because they interfere with API error responses
  # SPA routing is handled by serving index.html as default
  
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Cache Policy for static assets (24 hours)
resource "aws_cloudfront_cache_policy" "static" {
  name    = "${var.name_prefix}-static-cache"
  comment = "Cache policy for static assets"
  
  min_ttl     = 0
  default_ttl = 86400  # 24 hours
  max_ttl     = 604800 # 7 days
  
  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

# Cache Policy for public API (5 minutes)
resource "aws_cloudfront_cache_policy" "api_public" {
  name    = "${var.name_prefix}-api-public-cache"
  comment = "Cache policy for public API"
  
  min_ttl     = 0
  default_ttl = 300  # 5 minutes
  max_ttl     = 3600 # 1 hour
  
  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "all"
    }
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

# Origin Request Policy for static assets
resource "aws_cloudfront_origin_request_policy" "static" {
  name    = "${var.name_prefix}-static-origin"
  comment = "Origin request policy for S3"
  
  cookies_config {
    cookie_behavior = "none"
  }
  headers_config {
    header_behavior = "none"
  }
  query_strings_config {
    query_string_behavior = "none"
  }
}

# Origin Request Policy for API
resource "aws_cloudfront_origin_request_policy" "api" {
  name    = "${var.name_prefix}-api-origin"
  comment = "Origin request policy for API Gateway"
  
  cookies_config {
    cookie_behavior = "none"
  }
  headers_config {
    header_behavior = "whitelist"
    headers {
      items = ["Content-Type", "Origin", "Access-Control-Request-Method", "Access-Control-Request-Headers"]
    }
  }
  query_strings_config {
    query_string_behavior = "all"
  }
}

output "distribution_id" {
  value = aws_cloudfront_distribution.main.id
}

output "distribution_arn" {
  value = aws_cloudfront_distribution.main.arn
}

output "distribution_domain_name" {
  value = aws_cloudfront_distribution.main.domain_name
}
