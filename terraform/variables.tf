variable "aws_profile" {
  description = "AWS CLI profile name (from ~/.aws/credentials or ~/.aws/config for SSO)"
  type        = string
  default     = "default"
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "blog"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "admin_token" {
  description = "Admin token for API authentication"
  type        = string
  sensitive   = true
}

variable "ips" {
  description = "List of IP addresses to whitelist for admin access (CIDR notation, e.g., ['1.2.3.4/32', '5.6.7.8/32'])"
  type        = list(string)
  default     = []
  
  validation {
    condition     = length(var.ips) > 0
    error_message = "At least one IP address must be provided for admin access."
  }
  
  validation {
    condition     = alltrue([for ip in var.ips : can(cidrhost(ip, 0))])
    error_message = "All IP addresses must be in valid CIDR notation (e.g., '1.2.3.4/32')."
  }
}
