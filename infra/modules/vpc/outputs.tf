output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "igw_id" {
  description = "ID of the Internet Gateway."
  value       = aws_internet_gateway.this.id
}

output "azs" {
  description = "Availability Zones used."
  value       = local.azs
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ALB, NAT, bastion)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (app servers)."
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "Database subnet IDs (RDS)."
  value       = aws_subnet.database[*].id
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs (1 in dev, 1 per AZ in prod)."
  value       = aws_nat_gateway.this[*].id
}