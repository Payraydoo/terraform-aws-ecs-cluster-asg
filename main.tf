/**
 * # AWS ECS Cluster with Auto Scaling Group
 *
 * This Terraform module creates an ECS cluster with an auto-scaling group of EC2 instances
 * that automatically register with the cluster. The ASG scales based on CPU or Memory reservation.
 */

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
  }
}

#--------------------------
# Locals
#--------------------------

locals {
  # Generate standard tags for resources
  tags = merge(
    {
      Name         = "${var.tag_org_short_name}-${var.environment}-ecs-cluster"
      Environment  = var.environment
      Organization = var.tag_org
    },
    var.tags
  )
  
  # Resource-specific names
  security_group_name = "${var.tag_org_short_name}-${var.environment}-ecs-sg"
  iam_role_name       = "${var.tag_org_short_name}-${var.environment}-ecs-role"
  instance_name       = "${var.tag_org_short_name}-${var.environment}-ecs-instance"
  asg_name            = "${var.tag_org_short_name}-${var.environment}-ecs-asg"
  capacity_provider_name = "${var.tag_org_short_name}-${var.environment}-ecs-cp"
  
  # Scaling metric name
  metric_name = var.scaling_metric == "cpu" ? "CPUReservation" : "MemoryReservation"
}

#--------------------------
# Data Sources
#--------------------------

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# Get the latest ECS-optimized AMI if none is specified
data "aws_ami" "ecs_optimized" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

#--------------------------
# ECS Cluster
#--------------------------

resource "aws_ecs_cluster" "this" {
  name = var.name
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  
  tags = local.tags
}

# Capacity provider for the cluster (connects ASG to ECS cluster)
resource "aws_ecs_capacity_provider" "this" {
  count = var.capacity_provider_enabled ? 1 : 0
  
  name = local.capacity_provider_name
  
  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.this.arn
    managed_termination_protection = "DISABLED"
    
    managed_scaling {
      maximum_scaling_step_size = 10
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = var.scaling_threshold
    }
  }
  
  tags = merge(
    local.tags,
    {
      Name = local.capacity_provider_name
    }
  )
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  count = var.capacity_provider_enabled ? 1 : 0
  
  cluster_name = aws_ecs_cluster.this.name
  
  capacity_providers = [
    aws_ecs_capacity_provider.this[0].name
  ]
  
  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.this[0].name
    weight            = 100
    base              = 1
  }
}

#--------------------------
# IAM Roles and Policies
#--------------------------

resource "aws_iam_role" "ecs_instance_role" {
  count = var.instance_profile_name == null ? 1 : 0
  
  name = local.iam_role_name
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role" {
  count = var.instance_profile_name == null ? 1 : 0
  
  role       = aws_iam_role.ecs_instance_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_ssm" {
  count = var.instance_profile_name == null ? 1 : 0
  
  role       = aws_iam_role.ecs_instance_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  count = var.instance_profile_name == null ? 1 : 0
  
  name = "${var.tag_org_short_name}-${var.environment}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role[0].name
}

#--------------------------
# Security Group
#--------------------------

resource "aws_security_group" "ecs_instance_sg" {
  name        = local.security_group_name
  description = "Security group for ECS instances in ${var.name} cluster"
  vpc_id      = var.vpc_id
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = local.tags
}

#--------------------------
# Auto Scaling Group
#--------------------------

resource "aws_launch_template" "this" {
  name_prefix            = "${var.tag_org_short_name}-${var.environment}-ecs-"
  image_id               = var.ami_id != "" ? var.ami_id : data.aws_ami.ecs_optimized[0].id
  instance_type          = var.instance_type
  key_name               = var.key_name
  ebs_optimized          = var.ebs_optimized
  vpc_security_group_ids = concat([aws_security_group.ecs_instance_sg.id], var.additional_security_group_ids)
  
  iam_instance_profile {
    name = var.instance_profile_name != null ? var.instance_profile_name : aws_iam_instance_profile.ecs_instance_profile[0].name
  }
  
  monitoring {
    enabled = var.enable_monitoring
  }
  
  block_device_mappings {
    device_name = "/dev/xvda"
    
    ebs {
      volume_size           = var.root_volume_size
      volume_type           = var.root_volume_type
      delete_on_termination = true
      encrypted             = true
    }
  }
  
  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo "ECS_CLUSTER=${aws_ecs_cluster.this.name}" >> /etc/ecs/ecs.config
    echo "ECS_ENABLE_CONTAINER_METADATA=true" >> /etc/ecs/ecs.config
    echo "ECS_AVAILABLE_LOGGING_DRIVERS=[\"json-file\",\"awslogs\"]" >> /etc/ecs/ecs.config
    ${var.user_data_extra}
  EOF
  )
  
  tag_specifications {
    resource_type = "instance"
    tags = local.tags
  }
  
  tag_specifications {
    resource_type = "volume"
    tags = local.tags
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "this" {
  name                      = local.asg_name
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = var.subnet_ids
  health_check_grace_period = var.health_check_grace_period
  health_check_type         = var.health_check_type
  termination_policies      = var.termination_policies
  
  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }
  
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }
  
  dynamic "tag" {
    for_each = merge(
      local.tags,
      {
        AmazonECSManaged = ""
      }
    )
    
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

#--------------------------
# CloudWatch Alarms and Auto Scaling Policies
#--------------------------

resource "aws_cloudwatch_metric_alarm" "high_reservation" {
  alarm_name          = "${var.tag_org_short_name}-${var.environment}-high-${var.scaling_metric}-reservation"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = local.metric_name
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.scaling_threshold
  alarm_description   = "This metric monitors ECS cluster ${var.scaling_metric} reservation"
  
  dimensions = {
    ClusterName = aws_ecs_cluster.this.name
  }
  
  alarm_actions = [aws_autoscaling_policy.scale_up.arn]
}

resource "aws_cloudwatch_metric_alarm" "low_reservation" {
  alarm_name          = "${var.tag_org_short_name}-${var.environment}-low-${var.scaling_metric}-reservation"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = local.metric_name
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.scaling_threshold / 2  # Scale down at 50% of the scale up threshold
  alarm_description   = "This metric monitors ECS cluster ${var.scaling_metric} reservation"
  
  dimensions = {
    ClusterName = aws_ecs_cluster.this.name
  }
  
  alarm_actions = [aws_autoscaling_policy.scale_down.arn]
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.tag_org_short_name}-${var.environment}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.this.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = var.scale_up_cooldown
  policy_type            = "SimpleScaling"
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.tag_org_short_name}-${var.environment}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.this.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = var.scale_down_cooldown
  policy_type            = "SimpleScaling"
}