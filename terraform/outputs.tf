output "cloudfront_url" {
  description = "CloudFront distribution URL"
  value       = "https://${module.cloudfront.distribution_domain_name}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.cloudfront.distribution_id
}

output "api_gateway_url" {
  description = "API Gateway URL"
  value       = module.api_gateway.api_url
}

output "s3_bucket_name" {
  description = "S3 bucket name for frontend files"
  value       = module.s3.bucket_id
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = module.dynamodb.table_name
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = module.lambda.function_name
}

output "admin_url" {
  description = "Admin panel URL (IP restricted)"
  value       = "https://${module.cloudfront.distribution_domain_name}/admin/"
}

output "whitelisted_ips" {
  description = "IP addresses whitelisted for admin access"
  value       = var.ips
}
