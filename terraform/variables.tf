variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "prod-account"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "cloud-resume"
}

variable "domain_name" {
  description = "Domain name for the website"
  type        = string
  default     = "james-hodson.com"
}