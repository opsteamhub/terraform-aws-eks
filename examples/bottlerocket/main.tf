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
        name = var.cluster_name
        vpc_config = {
          subnet_ids = var.private_subnet_ids
        }
      }

      node_groups = {
        bottlerocket = {
          ami_type       = "BOTTLEROCKET_x86_64"
          instance_types = ["m7i.large"]

          launch_template = {
            user_data = <<-TOML
              [settings.kubernetes]
              max-pods = 42
            TOML
          }
        }
      }
    }
  }
}

output "node_group" {
  description = "Created Bottlerocket managed node group attributes."
  value       = module.eks.node_groups["primary||bottlerocket"]
}
