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

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 3, 1)
  # map_public_ip_on_launch
}

# TODO: we should lock this down and verify the users
resource "aws_security_group" "security" {
  name = "allow-us"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
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

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
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


resource "aws_key_pair" "tf_key" {
  key_name   = "pietro"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}

# create a machine with that image
resource "aws_instance" "management" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  # this allows us to connect
  security_groups = ["${aws_security_group.security.id}"]
  # allow this key to ssh in there
  key_name = aws_key_pair.tf_key.key_name

  associate_public_ip_address = true
  subnet_id = aws_subnet.main.id

  # put a cloud-init in there
  user_data  = file("./juju-bootstrap.yaml")

  tags = {
    Name = "juju_client"
  }
}

# setup 3-node EKS


# OUTPUTS
output "public-dns" {
    value = aws_instance.management.*.public_dns[0]
}
output "public-ip" {
    value = aws_instance.management.public_ip
}