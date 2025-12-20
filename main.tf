# Cost-Optimized EMR Spark Cluster with HDFS on Core Nodes and Spot Task Nodes
resource "aws_emr_cluster" "spark_cluster" {
  name          = var.cluster_name
  release_label = var.emr_release_label
  applications  = ["Spark", "Hadoop", "Hive", "Ganglia"]

  termination_protection            = var.enable_termination_protection
  keep_job_flow_alive_when_no_steps = true
  log_uri                           = var.log_uri

  # Auto-termination policy (optional)
  dynamic "auto_termination_policy" {
    for_each = var.auto_termination_minutes > 0 ? [1] : []
    content {
      idle_timeout = var.auto_termination_minutes * 60
    }
  }

  # EMR service role
  service_role = aws_iam_role.emr_service_role.arn

  # Auto-scaling role for managed scaling
  autoscaling_role = aws_iam_role.emr_autoscaling_role.arn

  ec2_attributes {
    key_name                          = var.key_name
    subnet_id                         = var.subnet_id
    emr_managed_master_security_group = aws_security_group.emr_master.id
    emr_managed_slave_security_group  = aws_security_group.emr_worker.id
    instance_profile                  = aws_iam_instance_profile.emr_ec2_instance_profile.arn
  }

  # Master Instance Group - Single On-Demand node
  master_instance_group {
    name           = "master-group"
    instance_type  = var.master_instance_type
    instance_count = 1

    ebs_config {
      size                 = 100
      type                 = "gp3"
      volumes_per_instance = 1
    }
  }

  # Core Instance Group - Multiple On-Demand nodes with EBS-backed HDFS
  # These nodes store HDFS data and provide reliable, persistent storage
  core_instance_group {
    name           = "core-group"
    instance_type  = var.core_instance_type
    instance_count = var.core_instance_count

    # EBS configuration for HDFS storage
    # Multiple volumes improve HDFS performance and throughput
    ebs_config {
      size                 = var.core_ebs_volume_size
      type                 = "gp3"
      iops                 = 3000
      throughput           = 125
      volumes_per_instance = var.core_ebs_volumes_per_instance
    }

    # Auto-scaling policy for core nodes (optional, typically kept stable)
    autoscaling_policy = jsonencode({
      Constraints = {
        MinCapacity = var.core_instance_count
        MaxCapacity = var.core_instance_count
      }
      Rules = []
    })
  }

  configurations_json = jsonencode([
    {
      Classification = "spark"
      Properties = {
        "maximizeResourceAllocation" = "true"
      }
    },
    {
      Classification = "spark-defaults"
      Properties = {
        "spark.dynamicAllocation.enabled"          = "true"
        "spark.shuffle.service.enabled"            = "true"
        "spark.sql.adaptive.enabled"               = "true"
        "spark.sql.adaptive.coalescePartitions.enabled" = "true"
        "spark.speculation"                        = "true"
        "spark.speculation.quantile"               = "0.9"
        "spark.speculation.multiplier"             = "2"
        "spark.driver.memory"                      = "8g"
        "spark.executor.memory"                    = "8g"
        "spark.executor.cores"                     = "4"
      }
    },
    {
      Classification = "hdfs-site"
      Properties = {
        "dfs.replication"                    = "3"
        "dfs.namenode.handler.count"         = "100"
        "dfs.datanode.handler.count"         = "30"
        "dfs.namenode.checkpoint.period"     = "3600"
        "dfs.namenode.checkpoint.txns"       = "1000000"
        "dfs.datanode.failed.volumes.tolerated" = "1"
      }
    },
    {
      Classification = "yarn-site"
      Properties = {
        "yarn.nodemanager.vmem-check-enabled" = "false"
        "yarn.nodemanager.pmem-check-enabled" = "false"
        "yarn.resourcemanager.am.max-attempts" = "3"
      }
    },
    {
      Classification = "mapred-site"
      Properties = {
        "mapreduce.map.memory.mb"      = "4096"
        "mapreduce.reduce.memory.mb"   = "8192"
        "mapreduce.map.java.opts"      = "-Xmx3276m"
        "mapreduce.reduce.java.opts"   = "-Xmx6553m"
      }
    }
  ])

  tags = merge(
    var.tags,
    {
      Name = var.cluster_name
    }
  )

  # Ensure IAM roles and security groups are created before cluster
  depends_on = [
    aws_iam_role_policy_attachment.emr_service_policy,
    aws_iam_role_policy_attachment.emr_ec2_policy,
    aws_iam_role_policy_attachment.emr_autoscaling_policy,
    aws_security_group.emr_master,
    aws_security_group.emr_worker
  ]
}

# Task Instance Fleet - Spot instances for compute-only workloads
# These nodes do NOT store HDFS data and can be terminated without data loss
resource "aws_emr_instance_fleet" "task_fleet" {
  cluster_id = aws_emr_cluster.spark_cluster.id
  name       = "task-fleet"

  target_on_demand_capacity = 0
  target_spot_capacity      = var.task_instance_min_count

  instance_type_configs {
    instance_type     = var.task_instance_type
    weighted_capacity = 1

    ebs_config {
      size                 = 100
      type                 = "gp3"
      volumes_per_instance = 1
    }
  }

  launch_specifications {
    spot_specification {
      allocation_strategy      = "capacity-optimized"
      timeout_action           = "SWITCH_TO_ON_DEMAND"
      timeout_duration_minutes = 10
      block_duration_minutes   = 0
    }
  }
}

# Managed Scaling Policy for Task Nodes
# Automatically scales task nodes based on YARN memory utilization
resource "aws_emr_managed_scaling_policy" "task_scaling" {
  cluster_id = aws_emr_cluster.spark_cluster.id

  compute_limits {
    unit_type                       = "Instances"
    minimum_capacity_units          = var.task_instance_min_count
    maximum_capacity_units          = var.task_instance_max_count
    maximum_on_demand_capacity_units = 0
    maximum_core_capacity_units     = var.core_instance_count
  }

  depends_on = [aws_emr_instance_fleet.task_fleet]
}
