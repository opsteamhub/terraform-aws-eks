terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.25, < 7.0"
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
        name      = var.cluster_name
        auto_mode = {}

        vpc_config = {
          subnet_ids = var.private_subnet_ids
        }
      }
    }
  }
}

output "cluster" {
  description = "Created EKS cluster attributes."
  value       = module.eks.clusters["primary"]
}

output "auto_mode" {
  description = "Resolved EKS Auto Mode configuration."
  value       = module.eks.auto_mode["primary"]
}
