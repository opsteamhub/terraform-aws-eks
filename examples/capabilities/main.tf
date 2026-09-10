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

        capabilities = {
          ack = {
            type     = "ACK"
            role_arn = var.ack_capability_role_arn
          }

          argocd = {
            type = "ARGOCD"
            argo_cd = {
              aws_idc = {
                idc_instance_arn = var.idc_instance_arn
                idc_region       = var.idc_region
              }
              rbac_role_mappings = {
                administrators = {
                  role = "ADMIN"
                  identities = [{
                    id   = var.idc_admin_group_id
                    type = "SSO_GROUP"
                  }]
                }
              }
            }
          }

          kro = {
            type = "KRO"
          }
        }
      }

      node_groups = {
        system = {}
      }
    }
  }
}

output "capabilities" {
  description = "Created EKS Capabilities, including the Argo CD server URL when available."
  value       = module.eks.capabilities
}
