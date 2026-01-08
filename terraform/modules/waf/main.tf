# WAF Module with IP Whitelisting

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

variable "whitelisted_ips" {
  description = "List of IP addresses to whitelist for admin access (CIDR notation)"
  type        = list(string)
}

# IP Set for admin whitelist
resource "aws_wafv2_ip_set" "admin_whitelist" {
  name               = "${var.name_prefix}-admin-whitelist"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = var.whitelisted_ips
  
  description = "IP addresses allowed to access admin panel"
}

# WAF Web ACL
resource "aws_wafv2_web_acl" "main" {
  name        = "${var.name_prefix}-waf"
  scope       = "CLOUDFRONT"
  description = "WAF for blog with admin IP whitelisting"
  
  default_action {
    allow {}
  }
  
  # Rule 1: Block admin paths unless from whitelisted IP
  rule {
    name     = "admin-ip-restriction"
    priority = 1
    
    action {
      block {}
    }
    
    statement {
      and_statement {
        statement {
          # Match admin paths
          byte_match_statement {
            field_to_match {
              uri_path {}
            }
            positional_constraint = "STARTS_WITH"
            search_string         = "/admin"
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
        
        statement {
          # NOT from whitelisted IP
          not_statement {
            statement {
              ip_set_reference_statement {
                arn = aws_wafv2_ip_set.admin_whitelist.arn
              }
            }
          }
        }
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AdminIPRestriction"
      sampled_requests_enabled   = true
    }
  }
  
  # Rule 2: Block admin API paths unless from whitelisted IP
  rule {
    name     = "admin-api-ip-restriction"
    priority = 2
    
    action {
      block {}
    }
    
    statement {
      and_statement {
        statement {
          # Match admin API paths
          byte_match_statement {
            field_to_match {
              uri_path {}
            }
            positional_constraint = "STARTS_WITH"
            search_string         = "/api/admin"
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
        
        statement {
          # NOT from whitelisted IP
          not_statement {
            statement {
              ip_set_reference_statement {
                arn = aws_wafv2_ip_set.admin_whitelist.arn
              }
            }
          }
        }
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AdminAPIIPRestriction"
      sampled_requests_enabled   = true
    }
  }
  
  # Rule 3: Rate limiting
  rule {
    name     = "rate-limit"
    priority = 3
    
    action {
      block {}
    }
    
    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit"
      sampled_requests_enabled   = true
    }
  }
  
  # Rule 4: AWS Managed Common Rule Set
  rule {
    name     = "aws-common-rules"
    priority = 4
    
    override_action {
      none {}
    }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSCommonRules"
      sampled_requests_enabled   = true
    }
  }
  
  # Rule 5: AWS Managed SQL Injection Rule Set
  rule {
    name     = "aws-sqli-rules"
    priority = 5
    
    override_action {
      none {}
    }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSSQLiRules"
      sampled_requests_enabled   = true
    }
  }
  
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-waf"
    sampled_requests_enabled   = true
  }
}

output "web_acl_arn" {
  value = aws_wafv2_web_acl.main.arn
}

output "web_acl_id" {
  value = aws_wafv2_web_acl.main.id
}
