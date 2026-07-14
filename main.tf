terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags       = { Name = "lab1-vpc" }
}

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags                    = { Name = "lab1-sn" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "lab1-ig" }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "lab1-rt" }

}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

resource "aws_security_group" "sg_allow_egress" {
  name        = "allow_ec2-ssm-sg"
  description = "Permite salida a internet para agente SSM"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "ec2-ssm-sg" }
}

resource "aws_vpc_security_group_egress_rule" "allow_all" {
  security_group_id = aws_security_group.sg_allow_egress.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 0
  to_port     = 0
  ip_protocol = "-1"
}

resource "aws_s3_bucket" "main" {
  bucket = "my-unique-bucket-name-1234567890-nashe"

  tags = { Name = "lab1-s3-bucket" }
}

resource "aws_s3_object" "secreto" {
  bucket = aws_s3_bucket.main.bucket
  key    = "secreto.txt"
  source = "secreto.txt"
}

resource "aws_iam_role" "AppServerRole" {
  name = "AppServerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "app_server_profile" {
  name = "app_server_profile"
  role = aws_iam_role.AppServerRole.name
}

resource "aws_iam_role_policy_attachment" "app_server_ssm" {
  role       = aws_iam_role.AppServerRole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "app_server_s3_read" {
  role       = aws_iam_role.AppServerRole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_role" "DeployerRole" {
  name = "DeployerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "deployer_permissions" {
  name = "DeployerPermissions"
  role = aws_iam_role.DeployerRole.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "RunInstances"
        Effect   = "Allow"
        Action   = "ec2:RunInstances"
        Resource = "*"
      },
      {
        Sid      = "PassRoleToAppServer"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.AppServerRole.arn
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ec2.amazonaws.com"
          }
        }
      }
    ]
  })
}
