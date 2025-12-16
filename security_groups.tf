# Security Group for EMR Master Node
resource "aws_security_group" "emr_master" {
  name        = "${var.cluster_name}-master-sg"
  description = "Security group for EMR master node"
  vpc_id      = var.vpc_id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  # Allow SSH from specified CIDR blocks
  dynamic "ingress" {
    for_each = length(var.allowed_cidr_blocks) > 0 ? var.allowed_cidr_blocks : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "SSH access"
    }
  }

  # Allow Spark UI access from specified CIDR blocks
  dynamic "ingress" {
    for_each = length(var.allowed_cidr_blocks) > 0 ? var.allowed_cidr_blocks : []
    content {
      from_port   = 18080
      to_port     = 18080
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "Spark History Server UI"
    }
  }

  # Allow communication between master and workers
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
    description = "Allow all traffic within security group"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-master-sg"
    }
  )
}

# Security Group for EMR Worker Nodes (Core and Task)
resource "aws_security_group" "emr_worker" {
  name        = "${var.cluster_name}-worker-sg"
  description = "Security group for EMR worker nodes (core and task)"
  vpc_id      = var.vpc_id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  # Allow communication between workers and master
  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.emr_master.id]
    description     = "Allow traffic from master node"
  }

  # Allow communication between workers
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
    description = "Allow all traffic within security group"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-worker-sg"
    }
  )
}

# Allow master to communicate with workers
resource "aws_security_group_rule" "master_to_worker" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.emr_worker.id
  security_group_id        = aws_security_group.emr_master.id
  description              = "Allow traffic from worker nodes"
}
