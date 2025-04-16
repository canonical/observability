


provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
  state = "available"
}
locals {
  cos-cluster    = "cos-cluster"
  cos-cloud      = "cos-cloud"
  cos-controller = "cos-controller"

}

# Network Infra
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.main.id
  # depends_on = [aws_eip.nat_eip]
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

# resource "aws_subnet" "private_subnet1" {
#   vpc_id            = aws_vpc.main.id
#   cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, 10)
#   availability_zone = data.aws_availability_zones.available.names[0]
#   tags = {
#     "kubernetes.io/role/internal-elb" = "1"
#   }
# }
# resource "aws_subnet" "private_subnet2" {
#   vpc_id            = aws_vpc.main.id
#   cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, 11)
#   availability_zone = data.aws_availability_zones.available.names[1]
#   tags = {
#     "kubernetes.io/role/internal-elb" = "1"
#   }
# }

# resource "aws_eip" "nat_eip" {
#   count = 1
# }

# resource "aws_nat_gateway" "nat_gw" {
#   allocation_id = aws_eip.nat_eip[0].id
#   subnet_id     = aws_subnet.subnet1.id
#   depends_on    = [aws_internet_gateway.internet_gateway]
# }

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

# resource "aws_route_table" "private_rt" {
#   vpc_id = aws_vpc.main.id
#   route {
#     cidr_block     = "0.0.0.0/0"
#     nat_gateway_id = aws_nat_gateway.nat_gw.id
#   }
# }

# resource "aws_route_table_association" "private_rta1" {
#   subnet_id      = aws_subnet.private_subnet1.id
#   route_table_id = aws_route_table.private_rt.id
# }

# resource "aws_route_table_association" "private_rta2" {
#   subnet_id      = aws_subnet.private_subnet2.id
#   route_table_id = aws_route_table.private_rt.id
# }

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


# Kubernetes Infra
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
  name                          = local.cos-cluster
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
      # aws_subnet.private_subnet1.id,
      # aws_subnet.private_subnet2.id,
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cos_cluster_policy,
    aws_iam_role_policy_attachment.cos_cluster_network_policy,
    aws_iam_role_policy_attachment.cos_cluster_lb_policy,
    aws_iam_role_policy_attachment.cos_cluster_storage_policy,
    aws_iam_role_policy_attachment.cos_cluster_compute_policy,
    aws_route_table.public_rt,
    # aws_route_table.private_rt,
    # aws_nat_gateway.nat_gw,
    aws_internet_gateway.internet_gateway,
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
  disk_size = 50
  instance_types = [
    "t3.xlarge"
  ]
  ami_type = "AL2_x86_64"

  depends_on = [
    aws_iam_role_policy_attachment.workers_nodes_policy,
    aws_iam_role_policy_attachment.workers_registry_policy,
    aws_iam_role_policy_attachment.workers_cni_policy,
    aws_eks_cluster.cos_cluster,
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

# Management Instance Infra
# resource "aws_key_pair" "tf_key" {
#   key_name   = "user"
#   public_key = file("~/.ssh/id_rsa.pub")
# }

# select the image for the machine we'll use to run the juju client
# data "aws_ami" "ubuntu" {
#   most_recent = true

#   filter {
#     name   = "name"
#     values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
#   }

#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }

#   owners = ["099720109477"] # Canonical
# }

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
      {
        Action = [
          "ec2:*",
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
# resource "aws_instance" "management" {
#   ami                  = data.aws_ami.ubuntu.id
#   instance_type        = "t3.medium"
#   iam_instance_profile = aws_iam_instance_profile.mgmt_instance_profile.name

#   # this allows us to connect
#   vpc_security_group_ids = [aws_security_group.security.id]
#   # allow this key to ssh in there
#   key_name = aws_key_pair.tf_key.key_name

#   associate_public_ip_address = true
#   subnet_id                   = aws_subnet.subnet1.id

#   tags = {
#     Name = "juju_client"
#   }
#   depends_on = [
#     aws_eks_cluster.cos_cluster,
#     aws_eks_node_group.cos_workers,
#     aws_eks_access_entry.mgmt_access_entry,
#     aws_eks_addon.eks_ebs_addon,
#     aws_iam_role.mgmt_eks_role,
#     aws_route_table.public_rt,
#     aws_route_table.private_rt,
#     aws_nat_gateway.nat_gw,
#     aws_internet_gateway.internet_gateway,
#   ]
# }

# bootstrap juju
# resource "null_resource" "bootstrap_juju" {
#   depends_on = [aws_instance.management]

#   connection {
#     type        = "ssh"
#     host        = aws_instance.management.public_ip
#     user        = "ubuntu"
#     private_key = file("~/.ssh/id_rsa")
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "sudo snap wait system seed.loaded",
#       "sudo snap install juju --channel 3/stable",
#       "sudo snap install kubectl --classic",
#       "sudo snap install jq",
#       "sudo snap install yq",
#       "sudo apt install unzip",
#       "curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\"",
#       "unzip awscliv2.zip",
#       "sudo ./aws/install",
#       "aws eks --region ${var.region} update-kubeconfig --name ${local.cos-cluster}",
#       "/snap/juju/current/bin/juju add-k8s ${local.cos-cloud}",
#       "juju bootstrap ${local.cos-cloud} ${local.cos-controller}",
#     ]
#   }
# }


# data "external" "juju_controller_config" {
#   depends_on = [null_resource.bootstrap_juju, aws_instance.management]
#   program = ["bash", "-c", <<-EOT
#     ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@${aws_instance.management.public_ip} /bin/bash <<'REMOTE_EOF'
#     #!/bin/bash
#     set -euo pipefail

#     CONTROLLER=$(juju whoami | yq -r .Controller)
#     JUJU_DATA=$(juju show-controller "$CONTROLLER" --format json)
#     JUJU_ACCOUNTS=$(cat ~/.local/share/juju/accounts.yaml)

#     jq -n \
#       --arg username "$(echo "$JUJU_ACCOUNTS" | yq -r ".controllers.\"$CONTROLLER\".user")" \
#       --arg password "$(echo "$JUJU_ACCOUNTS" | yq -r ".controllers.\"$CONTROLLER\".password")" \
#       --arg ca_cert "$(echo "$JUJU_DATA" | jq -r '.[].details["ca-cert"]')" \
#       --arg controller_ip "$(kubectl get pods controller-0 -n controller-cos-controller -o jsonpath='{.status.podIP}')" \
#       '{
#         juju_username: $username,
#         juju_password: $password,
#         juju_ca_cert: $ca_cert,
#         juju_controller_ip: $controller_ip,
#       }'
#     REMOTE_EOF
#   EOT
#   ]
# }

# create a user that can bootstrap juju
resource "aws_iam_user" "juju_bootstrap_user" {
  name = "juju-bootstrap"
}

resource "aws_iam_user_policy" "juju_bootstrap_policy" {
  name = "juju-bootstrap-policy"
  user = aws_iam_user.juju_bootstrap_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Sid" : "JujuEC2Actions",
        Action = [
          "ec2:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        "Sid" : "JujuIAMActions",
        "Effect" : "Allow",
        "Action" : [
          "iam:AddRoleToInstanceProfile",
          "iam:CreateInstanceProfile",
          "iam:CreateRole",
          "iam:DeleteInstanceProfile",
          "iam:DeleteRole",
          "iam:DeleteRolePolicy",
          "iam:GetInstanceProfile",
          "iam:GetRole",
          "iam:ListInstanceProfiles",
          "iam:ListRolePolicies",
          "iam:ListRoles",
          "iam:PassRole",
          "iam:PutRolePolicy",
          "iam:RemoveRoleFromInstanceProfile"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "JujuSSMActions",
        "Effect" : "Allow",
        "Action" : [
          "ssm:ListInstanceAssociations",
          "ssm:UpdateInstanceInformation"
        ],
        "Resource" : "*"
      }

    ]
  })
}

resource "aws_iam_access_key" "juju_bootstrap_access_key" {
  user = aws_iam_user.juju_bootstrap_user.name
}



resource "local_sensitive_file" "aws_credentials" {
  depends_on = [aws_iam_access_key.juju_bootstrap_access_key]
  content = yamlencode({
    credentials : {
      aws : {
        bootstrap-juju : {
          auth-type : "access-key",
          access-key : aws_iam_access_key.juju_bootstrap_access_key.id,
          secret-key : aws_iam_access_key.juju_bootstrap_access_key.secret,
      } }
    }
  })
  filename = "${path.module}/credentials.yaml"
}

resource "null_resource" "bootstrap_juju" {
  depends_on = [local_sensitive_file.aws_credentials,
    aws_eks_node_group.cos_workers,
    aws_eks_addon.eks_ebs_addon,
    aws_eks_access_entry.mgmt_access_entry,
    aws_eks_access_entry.admin_access_entry,
    aws_eks_addon.eks_vpc_cni_addon,
    aws_eks_addon.eks_kube_proxy_addon,
    aws_eks_addon.eks_core_dns_addon,
    aws_eks_addon.eks_pod_identity_addon,
    aws_iam_policy.mgmt_eks_policy,
    aws_route_table_association.public_rta1,
    aws_route_table_association.public_rta2,
    aws_security_group.security,
    aws_eks_access_policy_association.mgmt_access_eks_cluster_admin,
    aws_eks_access_policy_association.admin_eks_admin_policy,
    aws_iam_role.mgmt_eks_role,
    aws_iam_instance_profile.mgmt_instance_profile,

  ]
  provisioner "local-exec" {
    when    = create
    command = <<-EOT
      juju remove-credential aws bootstrap-juju --client
      juju add-credential aws --client -f  ${local_sensitive_file.aws_credentials.filename}
      if ! juju controllers | grep -q '^${local.cos-controller}'; then
        juju bootstrap --bootstrap-constraints="instance-role=${aws_iam_instance_profile.mgmt_instance_profile.name}" aws/${var.region} ${local.cos-controller} --config vpc-id=${aws_vpc.main.id} --config vpc-id-force=true --credential bootstrap-juju
      else
        echo "controller already exists, skipping bootstrap."
      fi
      aws eks --region ${var.region} update-kubeconfig --name ${local.cos-cluster}
      /snap/juju/current/bin/juju add-k8s ${local.cos-cloud} --controller ${local.cos-controller}
      juju add-model cos ${local.cos-cloud}/${var.region}
    EOT
  }

  # provisioner "local-exec" {
  #   when    = destroy
  #   command = <<-EOT
  #     juju destroy-model cos --destroy-storage --no-prompt --force
  #     juju destroy-controller cos-controller --destroy-all-models --destroy-storage --no-prompt
  #   EOT
  # }

}

# create S3 Buckets
resource "aws_s3_bucket" "tempo_s3" {
  bucket        = "cos-tempo-bucket"
  force_destroy = true
}

resource "aws_s3_bucket" "loki_s3" {
  bucket        = "cos-loki-bucket"
  force_destroy = true
}

resource "aws_s3_bucket" "mimir_s3" {
  bucket        = "cos-mimir-bucket"
  force_destroy = true
}

# create an IAM user to access the buckets
# TODO: create 3 IAM users, one for each bucket access
resource "aws_iam_user" "s3_access" {
  name = "s3-access"
}

resource "aws_iam_user_policy" "s3_access_policy" {
  name = "s3-access-policy"
  user = aws_iam_user.s3_access.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_access_key" "s3_access_key" {
  user = aws_iam_user.s3_access.name
}


# provider "juju" {
# }

# resource "juju_model" "cos_model" {
#   depends_on = [aws_eks_node_group.cos_workers, null_resource.bootstrap_juju]
#   name       = "cos"
# }

# module "cos" {
#   depends_on = [juju_model.cos_model, aws_s3_bucket.loki_s3, aws_s3_bucket.mimir_s3, aws_s3_bucket.tempo_s3]
#   # FIXME: use the remote module
#   source       = "../../../cos"
#   model_name   = juju_model.cos_model.name
#   use_tls      = true
#   loki_bucket  = aws_s3_bucket.loki_s3.bucket
#   mimir_bucket = aws_s3_bucket.mimir_s3.bucket
#   tempo_bucket = aws_s3_bucket.tempo_s3.bucket
#   s3_endpoint  = "https://s3.${var.region}.amazonaws.com"
#   s3_user      = aws_iam_access_key.s3_access_key.id
#   s3_password  = aws_iam_access_key.s3_access_key.secret
#   cloud        = "aws"

# }



# hacky way to expose juju controller


# resource "aws_security_group" "controller_sg1" {
#   vpc_id = aws_vpc.main.id
#   ingress {
#     from_port   = 17070
#     to_port     = 17070
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

# }

# resource "aws_security_group" "controller_sg2" {
#   vpc_id = aws_vpc.main.id
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

# }

# resource "aws_lb_target_group" "controller_tg" {
#   port        = 17070
#   protocol    = "TCP"
#   target_type = "ip"
#   vpc_id      = aws_vpc.main.id
#   health_check {
#     healthy_threshold = 2
#     protocol          = "TCP"
#     port              = "traffic-port"
#     interval          = 5
#     timeout           = 5
#   }
#   lifecycle {
#     create_before_destroy = true
#   }
#   depends_on = [aws_lb.controller_public_nlb]
# }


# resource "aws_lb" "controller_public_nlb" {
#   depends_on         = [aws_route_table.public_rt]
#   name               = "controller-public-service"
#   load_balancer_type = "network"
#   internal           = false
#   subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
#   security_groups    = [aws_security_group.controller_sg1.id, aws_security_group.controller_sg2.id]

#   enable_deletion_protection       = false
#   enable_cross_zone_load_balancing = true
# }

# resource "aws_lb_listener" "controller_listener" {
#   depends_on        = [aws_lb_target_group.controller_tg]
#   load_balancer_arn = aws_lb.controller_public_nlb.arn
#   port              = 17070
#   protocol          = "TCP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.controller_tg.arn
#   }
# }

# resource "aws_lb_target_group_attachment" "controller_tg_attach" {
#   depends_on       = [data.external.juju_controller_config, aws_lb_target_group.controller_tg]
#   target_group_arn = aws_lb_target_group.controller_tg.arn
#   target_id        = data.external.juju_controller_config.result.juju_controller_ip
#   port             = 17070
# }
