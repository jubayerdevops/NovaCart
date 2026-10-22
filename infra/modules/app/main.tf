# ================================================================ AMI
# Latest Amazon Linux 2023 (x86_64) published by Amazon
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ================================================================ IAM (SSM, no SSH keys)
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${var.name_prefix}-app-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.name_prefix}-app-profile"
  role = aws_iam_role.app.name
}

# ================================================================ Launch template
resource "aws_launch_template" "app" {
  name_prefix   = "${var.name_prefix}-app-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type

  # No key_name on purpose: access is through SSM Session Manager only
  iam_instance_profile {
    arn = aws_iam_instance_profile.app.arn
  }

  vpc_security_group_ids = [var.app_sg_id]

  # 1-minute CloudWatch metrics so the CPU scaling policy reacts quickly
  monitoring {
    enabled = true
  }

  # IMDSv2 only
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Encrypted root volume
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # replace() strips Windows CRLF line endings so the script runs on Linux
  user_data = base64encode(replace(templatefile("${path.module}/user_data.sh.tftpl", {
    environment = var.environment
    name_prefix = var.name_prefix
  }), "\r\n", "\n"))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.name_prefix}-app" }
  }

  tag_specifications {
    resource_type = "volume"
    tags          = { Name = "${var.name_prefix}-app-root" }
  }

  update_default_version = true
}

# ================================================================ Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name                = "${var.name_prefix}-app-asg"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [var.target_group_arn]

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  # Replace instances that fail the ALB health check, not just EC2 status checks
  health_check_type         = "ELB"
  health_check_grace_period = var.health_check_grace_period

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  # Rolling replacement whenever the launch template changes
  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
      instance_warmup        = var.health_check_grace_period
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-app"
    propagate_at_launch = true
  }

  lifecycle {
    # The scaling policy changes desired_capacity at runtime; don't fight it
    ignore_changes = [desired_capacity]
  }
}

# ================================================================ Scaling policy
resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.name_prefix}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target
  }
}