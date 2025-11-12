# EC2 module - Kubernetes cluster instances
# S3 bucket is created in root module and passed in

locals {
  master_init_user_data = templatefile("${path.module}/../../scripts/master_setup.sh", {
    s3_bucket              = var.s3_bucket_name
    aws_region             = var.aws_region
    control_plane_endpoint = var.control_plane_endpoint
    node_hostname          = "master1"
  })

  master_join_user_data = { for idx in range(1, var.master_count) :
    idx => templatefile("${path.module}/../../scripts/master_join.sh", {
      s3_bucket              = var.s3_bucket_name
      aws_region             = var.aws_region
      control_plane_endpoint = var.control_plane_endpoint
      node_hostname          = "master${idx + 1}"
    })
  }

  worker_user_data = { for idx in range(var.worker_count) :
    idx => templatefile("${path.module}/../../scripts/worker_setup.sh", {
      s3_bucket              = var.s3_bucket_name
      aws_region             = var.aws_region
      control_plane_endpoint = var.control_plane_endpoint
      node_hostname          = "worker${idx + 1}"
    })
  }

  repo_user_data = file("${path.module}/../../scripts/repo_setup.sh")
}

# IAM Role for EC2 instances
resource "aws_iam_role" "k8s_node_role" {
  name_prefix = "${var.project_name}-${var.environment}-k8s-node-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-k8s-node-role"
    }
  )
}

# IAM Policy for S3 access (simpler than SSM)
resource "aws_iam_role_policy" "k8s_s3_policy" {
  name_prefix = "${var.project_name}-s3-"
  role        = aws_iam_role.k8s_node_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "k8s_node_profile" {
  name_prefix = "${var.project_name}-${var.environment}-k8s-node-"
  role        = aws_iam_role.k8s_node_role.name

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-k8s-node-profile"
    }
  )
}

# EC2 Instances: Kubernetes Master Nodes
resource "aws_instance" "master" {
  count = var.master_count

  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.public_subnet_ids[count.index % length(var.public_subnet_ids)]
  vpc_security_group_ids = [var.k8s_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.k8s_node_profile.name

  # First master initializes, others join
  user_data = count.index == 0 ? local.master_init_user_data : local.master_join_user_data[count.index]

  # Explicit dependency on IAM resources
  depends_on = [
    aws_iam_role.k8s_node_role,
    aws_iam_instance_profile.k8s_node_profile,
    aws_iam_role_policy.k8s_s3_policy
  ]

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  monitoring                  = var.enable_detailed_monitoring
  associate_public_ip_address = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-master${count.index + 1}"
      Role = "kubernetes-master"
      Node = "master${count.index + 1}"
    }
  )
}

# EC2 Instances: Kubernetes Worker Nodes
resource "aws_instance" "worker" {
  count = var.worker_count

  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.public_subnet_ids[count.index % length(var.public_subnet_ids)]
  vpc_security_group_ids = [var.k8s_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.k8s_node_profile.name

  user_data = local.worker_user_data[count.index]

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  monitoring                  = var.enable_detailed_monitoring
  associate_public_ip_address = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Wait for first master to initialize
  depends_on = [
    aws_instance.master[0],
    aws_iam_role.k8s_node_role,
    aws_iam_instance_profile.k8s_node_profile,
    aws_iam_role_policy.k8s_s3_policy
  ]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-worker${count.index + 1}"
      Role = "kubernetes-worker"
      Node = "worker${count.index + 1}"
    }
  )
}

# EC2 Instance: Private Repository Host
resource "aws_instance" "repo" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.repo_security_group_id]

  user_data = local.repo_user_data

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  monitoring                  = var.enable_detailed_monitoring
  associate_public_ip_address = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-repo"
      Role = "private-repository"
      Node = "repo"
    }
  )
}

# Attach master nodes to load balancer target group
resource "aws_lb_target_group_attachment" "k8s_masters" {
  count = var.master_count

  target_group_arn = var.target_group_arn
  target_id        = aws_instance.master[count.index].id
  port             = 6443
}