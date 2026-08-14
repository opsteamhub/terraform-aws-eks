terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "eks" {
  source = "../.."

  default_tags = {
    Environment = var.environment
    Owner       = var.owner
    Project     = var.project
  }

  eks_config = {
    primary = {
      control_plane = {
        name = var.cluster_name
        vpc_config = {
          subnet_ids = var.private_subnet_ids
        }
      }

      node_groups = {
        system = {}
      }
    }
  }
}

output "cluster_name" {
  description = "Created EKS cluster name."
  value       = module.eks.cluster_names["primary"]
}
