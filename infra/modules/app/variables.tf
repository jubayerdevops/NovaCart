variable "name_prefix" {
  description = "Prefix for resource names, e.g. novacart-dev."
  type        = string
}

variable "environment" {
  description = "Environment name shown on the web page (dev/prod)."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the app servers."
  type        = string
  default     = "t3.micro"
}

variable "app_sg_id" {
  description = "Security group for the app instances."
  type        = string
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 8
}

variable "private_subnet_ids" {
  description = "Private subnets the app instances run in."
  type        = list(string)
}

variable "target_group_arn" {
  description = "ALB target group the instances register with."
  type        = string
}

variable "min_size" {
  description = "Minimum number of instances."
  type        = number
}

variable "max_size" {
  description = "Maximum number of instances."
  type        = number
}

variable "desired_capacity" {
  description = "Number of instances to start with."
  type        = number
}

variable "cpu_target" {
  description = "Target average CPU % for scaling."
  type        = number
  default     = 50
}

variable "health_check_grace_period" {
  description = "Seconds to wait after boot before ELB health checks count (user data needs time)."
  type        = number
  default     = 180
}

variable "db_secret_arn" {
  description = "ARN of the DB credentials secret the app may read."
  type        = string
}