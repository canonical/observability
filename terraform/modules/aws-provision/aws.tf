terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    juju = {
      source  = "juju/juju"
      version = "~> 0.14"
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
  tags = {
    "kubernetes.io/role/internal-elb" : ""
  }

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


  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
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

# TODO: is this needed?
# resource "aws_ec2_fleet" "nat_gateway_eip" {
#   // CF Property(Domain) = "vpc"
# }

# resource "aws_nat_gateway" "nat_gateway" {
#   allocation_id = aws_ec2_fleet.nat_gateway_eip.id
#   subnet_id = aws_subnet.managed_app_subnet.id
# }


resource "aws_route_table_association" "subnet_1_association" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "subnet_2_association" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.main.id
}




# setup EKS cluster
resource "aws_iam_role" "cos_cluster_role" {
  name = "cos-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = ["eks.amazonaws.com"]
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

}

resource "aws_iam_role_policy_attachment" "cos_cluster_policy" {
  role       = aws_iam_role.cos_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_iam_role_policy_attachment" "cos_cluster_network_policy" {
  role       = aws_iam_role.cos_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
}
resource "aws_iam_role_policy_attachment" "cos_cluster_lb_policy" {
  role       = aws_iam_role.cos_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
}
resource "aws_iam_role_policy_attachment" "cos_cluster_storage_policy" {
  role       = aws_iam_role.cos_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
}
resource "aws_iam_role_policy_attachment" "cos_cluster_compute_policy" {
  role       = aws_iam_role.cos_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
}

resource "aws_eks_cluster" "cos_cluster" {
  name                          = "cos-cluster"
  bootstrap_self_managed_addons = false
  access_config {
    authentication_mode = "API"
  }
  role_arn = aws_iam_role.cos_cluster_role.arn
  compute_config {
    enabled = true
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
  }

  depends_on = [
    aws_iam_role_policy_attachment.cos_cluster_policy,
    aws_iam_role_policy_attachment.cos_cluster_network_policy,
    aws_iam_role_policy_attachment.cos_cluster_lb_policy,
    aws_iam_role_policy_attachment.cos_cluster_storage_policy,
    aws_iam_role_policy_attachment.cos_cluster_compute_policy,
  ]
}

resource "aws_eks_addon" "eks_kube_proxy_addon" {
  cluster_name = aws_eks_cluster.cos_cluster.name
  addon_name   = "kube-proxy"
}

resource "aws_eks_addon" "eks_core_dns_addon" {
  cluster_name = aws_eks_cluster.cos_cluster.name
  addon_name   = "coredns"
}

resource "aws_eks_addon" "eks_vpc_cni_addon" {
  cluster_name = aws_eks_cluster.cos_cluster.name
  addon_name   = "vpc-cni"
}

resource "aws_eks_addon" "eks_pod_identity_addon" {
  cluster_name = aws_eks_cluster.cos_cluster.name
  addon_name   = "eks-pod-identity-agent"
}

# create aws-ebs-csi-driver
resource "aws_iam_role" "eks_ebs_role" {
  name = "eks-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = ["sts:AssumeRole", "sts:TagSession"]
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "eks_ebs_policy" {
  role       = aws_iam_role.eks_ebs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}


resource "aws_eks_addon" "eks_ebs_addon" {
  cluster_name = aws_eks_cluster.cos_cluster.name
  addon_name   = "aws-ebs-csi-driver"
  pod_identity_association {
    role_arn        = aws_iam_role.eks_ebs_role.arn
    service_account = "ebs-csi-controller-sa"
  }
}

# worker nodes
resource "aws_iam_role" "workers_role" {
  name = "workers-role"
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
}

resource "aws_iam_role_policy_attachment" "workers_nodes_policy" {
  role       = aws_iam_role.workers_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "workers_cni_policy" {
  role       = aws_iam_role.workers_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "workers_registry_policy" {
  role       = aws_iam_role.workers_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_eks_node_group" "cos_workers" {
  cluster_name    = aws_eks_cluster.cos_cluster.name
  node_group_name = "cos-workers"
  node_role_arn   = aws_iam_role.workers_role.arn
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
  ami_type = "AL2_x86_64"

  depends_on = [
    aws_iam_role_policy_attachment.workers_nodes_policy,
    aws_iam_role_policy_attachment.workers_registry_policy,
    aws_iam_role_policy_attachment.workers_cni_policy,
  ]
}



# create juju client machine
resource "aws_key_pair" "tf_key" {
  key_name   = "user"
  public_key = file("~/.ssh/id_rsa.pub")
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

resource "aws_iam_role" "mgmt_eks_role" {
  name = "mgmt-eks-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = ["ec2.amazonaws.com"]
        }
        Action = [
          "sts:AssumeRole",
        ]
      }
    ]
  })

}

resource "aws_iam_policy" "mgmt_eks_policy" {
  name = "mgmt-eks-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "eks:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "mgmt_eks_policy_attachment" {
  role       = aws_iam_role.mgmt_eks_role.name
  policy_arn = aws_iam_policy.mgmt_eks_policy.arn
}

resource "aws_iam_instance_profile" "mgmt_instance_profile" {
  name = "mgmt-instance-profile"
  role = aws_iam_role.mgmt_eks_role.name
}

# give access entry to the COS cluster
resource "aws_eks_access_entry" "mgmt_access_entry" {
  cluster_name  = aws_eks_cluster.cos_cluster.name
  principal_arn = aws_iam_role.mgmt_eks_role.arn

}

resource "aws_eks_access_policy_association" "mgmt_access_eks_admin" {
  cluster_name  = aws_eks_cluster.cos_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
  principal_arn = aws_iam_role.mgmt_eks_role.arn

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_policy_association" "mgmt_access_eks_cluster_admin" {
  cluster_name  = aws_eks_cluster.cos_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.mgmt_eks_role.arn

  access_scope {
    type = "cluster"
  }
}


# create a machine with that image
resource "aws_instance" "management" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.mgmt_instance_profile.name

  # this allows us to connect
  vpc_security_group_ids = [aws_security_group.security.id]
  # allow this key to ssh in there
  key_name = aws_key_pair.tf_key.key_name

  associate_public_ip_address = true
  subnet_id                   = aws_subnet.subnet1.id

  tags = {
    Name = "juju_client"
  }
  depends_on = [
    aws_eks_cluster.cos_cluster,
    aws_eks_node_group.cos_workers,
    aws_eks_access_entry.mgmt_access_entry,
    aws_eks_addon.eks_ebs_addon,
    aws_iam_role.mgmt_eks_role,
  ]
}

resource "null_resource" "bootstrap_juju" {
  depends_on = [aws_instance.management]

  connection {
    type        = "ssh"
    host        = aws_instance.management.public_ip
    user        = "ubuntu"
    private_key = file("~/.ssh/id_rsa")
  }

  provisioner "remote-exec" {
    inline = [
      "sudo snap wait system seed.loaded",
      "sudo snap install juju --channel 3/stable",
      "sudo snap install kubectl --classic",
      "sudo snap install yq",
      "sudo apt update",
      "sudo apt install -y python3-pip",
      "sudo pip install --upgrade awscli",
      # aws-iam-authenticator how does it help?
      "curl -o aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.12.7/2019-03-27/bin/linux/amd64/aws-iam-authenticator",
      "sudo chmod +x ./aws-iam-authenticator",
      "sudo mv ./aws-iam-authenticator /usr/local/bin/",
      # TODO: remove hardcoded values
      "aws eks --region eu-central-1 update-kubeconfig --name cos-cluster",
      "/snap/juju/current/bin/juju add-k8s eks-cloud",
      "juju bootstrap eks-cloud",
    ]
  }
}


provider "juju" {
  controller_addresses = aws_instance.management.public_ip
  
}

resource "juju_model" "development" {
  name = "development"

  cloud {
    name   = "aws"
    region = "eu-west-1"
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

