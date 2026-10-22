output "alb_dns_name" {
  description = "Public DNS name of the ALB (open this in a browser)."
  value       = aws_lb.this.dns_name
}

output "alb_arn" {
  description = "ARN of the ALB."
  value       = aws_lb.this.arn
}

output "alb_zone_id" {
  description = "Hosted zone ID of the ALB (for a Route 53 alias record)."
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "ARN of the app target group (the ASG attaches to this)."
  value       = aws_lb_target_group.app.arn
}