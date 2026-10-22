# ---------------------------------------------------------------- Load balancer
resource "aws_lb" "this" {
  name               = "${var.name_prefix}-alb"
  load_balancer_type = "application"
  internal           = false # internet-facing
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  drop_invalid_header_fields = true # reject malformed HTTP headers (security best practice)

  tags = { Name = "${var.name_prefix}-alb" }
}

# ---------------------------------------------------------------- Target group
resource "aws_lb_target_group" "app" {
  name        = "${var.name_prefix}-app-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  # How long to keep sending in-flight requests to an instance being removed
  deregistration_delay = 30

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15 # check every 15 seconds
    timeout             = 5
    healthy_threshold   = 2 # 2 passes in a row  -> healthy
    unhealthy_threshold = 3 # 3 fails in a row   -> unhealthy
  }

  tags = { Name = "${var.name_prefix}-app-tg" }
}

# ---------------------------------------------------------------- Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}