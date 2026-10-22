variable "name_prefix" {
  description = "Prefix for resource names, e.g. novacart-dev."
  type        = string
}

variable "vpc_id" {
  description = "VPC for the target group."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets the ALB is placed in (at least 2 AZs)."
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group for the ALB."
  type        = string
}

variable "app_port" {
  description = "Port the app instances listen on."
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Path the ALB requests to decide if an instance is healthy."
  type        = string
  default     = "/health"
}