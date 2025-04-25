provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
  state = "available"
}
locals {
  cos-cluster-name = "cos-cluster"
}

## ====================================================
## Network infra
## ====================================================
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# To allow workloads running on ec2 nodes to access the public internet (e.g: to pull OCI images)
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.main.id
}

# To deploy a 3-node eks cluster, it's recommended to spread them across at least 2 subnets in different AZs.
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, 1)
  availability_zone       = element(data.aws_availability_zones.available.names, 0)
  map_public_ip_on_launch = true
  tags = {
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, 2)
  availability_zone       = element(data.aws_availability_zones.available.names, 1)
  map_public_ip_on_launch = true
  tags = {
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
}


resource "aws_route_table_association" "public_rta_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rta_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

## ====================================================
## Kubernetes infra
## ====================================================

# a role that eks cluster can assume
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

# eks role needs the below permissions
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
  name                          = local.cos-cluster-name
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
      aws_subnet.public_subnet_1.id,
      aws_subnet.public_subnet_2.id,
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cos_cluster_policy,
    aws_iam_role_policy_attachment.cos_cluster_network_policy,
    aws_iam_role_policy_attachment.cos_cluster_lb_policy,
    aws_iam_role_policy_attachment.cos_cluster_storage_policy,
    aws_iam_role_policy_attachment.cos_cluster_compute_policy,
    aws_route_table.public_rt,
    aws_internet_gateway.internet_gateway,
  ]
}

# enable network communication
resource "aws_eks_addon" "eks_kube_proxy_addon" {
  cluster_name = aws_eks_cluster.cos_cluster.name
  addon_name   = "kube-proxy"
}

# enable name resolution for all pods
resource "aws_eks_addon" "eks_core_dns_addon" {
  cluster_name = aws_eks_cluster.cos_cluster.name
  addon_name   = "coredns"
  depends_on   = [aws_eks_node_group.cos_workers]
}

# enables assigning a private IPv4 from your VPC to each pod.
resource "aws_eks_addon" "eks_vpc_cni_addon" {
  cluster_name = aws_eks_cluster.cos_cluster.name
  addon_name   = "vpc-cni"
}

# provides the ability to manage credentials for your application
# needed for EBS CSI driver
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


# enable Amazon EBS CSI driver.
# Give access to "ebs-csi-controller-sa" SA to provision and manage Amazon EBS volumes.
resource "aws_eks_addon" "eks_ebs_addon" {
  cluster_name = aws_eks_cluster.cos_cluster.name
  addon_name   = "aws-ebs-csi-driver"
  pod_identity_association {
    role_arn        = aws_iam_role.eks_ebs_role.arn
    service_account = "ebs-csi-controller-sa"
  }
  depends_on = [aws_eks_node_group.cos_workers]
}

# Worker nodes need the below permissions
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

# create 3 AWS-managed worker nodes 
resource "aws_eks_node_group" "cos_workers" {
  cluster_name    = aws_eks_cluster.cos_cluster.name
  node_group_name = "cos-workers"
  node_role_arn   = aws_iam_role.workers_role.arn
  subnet_ids = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id,
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

## ====================================================
## Bootstrap Juju
## ====================================================

# Authorise the current user to access the K8s cluster resources (i.e K8s RBAC)
# needed for a later step (i.e juju add-k8s)
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

# create a role for the juju controller (i.e an ec2 instance) 
# with the necessary permissions to manage juju resources that interact with AWS resources.
resource "aws_iam_role" "juju_controller_role" {
  name = "juju-controller-role"
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

# permissions needed: https://discourse.charmhub.io/t/juju-aws-permissions/5307
resource "aws_iam_policy" "juju_controller_policy" {
  name = "juju-controller-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Sid" : "JujuEC2Actions",
        Action = [
          "ec2:AssociateIamInstanceProfile",
          "ec2:AttachVolume",
          "ec2:AuthoriseSecurityGroupIngress",
          "ec2:CreateSecurityGroup",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:DeleteSecurityGroup",
          "ec2:DeleteVolume",
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeIamInstanceProfileAssociations",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "ec2:DescribeVolumes",
          "ec2:DescribeVpcs",
          "ec2:DetachVolume",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RunInstances",
          "ec2:TerminateInstances"
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

resource "aws_iam_role_policy_attachment" "juju_controller_policy_attach" {
  role       = aws_iam_role.juju_controller_role.name
  policy_arn = aws_iam_policy.juju_controller_policy.arn
}

resource "aws_iam_instance_profile" "juju_ctrl_instance_profile" {
  name = "juju-ctrl-instance-profile"
  role = aws_iam_role.juju_controller_role.name
}

# Authorise the juju controller to access the K8s cluster resources (i.e K8s RBAC)
resource "aws_eks_access_policy_association" "ctrl_access_eks_admin" {
  cluster_name  = aws_eks_cluster.cos_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
  principal_arn = aws_iam_role.juju_controller_role.arn

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_policy_association" "ctrl_access_eks_cluster_admin" {
  cluster_name  = aws_eks_cluster.cos_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.juju_controller_role.arn

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_entry" "juju_controller_access_entry" {
  cluster_name  = aws_eks_cluster.cos_cluster.name
  principal_arn = aws_iam_role.juju_controller_role.arn
}


# create an IAM user with permissions that can bootstrap a juju controller on aws.
# The managed role used to run this terraform doesn't work for some reason.
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
        Action = [
          "ec2:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
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
    ]
  })

}

resource "aws_iam_access_key" "juju_bootstrap_access_key" {
  user = aws_iam_user.juju_bootstrap_user.name
}

# to bootstrap a controller on aws, we need to provide the aws credentials
# through a credentials.yaml file
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
  filename = "${path.root}/.terraform/tmp/credentials.yaml"
}


# run local juju commands to bootstrap a juju controller using aws_iam_user.juju_bootstrap_user credentials
# then, when the controller is running, it will use the aws_iam_instance_profile.juju_ctrl_instance_profile
# to give the controller access to manage AWS resources
resource "null_resource" "bootstrap_juju" {

  triggers = {
    # uncomment if you need to force destroy then create
    # once           = timestamp()
    cos-controller = var.cos_controller_name
  }

  depends_on = [local_sensitive_file.aws_credentials,
    aws_eks_node_group.cos_workers,
    aws_eks_addon.eks_ebs_addon,
    aws_eks_access_entry.juju_controller_access_entry,
    aws_eks_access_entry.admin_access_entry,
    aws_eks_addon.eks_vpc_cni_addon,
    aws_eks_addon.eks_kube_proxy_addon,
    aws_eks_addon.eks_core_dns_addon,
    aws_eks_addon.eks_pod_identity_addon,
    aws_iam_policy.juju_controller_policy,
    aws_route_table_association.public_rta_1,
    aws_route_table_association.public_rta_2,
    aws_eks_access_policy_association.ctrl_access_eks_cluster_admin,
    aws_eks_access_policy_association.admin_eks_admin_policy,
    aws_iam_role.juju_controller_role,
    aws_iam_instance_profile.juju_ctrl_instance_profile,
    aws_iam_role_policy_attachment.juju_controller_policy_attach,
    aws_iam_role_policy_attachment.eks_ebs_policy,
    aws_eks_access_policy_association.ctrl_access_eks_admin,
    aws_iam_user_policy.juju_bootstrap_policy,
    aws_eks_access_policy_association.admin_eks_cluster_admin_policy,
  ]

  provisioner "local-exec" {
    when    = create
    command = <<-EOT
      juju remove-credential aws bootstrap-juju --client
      juju add-credential aws --client -f  ${local_sensitive_file.aws_credentials.filename}

      if ! juju controllers | grep -q '^${var.cos_controller_name}'; then
        juju bootstrap --bootstrap-constraints="instance-role=${aws_iam_instance_profile.juju_ctrl_instance_profile.name}" aws/${var.region} ${var.cos_controller_name} --config vpc-id=${aws_vpc.main.id} --config vpc-id-force=true --credential bootstrap-juju
      else
        echo "controller already exists, skipping bootstrap."
      fi
      aws eks --region ${var.region} update-kubeconfig --name ${local.cos-cluster-name}
      /snap/juju/current/bin/juju add-k8s ${var.cos_cloud_name} --controller ${var.cos_controller_name}
      juju add-model ${var.cos_model_name} ${var.cos_cloud_name}/${var.region}
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      
      if juju controllers | grep -q '^${self.triggers.cos-controller}'; then
        juju kill-controller ${self.triggers.cos-controller} --timeout 0 --no-prompt
      else
        echo "Skipping controller deletion."
      fi
    EOT
  }
}


## ====================================================
## Create S3 buckets
## ====================================================

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

# currently, our charms require the existence of an S3 access key and secret key 
# and we can only obtain them through an IAM user.
# create an IAM user to access the buckets.
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

