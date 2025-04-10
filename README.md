# Terraform AWS ECS Cluster with Auto Scaling Group Module

This module creates an Amazon ECS cluster with an Auto Scaling Group (ASG) for EC2 instances.

## Features

- Creates an ECS cluster
- Sets up Auto Scaling Group with EC2 instances
- Configures Launch Template with ECS-optimized AMI
- Creates IAM roles and instance profiles
- Configures capacity providers
- Sets up security groups
- Auto-scaling policies for cluster capacity
- Standardized tagging system

## Usage

```hcl
module "ecs_cluster_asg" {
  source  = "payraydoo/aws-ecs-cluster-asg/terraform"
  version = "0.1.0"

  tag_org        = "payraydoo"
  env            = "dev"
  cluster_name   = "app-cluster"
  
  vpc_id             = module.vpc.id
  private_subnet_ids = module.vpc.private_subnet_ids
  
  # Instance configuration
  instance_type        = "t3.medium"
  min_size             = 1
  max_size             = 5
  desired_capacity     = 1
  
  # Scaling
  target_capacity      = 80
  
  tags = {
    Project     = "payraydoo"
    ManagedBy   = "terraform"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0.0 |
| aws | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| tag_org | Organization tag | `string` | n/a | yes |
| env | Environment (dev, staging, prod) | `string` | n/a | yes |
| cluster_name | Name of the ECS cluster | `string` | n/a | yes |
| vpc_id | VPC ID where resources will be created | `string` | n/a | yes |
| private_subnet_ids | List of private subnet IDs for the instances | `list(string)` | n/a | yes |
| instance_type | EC2 instance type | `string` | `"t3.medium"` | no |
| min_size | Minimum size of the Auto Scaling Group | `number` | `1` | no |
| max_size | Maximum size of the Auto Scaling Group | `number` | `5` | no |
| desired_capacity | Desired capacity of the Auto Scaling Group | `number` | `2` | no |
| target_capacity | Target capacity percentage for auto scaling | `number` | `80` | no |
| ebs_volume_size | Size of the EBS volume in GB | `number` | `30` | no |
| ebs_volume_type | Type of the EBS volume | `string` | `"gp3"` | no |
| associate_public_ip | Whether to associate public IP addresses to instances | `bool` | `false` | no |
| user_data | User data script for EC2 instances | `string` | `""` | no |
| security_group_ids | Additional security group IDs to attach to instances | `list(string)` | `[]` | no |
| tags | Additional tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | The ECS cluster ID |
| cluster_name | The ECS cluster name |
| cluster_arn | The ECS cluster ARN |
| autoscaling_group_name | The name of the Auto Scaling Group |
| autoscaling_group_arn | The ARN of the Auto Scaling Group |
| instance_security_group_id | The security group ID of the ECS instances |
| iam_role_name | The IAM role name for the ECS instances |
| iam_role_arn | The IAM role ARN for the ECS instances |
| capacity_provider_name | The name of the ECS capacity provider |

## Cloudflare Integration

This module doesn't directly handle DNS records. To manage DNS records with Cloudflare, use the Cloudflare provider in your root module:

```hcl
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_record" "ecs_service" {
  zone_id = var.cloudflare_zone_id
  name    = "service"
  value   = module.alb.dns_name # Use with an ALB module
  type    = "CNAME"
  ttl     = 1
  proxied = true
}
```