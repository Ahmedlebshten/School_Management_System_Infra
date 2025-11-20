# ============================================================================
# ROOT MODULE - terraform.tfvars
# ============================================================================

# Project Configuration
project_name = "hello-devops"
environment  = "production"
aws_region   = "us-east-1"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
enable_nat_gateway   = true
single_nat_gateway   = false # Use one NAT per AZ for HA
enable_dns_hostnames = true
enable_dns_support   = true

# EKS Configuration
cluster_version           = "1.30"
node_group_desired_size   = 2 # 2 nodes per AZ for HA
node_group_min_size       = 1
node_group_max_size       = 4
node_instance_types       = ["t3.medium"]
node_disk_size            = 20
enable_cluster_encryption = true

# Control plane logging
cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

# Security
allowed_ssh_ips = ["0.0.0.0/0"] # Change this to your IP range

# IAM ACCESS CONFIGURATION
additional_iam_users = [
  {
    userarn  = "arn:aws:iam::420606830171:role/Jenkins-EC2-Role"
    username = "jenkins-ec2-role"
    groups   = ["system:masters"]
  }
]

# Tags
tags = {
  Project     = "hello-devops"
  Environment = "production"
  ManagedBy   = "Terraform"
  Owner       = "DevOps-Team"
}
