variable "name" {
  description = "Name for the ECS cluster and related resources"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where resources will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs where EC2 instances will be launched"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type for the ECS container instances"
  type        = string
  default     = "t3.medium"
}

variable "ami_id" {
  description = "Custom AMI ID for ECS instances. If not provided, the latest ECS-optimized Amazon Linux 2 AMI will be used."
  type        = string
  default     = ""
}

variable "min_size" {
  description = "Minimum size of the ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum size of the ASG"
  type        = number
  default     = 10
}

variable "desired_capacity" {
  description = "Desired capacity of the ASG"
  type        = number
  default     = 2
}

variable "scaling_metric" {
  description = "Metric to use for auto scaling. Valid values are 'cpu' or 'memory'."
  type        = string
  default     = "cpu"
  validation {
    condition     = contains(["cpu", "memory"], var.scaling_metric)
    error_message = "Valid values for scaling_metric are 'cpu' or 'memory'."
  }
}

variable "scaling_threshold" {
  description = "Threshold percentage for scaling actions"
  type        = number
  default     = 75
  validation {
    condition     = var.scaling_threshold > 0 && var.scaling_threshold <= 100
    error_message = "Scaling threshold must be between 1 and 100 percent."
  }
}

variable "key_name" {
  description = "SSH key name to use for EC2 instances"
  type        = string
  default     = null
}

variable "additional_security_group_ids" {
  description = "List of additional security group IDs to attach to EC2 instances"
  type        = list(string)
  default     = []
}

variable "instance_profile_name" {
  description = "Instance profile name for the EC2 instances. If not provided, a new one will be created."
  type        = string
  default     = null
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring for EC2 instances"
  type        = bool
  default     = true
}

variable "ebs_optimized" {
  description = "Enable EBS optimization for EC2 instances"
  type        = bool
  default     = true
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 30
}

variable "root_volume_type" {
  description = "Type of the root volume (gp2, gp3, io1, etc.)"
  type        = string
  default     = "gp3"
}

variable "tags" {
  description = "Map of tags to apply to all resources"
  type        = map(string)
  default     = {}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "tag_org" {
  description = "Organization name for tagging resources"
  type        = string
}

variable "termination_policies" {
  description = "A list of policies to decide how the instances in the auto scaling group should be terminated"
  type        = list(string)
  default     = ["OldestLaunchTemplate", "OldestInstance"]
}

variable "health_check_grace_period" {
  description = "Time (in seconds) after instance comes into service before checking health"
  type        = number
  default     = 300
}

variable "health_check_type" {
  description = "EC2 or ELB. Controls how health checking is done"
  type        = string
  default     = "EC2"
}

variable "user_data_extra" {
  description = "Additional user data content to add to the default ECS user data script"
  type        = string
  default     = ""
}

variable "scale_up_cooldown" {
  description = "The amount of time, in seconds, between scale up events"
  type        = number
  default     = 300
}

variable "scale_down_cooldown" {
  description = "The amount of time, in seconds, between scale down events"
  type        = number
  default     = 300
}

variable "capacity_provider_enabled" {
  description = "Enable the capacity provider for the ECS cluster"
  type        = bool
  default     = true