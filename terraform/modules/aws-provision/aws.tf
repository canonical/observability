terraform {
  required_version = ">= 1.5"
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

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, 1)
  availability_zone       = element(data.aws_availability_zones.available.names, 0)
  map_public_ip_on_launch = true
  tags = {
    "kubernetes.io/role/elb" = "1"
  }

}

resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, 2)
  availability_zone       = element(data.aws_availability_zones.available.names, 1)
  map_public_ip_on_launch = true
  tags = {
    "kubernetes.io/role/elb" = "1"
  }

}

# Private Subnets
resource "aws_subnet" "private_subnet1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, 10)
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}
resource "aws_subnet" "private_subnet2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, 11)
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# NAT Gateway
resource "aws_eip" "nat_eip" {
  count = 1
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip[0].id
  subnet_id     = aws_subnet.subnet1.id
  tags          = { Name = "eks-nat-gw" }
  depends_on    = [aws_internet_gateway.internet_gateway]
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
}


resource "aws_route_table_association" "public_rta1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rta2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
}

resource "aws_route_table_association" "private_rta1" {
  subnet_id      = aws_subnet.private_subnet1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_rta2" {
  subnet_id      = aws_subnet.private_subnet2.id
  route_table_id = aws_route_table.private_rt.id
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

  # to access the juju controller
  ingress {
    protocol    = "tcp"
    from_port   = 17070
    to_port     = 17070
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
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
      aws_subnet.private_subnet1.id,
      aws_subnet.private_subnet2.id,
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
  depends_on   = [aws_eks_node_group.cos_workers]
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
  depends_on = [aws_eks_node_group.cos_workers]
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

# Give the admin access to eks
data "aws_caller_identity" "admin" {}

data "aws_iam_session_context" "admin_iam" {
  arn = data.aws_caller_identity.admin.arn
}

resource "aws_eks_access_policy_association" "admin_eks_admin_policy" {
  cluster_name  = aws_eks_cluster.cos_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
  principal_arn = data.aws_iam_session_context.admin_iam.issuer_arn
  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_policy_association" "admin_eks_cluster_admin_policy" {
  cluster_name  = aws_eks_cluster.cos_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = data.aws_iam_session_context.admin_iam.issuer_arn
  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_entry" "admin_access_entry" {
  cluster_name  = aws_eks_cluster.cos_cluster.name
  principal_arn = data.aws_iam_session_context.admin_iam.issuer_arn
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

# give the management machine access entry to the eks cluster
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
  instance_type        = "t3.medium"
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

# bootstrap juju
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
      "sudo snap install jq",
      "sudo snap install yq",
      "sudo apt install unzip",
      "curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\"",
      "unzip awscliv2.zip",
      "sudo ./aws/install",

      # TODO: remove hardcoded values
      "aws eks --region eu-central-1 update-kubeconfig --name cos-cluster",
      "/snap/juju/current/bin/juju add-k8s cos-cloud",
      "juju bootstrap cos-cloud cos-controller",
    ]
  }
}


data "external" "juju_controller_config" {
  depends_on = [null_resource.bootstrap_juju]

  program = ["bash", "-c", <<-EOT
    ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@${aws_instance.management.public_ip} /bin/bash <<'REMOTE_EOF'
    #!/bin/bash
    set -euo pipefail

    CONTROLLER=$(juju whoami | yq -r .Controller)
    JUJU_DATA=$(juju show-controller "$CONTROLLER" --format json)
    JUJU_ACCOUNTS=$(cat ~/.local/share/juju/accounts.yaml)

    jq -n \
      --arg username "$(echo "$JUJU_ACCOUNTS" | yq -r ".controllers.\"$CONTROLLER\".user")" \
      --arg password "$(echo "$JUJU_ACCOUNTS" | yq -r ".controllers.\"$CONTROLLER\".password")" \
      --arg ca_cert "$(echo "$JUJU_DATA" | jq -r '.[].details["ca-cert"]')" \
      '{
        juju_username: $username,
        juju_password: $password,
        juju_ca_cert: $ca_cert,
      }'
    REMOTE_EOF
  EOT
  ]
}


# create a public controller service
# copy the kubeconfig so we can use the kubernetes provider
resource "null_resource" "copy_kubeconfig" {
  depends_on = [null_resource.bootstrap_juju]

  provisioner "local-exec" {
    # TODO: check if there's a better way to pass ssh keys
    # copy the kubeconfig generated in the ec2 instance to the current directory
    command = "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_rsa ubuntu@${aws_instance.management.public_ip}:~/.kube/config ."
  }
}

provider "kubernetes" {
  config_path = "./config"
}

# TODO: check if we can configure health checks
resource "kubernetes_service" "controller_public_nlb" {
  depends_on             = [null_resource.copy_kubeconfig]
  wait_for_load_balancer = true
  metadata {
    name      = "controller-public-service"
    namespace = "controller-cos-controller"
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-scheme" : "internet-facing"
    }
  }
  spec {
    selector = {
      "app.kubernetes.io/name" = "controller"
    }
    port {
      port        = 17070
      target_port = 17070
    }
    type                = "LoadBalancer"
    load_balancer_class = "eks.amazonaws.com/nlb"
  }
}

# create S3 Buckets
resource "aws_s3_bucket" "tempo_s3" {
  bucket = "cos-tempo-bucket"
}

resource "aws_s3_bucket" "loki_s3" {
  bucket = "cos-loki-bucket"
}

resource "aws_s3_bucket" "mimir_s3" {
  bucket = "cos-mimir-bucket"
}




# for Tempo
resource "aws_iam_role" "tempo_s3_role" {
  name = "cos-tempo-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "pods.eks.amazonaws.com"
        },
        Action = [
          "sts:AssumeRole",
        "sts:TagSession"]
      }
    ]
  })
}
resource "aws_iam_policy" "tempo_s3_policy" {
  name = "cos-tempo-s3-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          "s3:*",
        ],
        Resource : [
          "arn:aws:s3:::${aws_s3_bucket.tempo_s3.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.tempo_s3.bucket}/*"
        ]
      }
    ]
  })

}


resource "aws_iam_role_policy_attachment" "attach_tempo_s3" {
  role       = aws_iam_role.tempo_s3_role.name
  policy_arn = aws_iam_policy.tempo_s3_policy.arn
}

resource "aws_eks_pod_identity_association" "tempo_querier_s3_access" {
  cluster_name    = aws_eks_cluster.cos_cluster.name
  namespace       = "cos"
  service_account = "tempo-querier"
  role_arn        = aws_iam_role.tempo_s3_role.arn
}

resource "aws_eks_pod_identity_association" "tempo_ingester_s3_access" {
  cluster_name    = aws_eks_cluster.cos_cluster.name
  namespace       = "cos"
  service_account = "tempo-ingester"
  role_arn        = aws_iam_role.tempo_s3_role.arn
}

resource "aws_eks_pod_identity_association" "tempo_metrics_generator_s3_access" {
  cluster_name    = aws_eks_cluster.cos_cluster.name
  namespace       = "cos"
  service_account = "tempo-metrics-generator"
  role_arn        = aws_iam_role.tempo_s3_role.arn
}

# for Loki
resource "aws_iam_role" "loki_s3_role" {
  name = "cos-loki-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "pods.eks.amazonaws.com"
        },
        Action = [
          "sts:AssumeRole",
        "sts:TagSession"]
      }
    ]
  })
}

resource "aws_iam_policy" "loki_s3_policy" {
  name = "cos-loki-s3-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          "s3:*",

        ],
        Resource : [
          "arn:aws:s3:::${aws_s3_bucket.loki_s3.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.loki_s3.bucket}/*"
        ]
      }
    ]
  })
}



resource "aws_iam_role_policy_attachment" "attach_loki_s3" {
  role       = aws_iam_role.loki_s3_role.name
  policy_arn = aws_iam_policy.loki_s3_policy.arn
}

resource "aws_eks_pod_identity_association" "loki_backend_s3_access" {
  cluster_name    = aws_eks_cluster.cos_cluster.name
  namespace       = "cos"
  service_account = "loki-backend"
  role_arn        = aws_iam_role.loki_s3_role.arn
}

resource "aws_eks_pod_identity_association" "loki_read_s3_access" {
  cluster_name    = aws_eks_cluster.cos_cluster.name
  namespace       = "cos"
  service_account = "loki-read"
  role_arn        = aws_iam_role.loki_s3_role.arn
}

resource "aws_eks_pod_identity_association" "loki_write_s3_access" {
  cluster_name    = aws_eks_cluster.cos_cluster.name
  namespace       = "cos"
  service_account = "loki-write"
  role_arn        = aws_iam_role.loki_s3_role.arn
}

# for Mimir
resource "aws_iam_role" "mimir_s3_role" {
  name = "cos-mimir-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "pods.eks.amazonaws.com"
        },
        Action = [
          "sts:AssumeRole",
        "sts:TagSession"]
      }
    ]
  })
}

resource "aws_iam_policy" "mimir_s3_policy" {
  name = "cos-mimir-s3-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          "s3:*",

        ],
        Resource : [
          "arn:aws:s3:::${aws_s3_bucket.mimir_s3.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.mimir_s3.bucket}/*"
        ]
      }
    ]
  })
}



resource "aws_iam_role_policy_attachment" "attach_mimir_s3" {
  role       = aws_iam_role.mimir_s3_role.name
  policy_arn = aws_iam_policy.mimir_s3_policy.arn
}

resource "aws_eks_pod_identity_association" "mimir_backend_s3_access" {
  cluster_name    = aws_eks_cluster.cos_cluster.name
  namespace       = "cos"
  service_account = "mimir-backend"
  role_arn        = aws_iam_role.mimir_s3_role.arn
}

resource "aws_eks_pod_identity_association" "mimir_read_s3_access" {
  cluster_name    = aws_eks_cluster.cos_cluster.name
  namespace       = "cos"
  service_account = "mimir-read"
  role_arn        = aws_iam_role.mimir_s3_role.arn
}

resource "aws_eks_pod_identity_association" "mimir_write_s3_access" {
  cluster_name    = aws_eks_cluster.cos_cluster.name
  namespace       = "cos"
  service_account = "mimir-write"
  role_arn        = aws_iam_role.mimir_s3_role.arn
}

# bootstrap COS
provider "juju" {
  controller_addresses = "${kubernetes_service.controller_public_nlb.status[0].load_balancer[0].ingress[0].hostname}:17070"
  username             = data.external.juju_controller_config.result.juju_username
  password             = data.external.juju_controller_config.result.juju_password
  ca_certificate       = data.external.juju_controller_config.result.juju_ca_cert
}

resource "juju_model" "cos_model" {
  name = "cos"
}

module "cos" {
  depends_on = [aws_s3_bucket.loki_s3, aws_s3_bucket.mimir_s3, aws_s3_bucket.tempo_s3]
  source     = "../cos"
  model_name = juju_model.cos_model.name
  # TODO: use tls
  use_tls      = false
  loki_bucket  = aws_s3_bucket.loki_s3.bucket
  mimir_bucket = aws_s3_bucket.mimir_s3.bucket
  tempo_bucket = aws_s3_bucket.tempo_s3.bucket
  s3_endpoint  = "https://s3.eu-central-1.amazonaws.com"
  # we don't create access and secret keys
  s3_user     = "foo"
  s3_password = "bar"

  # make traefik's LB public
  configs = {
    traefik = {
      "loadbalancer_annotations" = "service.beta.kubernetes.io/aws-load-balancer-scheme=internet-facing"
    }
  }

  # pass config of remote instance's juju client
  remote_ip       = aws_instance.management.public_ip
  remote_user     = "ubuntu"
  ssh_private_key = "~/.ssh/id_rsa"
}


# OUTPUTS
output "controller-nlb" {
  value = kubernetes_service.controller_public_nlb.status[0].load_balancer[0].ingress[0].hostname
}

output "public-dns" {
  value = aws_instance.management.*.public_dns[0]
}
output "public-ip" {
  value = aws_instance.management.public_ip
}

output "tempo-bucket-endpoint" {
  value = aws_s3_bucket.tempo_s3.bucket_regional_domain_name
}
