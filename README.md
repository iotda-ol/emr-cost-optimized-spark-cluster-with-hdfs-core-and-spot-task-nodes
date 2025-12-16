# Cost-Optimized Amazon EMR Spark Cluster with HDFS Core and Spot Task Nodes

This repository demonstrates a cost-optimized Amazon EMR cluster design for large-scale Spark workloads. It uses On-Demand master and core nodes with EBS-backed HDFS for reliability, and auto-scaling Spot task nodes for variable compute demand. The architecture balances performance, fault tolerance, and cost, aligned with AWS DEA-C01 best practices.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Cost Optimization Strategy](#cost-optimization-strategy)
- [HDFS Reliability Design](#hdfs-reliability-design)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Monitoring](#monitoring)
- [Cost Estimation](#cost-estimation)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Architecture Overview

This Terraform configuration provisions a production-ready Amazon EMR cluster with the following architecture:

```
┌─────────────────────────────────────────────────────────────────┐
│                    EMR Cluster Architecture                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Master Node (On-Demand)                                        │
│  ┌────────────────────────────────────┐                         │
│  │  m5.xlarge (1x)                    │                         │
│  │  - YARN ResourceManager            │                         │
│  │  - HDFS NameNode                   │                         │
│  │  - Spark Master                    │                         │
│  │  - EBS: 100GB gp3                  │                         │
│  └────────────────────────────────────┘                         │
│                    │                                             │
│         ┌──────────┴──────────┐                                 │
│         │                     │                                 │
│  ┌──────▼──────┐      ┌──────▼──────────────────────┐          │
│  │             │      │                              │          │
│  │ Core Nodes  │      │     Task Nodes (Spot)        │          │
│  │ (On-Demand) │      │                              │          │
│  │             │      │  Auto-Scaling: 10-50 nodes   │          │
│  │ r5.2xlarge  │      │  r5.xlarge                   │          │
│  │ (3+ nodes)  │      │                              │          │
│  │             │      │  - Compute-only workloads    │          │
│  │ - HDFS      │      │  - No HDFS data storage      │          │
│  │   DataNodes │      │  - Ephemeral storage         │          │
│  │ - YARN      │      │  - Capacity-optimized        │          │
│  │   NodeMgr   │      │  - Fallback to On-Demand     │          │
│  │ - Spark     │      │                              │          │
│  │   Executor  │      │  EBS: 100GB gp3              │          │
│  │             │      │  (per node)                  │          │
│  │ EBS Storage │      │                              │          │
│  │ - 2 volumes │      └──────────────────────────────┘          │
│  │ - 500GB ea. │                                                │
│  │ - gp3 IOPS  │                                                │
│  │ - Encrypted │                                                │
│  │             │                                                │
│  │ Replication │                                                │
│  │ Factor: 3   │                                                │
│  └─────────────┘                                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Components

1. **Master Node (1x m5.xlarge, On-Demand)**
   - Runs cluster management services (YARN ResourceManager, HDFS NameNode)
   - Single point of coordination - must be reliable (On-Demand)
   - No HDFS data storage on master

2. **Core Nodes (3+ r5.2xlarge, On-Demand)**
   - Store HDFS data with 3x replication
   - Run YARN NodeManagers and Spark executors
   - EBS-backed storage (2x 500GB gp3 volumes per node)
   - Provides reliable, persistent storage for datasets
   - Minimum 3 nodes for HDFS reliability (default replication factor)

3. **Task Nodes (10-50 r5.xlarge, Spot)**
   - Compute-only workload processing
   - No HDFS data storage (stateless)
   - Auto-scales based on YARN memory utilization
   - Spot instances with capacity-optimized allocation
   - Can be terminated without data loss

## Cost Optimization Strategy

This architecture achieves significant cost savings through strategic use of Spot instances and right-sizing:

### 1. **Spot Instance Utilization for Task Nodes**

**Why It Works:**
- Task nodes don't store HDFS data, making them stateless
- Spot interruptions don't cause data loss
- Spark's speculation and dynamic allocation handle task failures gracefully
- Capacity-optimized allocation strategy minimizes interruption rate

**Cost Savings:**
- Spot instances typically cost 70-90% less than On-Demand
- Example: r5.xlarge Spot ~$0.075/hr vs On-Demand ~$0.252/hr
- With 40 task nodes, monthly savings: ~$5,664 (vs On-Demand)

### 2. **On-Demand Core Nodes for HDFS Reliability**

**Why It's Necessary:**
- Core nodes store HDFS data with 3x replication
- Termination causes data re-replication overhead
- On-Demand ensures stable storage layer
- Small core cluster (3-5 nodes) keeps costs manageable

**Cost Justification:**
- Only 4 On-Demand instances (1 master + 3 core) vs 50+ total cluster capacity
- Core nodes represent ~10% of total compute capacity
- Prevents expensive data re-replication operations
- Ensures data durability and availability

### 3. **Auto-Scaling for Variable Workloads**

**How It Optimizes Cost:**
- Scales task nodes from 10 to 50 based on demand
- Reduces capacity during idle periods
- Managed scaling policy automatically adjusts based on YARN metrics
- No manual intervention required

**Cost Impact:**
- Minimum configuration (4 On-Demand + 10 Spot): ~$600/month
- Maximum configuration (4 On-Demand + 50 Spot): ~$1,200/month
- Dynamically adjusts to actual workload needs

### 4. **Right-Sized Instance Types**

**Instance Selection Rationale:**
- **Master (m5.xlarge):** Balanced compute/memory for cluster management
- **Core (r5.2xlarge):** Memory-optimized for HDFS caching and Spark executors
- **Task (r5.xlarge):** Cost-effective compute with sufficient memory

**Cost Efficiency:**
- Larger core instances = fewer nodes for same storage = lower HDFS overhead
- Smaller task instances = more flexibility in Spot markets

### 5. **EBS gp3 Optimization**

**Storage Cost Savings:**
- gp3 volumes: ~20% cheaper than gp2
- Configurable IOPS and throughput without volume size increase
- 3000 IOPS and 125 MB/s included (sufficient for most workloads)

**Example:**
- 3 core nodes × 2 volumes × 500GB = 3TB storage
- gp3: ~$240/month vs gp2: ~$300/month
- Savings: ~$60/month on storage alone

### Total Cost Comparison

**Traditional All-On-Demand Approach:**
- 1 master + 3 core + 40 task (all On-Demand) = 44 nodes
- Estimated cost: ~$6,500/month

**This Cost-Optimized Approach:**
- 1 master + 3 core (On-Demand) + 40 task (Spot) = 44 nodes
- Estimated cost: ~$1,200/month
- **Savings: ~$5,300/month (81% reduction)**

## HDFS Reliability Design

### Why Core Nodes Must Be On-Demand

HDFS (Hadoop Distributed File System) requires reliable storage nodes to maintain data integrity and availability. Here's why core nodes MUST use On-Demand instances:

#### 1. **Data Replication and Re-replication**

**The Problem:**
- HDFS replicates data blocks across DataNodes (default: 3x replication)
- When a DataNode fails, HDFS initiates re-replication to maintain replication factor
- Re-replication is network and I/O intensive

**With Spot Core Nodes (BAD):**
- Frequent Spot interruptions trigger constant re-replication
- Network saturation during re-replication
- Increased NameNode load tracking block locations
- Risk of data loss if multiple nodes fail simultaneously (under-replication)

**With On-Demand Core Nodes (GOOD):**
- Stable DataNodes minimize re-replication overhead
- Predictable cluster capacity for HDFS
- NameNode stability and performance

#### 2. **HDFS Block Placement and Rack Awareness**

**Why It Matters:**
- HDFS places replicas across different nodes/racks
- Spot interruptions can violate placement policies
- Improper block distribution impacts read performance

**This Configuration:**
- Stable core nodes ensure consistent block placement
- Optimal data locality for Spark jobs
- Predictable read performance

#### 3. **Minimum Replication Requirements**

**HDFS Configuration:**
```hcl
"dfs.replication" = "3"  # Default replication factor
```

**Why 3 Core Nodes Minimum:**
- Satisfies 3x replication requirement
- Tolerates single node failure without under-replication
- Maintains quorum for HDFS operations
- Best practice: Use 3+ core nodes for production

#### 4. **Task Nodes Don't Store HDFS Data**

**Key Distinction:**
- Task nodes run YARN NodeManager only
- No HDFS DataNode service on task nodes
- Temporary/shuffle data only (lost on termination is acceptable)
- Spark can re-compute lost shuffle partitions

**Why This Enables Spot:**
- Spot interruptions don't affect persistent data
- Task failures handled by Spark's speculation
- Zero data re-replication overhead
- Cost-effective compute scaling

### HDFS Configuration Details

#### EBS Volume Configuration

```hcl
core_ebs_volume_size         = 500   # GB per volume
core_ebs_volumes_per_instance = 2     # Multiple volumes per node
```

**Benefits:**
- Multiple volumes improve HDFS throughput (parallel I/O)
- Each volume = separate HDFS data directory
- Better disk utilization and performance
- Easier capacity expansion

#### EBS gp3 Performance

```hcl
type       = "gp3"
iops       = 3000        # Provisioned IOPS
throughput = 125         # MB/s
```

**Performance Characteristics:**
- 3000 IOPS suitable for most Spark workloads
- 125 MB/s per volume = 250 MB/s per core node
- Consistent performance vs gp2 (no burst credits)

#### HDFS Site Configuration

```hcl
"dfs.replication"                    = "3"
"dfs.datanode.failed.volumes.tolerated" = "1"
"dfs.namenode.handler.count"         = "100"
"dfs.datanode.handler.count"         = "30"
```

**Reliability Features:**
- 3x replication for fault tolerance
- Tolerates 1 failed volume per DataNode
- Optimized handler threads for throughput

#### Encryption at Rest

```hcl
enable_ebs_encryption = true
```

**Security Benefits:**
- EBS volumes encrypted with AWS KMS
- Meets compliance requirements (PCI-DSS, HIPAA)
- No performance impact
- Transparent to HDFS

## Features

### Core Features

- ✅ **Cost-optimized architecture** using Spot instances for compute
- ✅ **HDFS reliability** with On-Demand core nodes and EBS-backed storage
- ✅ **Auto-scaling** task nodes (10-50 nodes) based on workload
- ✅ **Managed scaling policy** with YARN-aware metrics
- ✅ **Fault tolerance** with Spark speculation and dynamic allocation
- ✅ **Monitoring** with CloudWatch logs and Ganglia
- ✅ **Security** with EBS encryption and security groups
- ✅ **High availability** with 3x HDFS replication
- ✅ **Capacity-optimized Spot** allocation strategy
- ✅ **Fallback to On-Demand** for task nodes when Spot unavailable

### Spark Optimizations

- **Dynamic Allocation:** Auto-scales executors based on workload
- **Shuffle Service:** Preserves shuffle data during executor scaling
- **Adaptive Query Execution:** Optimizes query plans at runtime
- **Speculation:** Re-executes slow tasks on faster nodes
- **Maximized Resource Allocation:** Uses all available cluster resources

### HDFS Optimizations

- **Multiple EBS volumes per core node** for parallel I/O
- **gp3 volumes** with provisioned IOPS and throughput
- **3x replication** for fault tolerance
- **Failed volume tolerance** to handle partial disk failures
- **Optimized handler threads** for high throughput

## Prerequisites

Before deploying this EMR cluster, ensure you have:

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.0 installed
3. **AWS CLI** configured with credentials
4. **VPC and Subnet** already created
5. **S3 Bucket** for EMR logs
6. **EC2 Key Pair** for SSH access
7. **IAM Permissions** to create:
   - EMR clusters
   - IAM roles and policies
   - Security groups
   - EC2 instances

### Required AWS Permissions

The AWS user/role running Terraform needs:
- `elasticmapreduce:*`
- `ec2:*` (for security groups and instances)
- `iam:*` (for creating roles)
- `s3:*` (for log bucket access)

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/iotda-ol/emr-cost-optimized-spark-cluster-with-hdfs-core-and-spot-task-nodes.git
cd emr-cost-optimized-spark-cluster-with-hdfs-core-and-spot-task-nodes
```

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your AWS configuration
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review the Plan

```bash
terraform plan
```

### 5. Deploy the Cluster

```bash
terraform apply
```

### 6. Access the Cluster

```bash
# SSH to master node
ssh -i /path/to/key.pem hadoop@<master_public_dns>

# View Spark History Server
# http://<master_public_dns>:18080
```

## Configuration

### Required Variables

These variables **must** be set in `terraform.tfvars`:

```hcl
key_name  = "my-ec2-keypair"        # Your EC2 key pair name
subnet_id = "subnet-xxxxxxxxx"      # Subnet ID for EMR cluster
vpc_id    = "vpc-xxxxxxxxx"         # VPC ID for security groups
log_uri   = "s3://my-bucket/logs/"  # S3 URI for cluster logs
```

### Optional Variables

Customize these variables for your workload:

```hcl
# Cluster Configuration
cluster_name      = "spark-cost-optimized-cluster"
emr_release_label = "emr-6.15.0"
aws_region        = "us-east-1"
environment       = "production"

# Master Node
master_instance_type = "m5.xlarge"

# Core Nodes (On-Demand with HDFS)
core_instance_type            = "r5.2xlarge"
core_instance_count           = 3
core_ebs_volume_size          = 500
core_ebs_volumes_per_instance = 2

# Task Nodes (Spot for compute)
task_instance_type      = "r5.xlarge"
task_instance_min_count = 10
task_instance_max_count = 50

# Security
allowed_cidr_blocks = ["10.0.0.0/8"]
enable_ebs_encryption = true

# Additional Settings
enable_termination_protection = false
auto_termination_minutes      = 0  # Disable auto-termination
```

### Instance Type Selection Guide

| Node Type | Recommended | Alternative | Use Case |
|-----------|-------------|-------------|----------|
| Master | m5.xlarge | m5.2xlarge | Cluster management |
| Core | r5.2xlarge | r5.4xlarge | HDFS + Spark executors |
| Task | r5.xlarge | m5.xlarge | Compute-only workloads |

**Memory-Optimized (r5) Rationale:**
- Spark is memory-intensive
- HDFS caching benefits from extra memory
- Better performance for in-memory analytics

## Deployment

### Step-by-Step Deployment

1. **Prepare AWS Environment**
   ```bash
   # Create S3 bucket for logs
   aws s3 mb s3://my-emr-logs-bucket
   
   # Verify VPC and subnet
   aws ec2 describe-subnets --subnet-ids subnet-xxxxxxxxx
   ```

2. **Configure Terraform**
   ```bash
   # Copy example configuration
   cp terraform.tfvars.example terraform.tfvars
   
   # Edit with your values
   vim terraform.tfvars
   ```

3. **Initialize and Validate**
   ```bash
   terraform init
   terraform validate
   terraform fmt
   ```

4. **Plan and Review**
   ```bash
   terraform plan -out=tfplan
   # Review the plan carefully
   ```

5. **Apply Configuration**
   ```bash
   terraform apply tfplan
   ```

6. **Verify Deployment**
   ```bash
   # Get cluster ID
   terraform output cluster_id
   
   # Check cluster status
   aws emr describe-cluster --cluster-id j-XXXXXXXXXXXXX
   ```

### Deployment Time

- **Initial provisioning:** 10-15 minutes
- **Master node ready:** ~5 minutes
- **Core nodes ready:** ~8 minutes
- **Task nodes scaling:** ~3-5 minutes

## Monitoring

### CloudWatch Logs

EMR automatically sends logs to CloudWatch:
- Application logs (Spark, Hadoop)
- System logs (daemon, bootstrap)
- Step logs (for submitted jobs)

**Access logs:**
```bash
# View in AWS Console
AWS Console > CloudWatch > Log Groups > /aws/emr/<cluster-id>

# Or via CLI
aws logs tail /aws/emr/<cluster-id> --follow
```

### Ganglia Monitoring

Access Ganglia web interface:
```bash
# Set up SSH tunnel
ssh -i key.pem -L 8080:localhost:80 hadoop@<master_public_dns>

# Open browser
http://localhost:8080/ganglia
```

**Ganglia Metrics:**
- CPU utilization
- Memory usage
- Network I/O
- Disk I/O
- HDFS metrics

### Spark History Server

Access Spark UI:
```
http://<master_public_dns>:18080
```

**Available Information:**
- Completed Spark jobs
- Job execution timeline
- Stage details and task metrics
- Executor metrics
- SQL query plans

### YARN ResourceManager

Access YARN UI:
```bash
# Set up SSH tunnel
ssh -i key.pem -L 8088:localhost:8088 hadoop@<master_public_dns>

# Open browser
http://localhost:8088
```

**YARN Metrics:**
- Running applications
- Cluster capacity utilization
- Queue status
- Node health

### CloudWatch Metrics

EMR publishes metrics to CloudWatch:
- `IsIdle` - Cluster idle status
- `AppsRunning` - Number of running applications
- `ContainerAllocated` - Allocated YARN containers
- `MemoryAvailableMB` - Available YARN memory
- `HDFSUtilization` - HDFS storage utilization

**Set up alarms:**
```bash
# Example: Alert when HDFS utilization > 80%
aws cloudwatch put-metric-alarm \
  --alarm-name emr-hdfs-high-utilization \
  --alarm-description "HDFS utilization above 80%" \
  --metric-name HDFSUtilization \
  --namespace AWS/ElasticMapReduce \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2
```

## Cost Estimation

### Monthly Cost Breakdown (Example)

**Assumptions:**
- Region: us-east-1
- Usage: 24/7 (730 hours/month)
- Task nodes: Average 30 instances (50% of max capacity)

| Component | Instance Type | Count | Pricing | Monthly Cost |
|-----------|---------------|-------|---------|--------------|
| Master | m5.xlarge (On-Demand) | 1 | $0.192/hr | $140 |
| Core | r5.2xlarge (On-Demand) | 3 | $0.504/hr | $1,105 |
| Task | r5.xlarge (Spot) | 30 | ~$0.075/hr | $1,642 |
| EBS (gp3) | 3TB core storage | - | $0.08/GB | $240 |
| **Total** | | | | **~$3,127** |

**Compared to All On-Demand:**
| Component | Instance Type | Count | Pricing | Monthly Cost |
|-----------|---------------|-------|---------|--------------|
| Master | m5.xlarge | 1 | $0.192/hr | $140 |
| Core | r5.2xlarge | 3 | $0.504/hr | $1,105 |
| Task | r5.xlarge (On-Demand) | 30 | $0.252/hr | $5,518 |
| EBS (gp3) | 3TB storage | - | $0.08/GB | $240 |
| **Total** | | | | **~$7,003** |

**Savings: $3,876/month (55% reduction)**

### Cost Optimization Tips

1. **Right-size instances** based on workload analysis
2. **Use auto-termination** for dev/test clusters
3. **Schedule clusters** for business hours only (if applicable)
4. **Monitor Spot interruptions** and adjust instance types
5. **Use Reserved Instances** for core nodes in production
6. **Compress data** in HDFS to reduce storage costs
7. **Clean up old logs** from S3 regularly
8. **Use S3 for cold data** instead of HDFS

### Cost Monitoring

```bash
# AWS Cost Explorer API
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter file://emr-filter.json
```

## Best Practices

### 1. Production Deployment

- ✅ Use at least 3 core nodes for HDFS reliability
- ✅ Enable termination protection for production clusters
- ✅ Enable EBS encryption for compliance
- ✅ Use dedicated VPC and subnets
- ✅ Implement least-privilege IAM policies
- ✅ Enable CloudWatch monitoring and alarms
- ✅ Regular backups of critical HDFS data to S3

### 2. Security

- ✅ Restrict security group ingress to known IPs
- ✅ Use EC2 key pairs for SSH access
- ✅ Enable encryption at rest (EBS) and in transit
- ✅ Implement VPC endpoints for S3 access
- ✅ Use AWS Secrets Manager for credentials
- ✅ Enable CloudTrail for audit logging

### 3. Performance Tuning

- ✅ Monitor YARN memory utilization
- ✅ Adjust Spark executor memory/cores based on workload
- ✅ Use partition pruning and predicate pushdown
- ✅ Cache frequently accessed data in memory
- ✅ Use appropriate file formats (Parquet, ORC)
- ✅ Coalesce small files to reduce HDFS overhead

### 4. Data Management

- ✅ Use S3 for long-term data storage
- ✅ Use HDFS for intermediate/temporary data
- ✅ Implement data lifecycle policies
- ✅ Monitor HDFS utilization and capacity
- ✅ Regular HDFS balancer runs
- ✅ Archive old data to Glacier

### 5. Spot Instance Management

- ✅ Use multiple instance types in Spot fleet
- ✅ Enable capacity-optimized allocation strategy
- ✅ Set timeout action to SWITCH_TO_ON_DEMAND
- ✅ Monitor Spot interruption rates
- ✅ Use Spot instance advisor for instance selection

### 6. Cost Management

- ✅ Use Reserved Instances for core nodes (1-3 year)
- ✅ Implement auto-termination for dev/test
- ✅ Tag resources for cost allocation
- ✅ Monitor and optimize idle time
- ✅ Review and adjust auto-scaling policies

## Troubleshooting

### Common Issues

#### 1. Cluster Fails to Start

**Symptoms:**
- Cluster status: `TERMINATED_WITH_ERRORS`
- Bootstrap actions fail

**Solutions:**
```bash
# Check logs
aws emr describe-cluster --cluster-id j-XXXXXXXXXXXXX

# Review bootstrap logs
aws s3 cp s3://your-log-bucket/j-XXXXXXXXXXXXX/ . --recursive
```

**Common causes:**
- Insufficient subnet capacity
- Security group misconfiguration
- Invalid S3 log URI
- IAM role permissions

#### 2. HDFS Capacity Issues

**Symptoms:**
- `No space left on device` errors
- HDFS utilization > 90%

**Solutions:**
```bash
# Check HDFS usage
hdfs dfsadmin -report

# Clean up temporary data
hadoop fs -rm -r /tmp/*

# Increase core node EBS volumes
terraform apply -var="core_ebs_volume_size=1000"
```

#### 3. Task Node Spot Interruptions

**Symptoms:**
- Frequent task node terminations
- Degraded job performance

**Solutions:**
```bash
# Check Spot interruption rate
aws ec2 describe-spot-instance-requests

# Add alternative instance types
# Modify main.tf instance_type_configs

# Increase On-Demand capacity temporarily
terraform apply -var="task_instance_min_count=0"
```

#### 4. Slow Job Performance

**Symptoms:**
- Jobs taking longer than expected
- Low CPU/memory utilization

**Solutions:**
```bash
# Check YARN resource utilization
yarn node -list -all

# Increase parallelism
spark-submit --conf spark.sql.shuffle.partitions=400

# Adjust executor resources
spark-submit --executor-memory 8g --executor-cores 4
```

#### 5. Network Connectivity Issues

**Symptoms:**
- Nodes unable to communicate
- DNS resolution failures

**Solutions:**
```bash
# Verify security group rules
aws ec2 describe-security-groups --group-ids sg-xxxxx

# Check subnet routing
aws ec2 describe-route-tables

# Test connectivity
ssh hadoop@master
ping core-node-1.internal
```

### Debug Commands

```bash
# SSH to master node
ssh -i key.pem hadoop@<master_public_dns>

# Check HDFS health
hdfs dfsadmin -report
hdfs fsck / -files -blocks -locations

# Check YARN status
yarn node -list -all
yarn application -list

# View Hadoop logs
cat /var/log/hadoop-hdfs/hadoop-hdfs-namenode-*.log

# View Spark logs
cat /var/log/spark/spark-*.log

# Check disk usage
df -h
du -sh /mnt/*

# Monitor cluster in real-time
top
htop
iotop
```

### Getting Help

1. **AWS Support:** For production issues
2. **EMR Documentation:** https://docs.aws.amazon.com/emr/
3. **Terraform AWS Provider:** https://registry.terraform.io/providers/hashicorp/aws/
4. **Spark Documentation:** https://spark.apache.org/docs/latest/

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Submit a pull request

## Acknowledgments

This configuration follows AWS best practices for:
- EMR cluster design
- Spot instance usage
- HDFS reliability
- Cost optimization
- DEA-C01 certification guidelines

---

**Note:** This is a reference architecture. Always test thoroughly in a non-production environment before deploying to production. Adjust instance types, counts, and configuration based on your specific workload requirements.
