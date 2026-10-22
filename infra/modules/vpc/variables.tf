variable "name_prefix" {
  description = "Prefix for resource Name tags, e.g. novacart-dev."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "az_count" {
  description = "Number of Availability Zones to spread subnets across."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3 (high availability needs at least 2)."
  }
}

variable "single_nat_gateway" {
  description = "true = one shared NAT Gateway (cheap, dev). false = one NAT per AZ (highly available, prod)."
  type        = bool
  default     = true
}