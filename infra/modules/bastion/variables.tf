variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet for the bastion."
  type        = string
}

variable "bastion_sg_id" {
  description = "Security group for the bastion (SSH from allowed_ssh_cidr only)."
  type        = string
}

variable "instance_type" {
  description = "Bastion instance type."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Existing EC2 key pair name for SSH."
  type        = string
  default     = null
}