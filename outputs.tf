output "cluster_id" {
  description = "The ID of the EMR cluster"
  value       = aws_emr_cluster.spark_cluster.id
}

output "cluster_name" {
  description = "The name of the EMR cluster"
  value       = aws_emr_cluster.spark_cluster.name
}

output "cluster_master_public_dns" {
  description = "The public DNS name of the master node"
  value       = aws_emr_cluster.spark_cluster.master_public_dns
}

output "cluster_arn" {
  description = "The ARN of the EMR cluster"
  value       = aws_emr_cluster.spark_cluster.arn
}

output "cluster_release_label" {
  description = "The EMR release label"
  value       = aws_emr_cluster.spark_cluster.release_label
}

output "master_security_group_id" {
  description = "Security group ID for the master node"
  value       = aws_security_group.emr_master.id
}

output "worker_security_group_id" {
  description = "Security group ID for the worker nodes"
  value       = aws_security_group.emr_worker.id
}

output "emr_service_role_arn" {
  description = "ARN of the EMR service role"
  value       = aws_iam_role.emr_service_role.arn
}

output "emr_ec2_role_arn" {
  description = "ARN of the EMR EC2 instance role"
  value       = aws_iam_role.emr_ec2_role.arn
}

output "emr_autoscaling_role_arn" {
  description = "ARN of the EMR autoscaling role"
  value       = aws_iam_role.emr_autoscaling_role.arn
}

output "task_fleet_id" {
  description = "The ID of the task instance fleet"
  value       = aws_emr_instance_fleet.task_fleet.id
}

output "core_instance_count" {
  description = "Number of core instances configured"
  value       = var.core_instance_count
}

output "task_instance_min_count" {
  description = "Minimum number of task instances for auto-scaling"
  value       = var.task_instance_min_count
}

output "task_instance_max_count" {
  description = "Maximum number of task instances for auto-scaling"
  value       = var.task_instance_max_count
}

output "log_uri" {
  description = "S3 URI where cluster logs are stored"
  value       = var.log_uri
}
