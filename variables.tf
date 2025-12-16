variable "aws_region" {
  description = "AWS region for EMR cluster deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "production"
}

variable "cluster_name" {
  description = "Name of the EMR cluster"
  type        = string
  default     = "spark-cost-optimized-cluster"
}

variable "emr_release_label" {
  description = "EMR release version"
  type        = string
  default     = "emr-6.15.0"
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for EMR cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for security group configuration"
  type        = string
}

variable "master_instance_type" {
  description = "Instance type for master node"
  type        = string
  default     = "m5.xlarge"
}

variable "core_instance_type" {
  description = "Instance type for core nodes"
  type        = string
  default     = "r5.2xlarge"
}

variable "core_instance_count" {
  description = "Number of core nodes (minimum 3 for HDFS reliability)"
  type        = number
  default     = 3
}

variable "core_ebs_volume_size" {
  description = "EBS volume size in GB for core nodes (HDFS storage)"
  type        = number
  default     = 500
}

variable "core_ebs_volumes_per_instance" {
  description = "Number of EBS volumes per core instance for better HDFS performance"
  type        = number
  default     = 2
}

variable "task_instance_type" {
  description = "Instance type for task nodes (Spot instances)"
  type        = string
  default     = "r5.xlarge"
}

variable "task_instance_min_count" {
  description = "Minimum number of task nodes for auto-scaling"
  type        = number
  default     = 10
}

variable "task_instance_max_count" {
  description = "Maximum number of task nodes for auto-scaling"
  type        = number
  default     = 50
}

variable "task_bid_price" {
  description = "Maximum bid price for Spot task instances (as percentage of On-Demand price). Leave empty for default Spot pricing."
  type        = string
  default     = ""
}

variable "log_uri" {
  description = "S3 URI for EMR logs (e.g., s3://my-bucket/emr-logs/)"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access EMR cluster"
  type        = list(string)
  default     = []
}

variable "enable_termination_protection" {
  description = "Enable termination protection for the EMR cluster"
  type        = bool
  default     = false
}

variable "enable_ebs_encryption" {
  description = "Enable EBS encryption for core node volumes"
  type        = bool
  default     = true
}

variable "auto_termination_minutes" {
  description = "Auto-terminate cluster after specified idle minutes (0 to disable)"
  type        = number
  default     = 0
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
