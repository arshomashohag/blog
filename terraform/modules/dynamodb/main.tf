# DynamoDB Module

variable "table_name" {
  description = "Name of the DynamoDB table"
  type        = string
}

resource "aws_dynamodb_table" "blog" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"  # On-demand pricing for cost optimization
  hash_key     = "pk"
  range_key    = "sk"
  
  attribute {
    name = "pk"
    type = "S"
  }
  
  attribute {
    name = "sk"
    type = "S"
  }
  
  attribute {
    name = "status"
    type = "S"
  }
  
  attribute {
    name = "published_at"
    type = "S"
  }
  
  attribute {
    name = "category"
    type = "S"
  }
  
  # GSI for querying by status (PUBLISHED/DRAFT) sorted by published_at
  global_secondary_index {
    name            = "status-publishedAt-index"
    hash_key        = "status"
    range_key       = "published_at"
    projection_type = "ALL"
  }
  
  # GSI for querying by category sorted by published_at
  global_secondary_index {
    name            = "category-publishedAt-index"
    hash_key        = "category"
    range_key       = "published_at"
    projection_type = "ALL"
  }
  
  point_in_time_recovery {
    enabled = true
  }
  
  tags = {
    Name = var.table_name
  }
}

output "table_name" {
  value = aws_dynamodb_table.blog.name
}

output "table_arn" {
  value = aws_dynamodb_table.blog.arn
}
