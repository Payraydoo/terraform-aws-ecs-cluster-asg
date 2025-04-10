# Terraform AWS ECS Cluster with Auto Scaling Group

This Terraform module creates an ECS cluster with an auto-scaling group of EC2 instances that automatically register with the cluster. The ASG scales based on CPU or Memory reservation metrics.

## Features

- Creates an ECS cluster
- Sets up an Auto Scaling Group with EC2 instances that automatically join the ECS cluster
- Configures scaling policies based on CPU or Memory reservation
- Supports custom AMI selection
- Supports custom instance types
- Configures necessary IAM roles and policies
- Provides customizable security groups
- Includes capacity provider integration

## Usage

```hcl
module "ecs_cluster_with_asg" {
  source  = "username/ecs-cluster-asg/aws"
  version = "1.0.0"

  name                = "my-ecs-cluster"
  vpc_id              = "vpc-123456"
  subnet_ids          = ["subnet-123456", "subnet-654321"]
  instance_type       = "t3.medium"
  min_size            = 1
  max_size            = 10
  desired_capacity    = 2
  
  # Environment and organization tagging
  environment         = "dev"
  tag_org_short_name  = "acme"
  
  # Additional custom tags
  tags = {
    Project     = "Example"
    CostCenter  = "Platform"
  }
  
  scaling_metric      = "cpu" # or "memory"
  scaling_threshold   = 75    # percentage
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0.0 |
| aws | >= 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 4.0.0 |

## Resources

| Name | Type |
|------|------|
| aws_ecs_cluster.this | resource |
| aws_ecs_capacity_provider.this | resource |
| aws_ecs_cluster_capacity_providers.this | resource |
| aws_iam_role.ecs_instance_role | resource |
| aws_iam_role_policy_attachment.ecs_instance_role | resource |
| aws_iam_role_policy_attachment.ecs_instance_ssm | resource |
| aws_iam_instance_profile.ecs_instance_profile | resource |
| aws_security_group.ecs_instance_sg | resource |
| aws_launch_template.this | resource |
| aws_autoscaling_group.this | resource |
| aws_cloudwatch_metric_alarm.high_reservation | resource |
| aws_cloudwatch_metric_alarm.low_reservation | resource |
| aws_autoscaling_policy.scale_up | resource |
| aws_autoscaling_policy.scale_down | resource |
| aws_ami.ecs_optimized | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name for the ECS cluster and related resources | `string` | n/a | yes |
| vpc_id | ID of the VPC where resources will be created | `string` | n/a | yes |
| subnet_ids | List of subnet IDs where EC2 instances will be launched | `list(string)` | n/a | yes |
| instance_type | EC2 instance type for the ECS container instances | `string` | `"t3.medium"` | no |
| ami_id | Custom AMI ID for ECS instances. If not provided, the latest ECS-optimized Amazon Linux 2 AMI will be used. | `string` | `""` | no |
| min_size | Minimum size of the ASG | `number` | `1` | no |
| max_size | Maximum size of the ASG | `number` | `10` | no |
| desired_capacity | Desired capacity of the ASG | `number` | `2` | no |
| scaling_metric | Metric to use for auto scaling. Valid values are 'cpu' or 'memory'. | `string` | `"cpu"` | no |
| scaling_threshold | Threshold percentage for scaling actions | `number` | `75` | no |
| key_name | SSH key name to use for EC2 instances | `string` | `null` | no |
| additional_security_group_ids | List of additional security group IDs to attach to EC2 instances | `list(string)` | `[]` | no |
| instance_profile_name | Instance profile name for the EC2 instances. If not provided, a new one will be created. | `string` | `null` | no |
| enable_monitoring | Enable detailed monitoring for EC2 instances | `bool` | `true` | no |
| ebs_optimized | Enable EBS optimization for EC2 instances | `bool` | `true` | no |
| root_volume_size | Size of the root volume in GB | `number` | `30` | no |
| root_volume_type | Type of the root volume (gp2, gp3, io1, etc.) | `string` | `"gp3"` | no |
| tags | Map of tags to apply to all resources | `map(string)` | `{}` | no |
| termination_policies | A list of policies to decide how the instances in the auto scaling group should be terminated | `list(string)` | `["OldestLaunchTemplate", "OldestInstance"]` | no |
| health_check_grace_period | Time (in seconds) after instance comes into service before checking health | `number` | `300` | no |
| health_check_type | EC2 or ELB. Controls how health checking is done | `string` | `"EC2"` | no |
| user_data_extra | Additional user data content to add to the default ECS user data script | `string` | `""` | no |
| scale_up_cooldown | The amount of time, in seconds, between scale up events | `number` | `300` | no |
| scale_down_cooldown | The amount of time, in seconds, between scale down events | `number` | `300` | no |
| capacity_provider_enabled | Enable the capacity provider for the ECS cluster | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | The ID of the ECS cluster |
| cluster_name | The name of the ECS cluster |
| cluster_arn | The ARN of the ECS cluster |
| autoscaling_group_id | The ID of the Auto Scaling Group |
| autoscaling_group_name | The name of the Auto Scaling Group |
| autoscaling_group_arn | The ARN of the Auto Scaling Group |
| security_group_id | The ID of the security group created for the ECS instances |
| launch_template_id | The ID of the launch template |
| launch_template_arn | The ARN of the launch template |
| capacity_provider_name | The name of the ECS capacity provider |
| iam_role_arn | The ARN of the IAM role used by the ECS instances |
| iam_instance_profile_arn | The ARN of the IAM instance profile used by the ECS instances |
| iam_instance_profile_name | The name of the IAM instance profile used by the ECS instances |

## License

MIT Licensed. See LICENSE for full details.


provider "aws" {
  region = "us-west-2"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = "ecs-cluster-example-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = "example"
    Terraform   = "true"
  }
  
  ecs_cluster_tags = {
    ResourceType = "ECSCluster"
  }
  
  security_group_tags = {
    ResourceType = "SecurityGroup"
  }
  
  instance_tags = {
    ResourceType = "EC2Instance"
  }
  
  asg_tags = {
    ResourceType = "AutoScalingGroup"
  }
}

module "ecs_cluster_with_asg" {
  source = "../../"

  name          = "example-ecs-cluster"
  vpc_id        = module.vpc.vpc_id
  subnet_ids    = module.vpc.private_subnets
  instance_type = "t3.medium"

  min_size         = 2
  max_size         = 10
  desired_capacity = 2
  
  # Environment and organization tagging
  environment      = "dev"
  tag_org          = "acme"
  
  scaling_metric    = "cpu"  # can also be "memory"
  scaling_threshold = 75
  
  # Optional parameters
  key_name            = null
  enable_monitoring   = true
  ebs_optimized       = true
  root_volume_size    = 30
  root_volume_type    = "gp3"
  
  tags = {
    Environment = "example"
    Terraform   = "true"
  }
  
  # Additional user data if needed
  user_data_extra = <<-EOT
    # Additional configuration can be added here
    echo "ECS_INSTANCE_ATTRIBUTES={\"stack\":\"example\"}" >> /etc/ecs/ecs.config
  EOT
}

# Example service - nginx on the ECS cluster
resource "aws_ecs_task_definition" "nginx" {
  family                   = "nginx"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  
  container_definitions = jsonencode([
    {
      name      = "nginx"
      image     = "nginx:latest"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 0
          protocol      = "tcp"
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "nginx" {
  name            = "nginx"
  cluster         = module.ecs_cluster_with_asg.cluster_id
  task_definition = aws_ecs_task_definition.nginx.arn
  desired_count   = 2
  
  # Optional: Deploy new tasks before killing old ones
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  
  # For demonstration, no load balancer attached
  # In a real scenario, you would likely use a load balancer
}