terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


provider "aws" {
  region = "eu-central-1"
}

data "aws_availability_zones" "available" {
  state = "available"
}


resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

}

resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 3, 1)
  availability_zone       = element(data.aws_availability_zones.available.names, 0)
  map_public_ip_on_launch = true

}

resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 3, 2)
  availability_zone       = element(data.aws_availability_zones.available.names, 1)
  map_public_ip_on_launch = true

}

# TODO: we should lock this down and verify the users
resource "aws_security_group" "security" {
  name   = "allow-us"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# ingress/egress for us
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
}

resource "aws_route_table_association" "subnet_1_association" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "subnet_2_association" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.main.id
}


# select the image for the machine we'll use to run the juju client
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# setup 3-node EKS
resource "aws_iam_role" "cos_cluster_role" {
  name = "cos-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = ["eks.amazonaws.com", "ec2.amazonaws.com"]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

}

resource "aws_iam_role_policy_attachment" "cos_cluster_policy" {
  role       = aws_iam_role.cos_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "cos_cluster_nodes_policy" {
  role       = aws_iam_role.cos_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cos_cluster_cni_policy" {
  role       = aws_iam_role.cos_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "cos_cluster_compute_policy" {
  role       = aws_iam_role.cos_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
}

resource "aws_iam_role_policy_attachment" "cos_cluster_storage_policy" {
  role       = aws_iam_role.cos_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
}

resource "aws_iam_role_policy_attachment" "cos_cluster_lb_policy" {
  role       = aws_iam_role.cos_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
}

resource "aws_iam_role_policy_attachment" "cos_cluster_network_policy" {
  role       = aws_iam_role.cos_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
}


resource "aws_eks_cluster" "cos_cluster" {
  name = "cos-cp"
  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }
  role_arn                      = aws_iam_role.cos_cluster_role.arn
  bootstrap_self_managed_addons = false
  compute_config {
    enabled       = true
    node_pools    = ["general-purpose"]
    node_role_arn = aws_iam_role.cos_cluster_role.arn
  }

  kubernetes_network_config {
    elastic_load_balancing {
      enabled = true
    }
  }

  storage_config {
    block_storage {
      enabled = true
    }
  }

  vpc_config {
    subnet_ids = [
      aws_subnet.subnet1.id,
      aws_subnet.subnet2.id,
    ]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.cos_cluster_policy,
    aws_iam_role_policy_attachment.cos_cluster_nodes_policy,
    aws_iam_role_policy_attachment.cos_cluster_network_policy,
    aws_iam_role_policy_attachment.cos_cluster_lb_policy,
    aws_iam_role_policy_attachment.cos_cluster_storage_policy,
    aws_iam_role_policy_attachment.cos_cluster_compute_policy,
    aws_iam_role_policy_attachment.cos_cluster_cni_policy,
  ]
}




resource "aws_eks_node_group" "cos_workers" {
  cluster_name    = aws_eks_cluster.cos_cluster.name
  node_group_name = "cos-workers"
  node_role_arn   = aws_iam_role.cos_cluster_role.arn
  subnet_ids = [
    aws_subnet.subnet1.id,
    aws_subnet.subnet2.id,
  ]
  scaling_config {
    min_size     = 3
    max_size     = 3
    desired_size = 3
  }
  # TODO: what is the recommended size and instance type
  # disk_size = 100
  instance_types = [
    "t3.medium"
  ]

  tags = {
    "kubernetes.io/cluster/${aws_eks_cluster.cos_cluster.name}" = "owned"
  }

  depends_on = [
    aws_iam_role_policy_attachment.cos_cluster_cni_policy,
    aws_iam_role_policy_attachment.cos_cluster_nodes_policy,
  ]
}



# create juju client machine
resource "aws_key_pair" "tf_key" {
  key_name   = "user"
  public_key = file("~/.ssh/id_rsa.pub")
}

# create a machine with that image
resource "aws_instance" "management" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  # this allows us to connect
  security_groups = [aws_security_group.security.id]
  # allow this key to ssh in there
  key_name = aws_key_pair.tf_key.key_name

  associate_public_ip_address = true
  subnet_id                   = aws_subnet.subnet1.id

  # put a cloud-init in there
  user_data = file("./juju-bootstrap.yaml")

  tags = {
    Name = "juju_client"
  }
}



# OUTPUTS
output "public-dns" {
  value = aws_instance.management.*.public_dns[0]
}
output "public-ip" {
  value = aws_instance.management.public_ip
}
output "cp-public-ip" {
  value = aws_eks_cluster.cos_cluster.endpoint
}

