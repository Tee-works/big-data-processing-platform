variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "big-data-architecture"
}

variable "cidr_block" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.100.0.0/16"
}

variable "vpc_name" {
  description = "VPC name"
  type        = string
  default     = "big-data-VPC"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"

}

variable "aws_bucket_name" {
  description = "S3 bucket name"
  type        = string
  default     = "big-data-bck"

}

variable "group_name" {
  description = "Name of the IAM group "
  type        = string
  default     = "data-engineers"
}

variable "users" {
  description = "List of users to create"
  type        = list(string)
  default     = []
}


variable "create_access_keys" {
  description = "Whether to create access keys for the users"
  type        = bool
  default     = true
}

variable "password_length" {
  description = "Length of the generated passwords for console access"
  type        = number
  default     = 8
}

variable "password_reset_required" {
  description = "Whether the user should reset their password on first login"
  type        = bool
  default     = true
}

variable "mail_server" {}
variable "mail_port" {}
variable "mail_username" {}
variable "mail_password" {}
variable "mail_use_tls" {
  type    = bool
  default = true
}
