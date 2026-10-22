variable "name_prefix" {
  description = "Prefix for resource names, e.g. novacart-dev."
  type        = string
}

variable "vpc_id" {
  description = "VPC the security groups belong to."
  type        = string
}

variable "app_port" {
  description = "Port the app servers (nginx) listen on."
  type        = number
  default     = 80
}

variable "db_port" {
  description = "MySQL port."
  type        = number
  default     = 3306
}

variable "enable_https" {
  description = "Open 443 on the ALB (HTTPS bonus)."
  type        = bool
  default     = false
}

variable "enable_bastion" {
  description = "Create the bastion SG and allow SSH from it to the app tier."
  type        = bool
  default     = false
}

variable "allowed_ssh_cidr" {
  description = "Your public IP as /32, allowed to SSH to the bastion. Required when enable_bastion = true."
  type        = string
  default     = null

  validation {
    condition     = var.allowed_ssh_cidr == null || (can(cidrhost(var.allowed_ssh_cidr, 0)) && var.allowed_ssh_cidr != "0.0.0.0/0")
    error_message = "allowed_ssh_cidr must be a valid CIDR (ideally your IP /32) and never 0.0.0.0/0."
  }
}