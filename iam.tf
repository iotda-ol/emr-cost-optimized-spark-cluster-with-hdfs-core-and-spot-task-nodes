# EMR Service Role
resource "aws_iam_role" "emr_service_role" {
  name = "${var.cluster_name}-emr-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "elasticmapreduce.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-emr-service-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "emr_service_policy" {
  role       = aws_iam_role.emr_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole"
}

# EMR EC2 Instance Profile Role
resource "aws_iam_role" "emr_ec2_role" {
  name = "${var.cluster_name}-emr-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-emr-ec2-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "emr_ec2_policy" {
  role       = aws_iam_role.emr_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"
}

# Instance profile for EMR EC2 instances
resource "aws_iam_instance_profile" "emr_ec2_instance_profile" {
  name = "${var.cluster_name}-emr-ec2-instance-profile"
  role = aws_iam_role.emr_ec2_role.name

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-emr-ec2-instance-profile"
    }
  )
}

# EMR Auto Scaling Role
resource "aws_iam_role" "emr_autoscaling_role" {
  name = "${var.cluster_name}-emr-autoscaling-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "elasticmapreduce.amazonaws.com",
            "application-autoscaling.amazonaws.com"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-emr-autoscaling-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "emr_autoscaling_policy" {
  role       = aws_iam_role.emr_autoscaling_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforAutoScalingRole"
}
