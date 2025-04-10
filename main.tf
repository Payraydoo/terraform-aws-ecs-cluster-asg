##############################################
# main.tf
##############################################

# Create ECS cluster
resource "aws_ecs_cluster" "this" {
  name = "${var.tag_org}-${var.env}-${var.cluster_name}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(
    {
      Name        = "${var.tag_org}-${var.env}-${var.cluster_name}"
      Environment = var.env
      Organization = var.tag_org
    },
    var.tags
  )
}

# Create IAM role for ECS instances
resource "aws_iam_role" "ecs_instance_role" {
  name = "${var.tag_org}-${var.env}-${var.cluster_name}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = merge(
    {
      Name        = "${var.tag_org}-${var.env}-${var.cluster_name}-instance-role"
      Environment = var.env
      Organization = var.tag_org
    },
    var.tags
  )
}

# Attach policies to the ECS instance role
resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_ssm_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create IAM instance profile
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "${var.tag_org}-${var.env}-${var.cluster_name}-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}

# Create security group for ECS instances
resource "aws_security_group" "ecs_instances" {
  name        = "${var.tag_org}-${var.env}-${var.cluster_name}-sg"
  description = "Security group for ECS instances in cluster ${var.cluster_name}"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name        = "${var.tag_org}-${var.env}-${var.cluster_name}-sg"
      Environment = var.env
      Organization = var.tag_org
    },
    var.tags
  )
}

# Get latest ECS-optimized AMI
data "aws_ami" "ecs_optimized" {
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

# Create user data for ECS instances
locals {
  user_data = var.user_data != "" ? var.user_data : <<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.this.name} >> /etc/ecs/ecs.config
    echo ECS_ENABLE_SPOT_INSTANCE_DRAINING=true >> /etc/ecs/ecs.config
    echo ECS_ENABLE_CONTAINER_METADATA=true >> /etc/ecs/ecs.config
    echo ECS_AVAILABLE_LOGGING_DRIVERS='["json-file","awslogs"]' >> /etc/ecs/ecs.config
    yum update -y
    yum install -y amazon-cloudwatch-agent
    systemctl enable amazon-cloudwatch-agent
    systemctl start amazon-cloudwatch-agent
  EOF
}

# Create launch template for ASG
resource "aws_launch_template" "this" {
  name_prefix   = "${var.tag_org}-${var.env}-${var.cluster_name}-"
  image_id      = data.aws_ami.ecs_optimized.id
  instance_type = var.instance_type
  
  # User data
  user_data = base64encode(local.user_data)
  
  # IAM instance profile
  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }
  
  # Network
  network_interfaces {
    associate_public_ip_address = var.associate_public_ip
    security_groups             = concat([aws_security_group.ecs_instances.id], var.security_group_ids)
    delete_on_termination       = true
  }
  
  # Storage
  block_device_mappings {
    device_name = "/dev/xvda"
    
    ebs {
      volume_size           = var.ebs_volume_size
      volume_type           = var.ebs_volume_type
      delete_on_termination = true
      encrypted             = true
    }
  }
  
  # Metadata options
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 required for security
    http_put_response_hop_limit = 1
  }
  
  # Monitoring
  monitoring {
    enabled = true
  }
  
  # Tagging
  tag_specifications {
    resource_type = "instance"
    
    tags = merge(
      {
        Name        = "${var.tag_org}-${var.env}-${var.cluster_name}-instance"
        Environment = var.env
        Organization = var.tag_org
      },
      var.tags
    )
  }
  
  tag_specifications {
    resource_type = "volume"
    
    tags = merge(
      {
        Name        = "${var.tag_org}-${var.env}-${var.cluster_name}-volume"
        Environment = var.env
        Organization = var.tag_org
      },
      var.tags
    )
  }
  
  tags = merge(
    {
      Name        = "${var.tag_org}-${var.env}-${var.cluster_name}-launch-template"
      Environment = var.env
      Organization = var.tag_org
    },
    var.tags
  )
}

# Create Auto Scaling Group
resource "aws_autoscaling_group" "this" {
  name                = "${var.tag_org}-${var.env}-${var.cluster_name}-asg"
  vpc_zone_identifier = var.private_subnet_ids
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  
  # Launch template
  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }
  
  # Health check
  health_check_type          = "EC2"
  health_check_grace_period  = 300
  
  # Termination policies
  termination_policies       = ["OldestInstance", "Default"]
  
  # Wait for instances to be healthy on scale out
  wait_for_capacity_timeout  = "10m"
  
  # Instance protection
  protect_from_scale_in      = false
  
  # Tags for ASG
  dynamic "tag" {
    for_each = merge(
      {
        Name        = "${var.tag_org}-${var.env}-${var.cluster_name}-instance"
        Environment = var.env
        Organization = var.tag_org
        AmazonECSManaged = ""
      },
      var.tags
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

# Create ECS capacity provider
resource "aws_ecs_capacity_provider" "this" {
  name = "${var.tag_org}-${var.env}-${var.cluster_name}-cp"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.this.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      maximum_scaling_step_size = 10
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = var.target_capacity
    }
  }

  tags = merge(
    {
      Name        = "${var.tag_org}-${var.env}-${var.cluster_name}-cp"
      Environment = var.env
      Organization = var.tag_org
    },
    var.tags
  )
}

# Attach capacity provider to cluster
resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = [aws_ecs_capacity_provider.this.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.this.name
    weight            = 1
    base              = 0
  }
}

# Create scaling policies based on ECS service utilization
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.tag_org}-${var.env}-${var.cluster_name}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.this.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
  policy_type            = "SimpleScaling"
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.tag_org}-${var.env}-${var.cluster_name}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.this.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
  policy_type            = "SimpleScaling"
}