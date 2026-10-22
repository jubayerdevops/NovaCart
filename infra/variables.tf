variable "project_name" {
  description = "Short project name, used as a prefix for resource names."
  type        = string
  default     = "novacart"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project_name))
    error_message = "project_name must be 2-21 chars: lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "environment must be either \"dev\" or \"prod\"."
  }
}

variable "owner" {
  description = "Person or team responsible for these resources (used in tags)."
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-southeast-1"
}

variable "aws_profile" {
  description = "AWS CLI profile for local runs. Leave null in CI (OIDC provides credentials)."
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block, e.g. 10.0.0.0/16."
  }
}

variable "az_count" {
  description = "Number of Availability Zones to use."
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "true = one shared NAT Gateway (dev). false = one NAT per AZ (prod)."
  type        = bool
  default     = true
}

variable "enable_https" {
  description = "Open 443 on the ALB and add an HTTPS listener (bonus)."
  type        = bool
  default     = false
}

variable "enable_bastion" {
  description = "Create a bastion host and its security group."
  type        = bool
  default     = false
}

variable "allowed_ssh_cidr" {
  description = "Your public IP as /32 for bastion SSH. Only used when enable_bastion = true."
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type for the app servers."
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "Minimum number of app instances."
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of app instances."
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "Number of app instances to start with."
  type        = number
  default     = 2
}

variable "cpu_target" {
  description = "Target average CPU % for the scaling policy."
  type        = number
  default     = 50
}