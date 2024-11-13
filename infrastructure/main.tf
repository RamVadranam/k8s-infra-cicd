# main.tf

provider "aws" {
  region = var.aws_region
}

# EKS Module to provision the EKS cluster and required VPC
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = var.cluster_name
  cluster_version = "1.25"
  subnets         = var.subnets
  vpc_id          = var.vpc_id

  # Configure the worker nodes
  worker_groups = [
    {
      instance_type       = "t3.medium"
      asg_desired_capacity = 2
    }
  ]

  enable_irsa = true  # Enable IAM roles for service accounts
}
