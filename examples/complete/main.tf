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
    Environment = "production"
    Owner       = "platform"
    Project     = "container-platform"
  }

  eks_config = {
    production = {
      control_plane = {
        name    = var.cluster_name
        version = "1.35"

        vpc_config = {
          subnet_ids              = var.private_subnet_ids
          endpoint_private_access = true
          endpoint_public_access  = false
        }

        access_entries = {
          platform_admin = {
            principal_arn = var.platform_admin_role_arn
            policy_associations = {
              cluster_admin = {
                policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
                access_scope = {
                  type = "cluster"
                }
              }
            }
          }
        }

        addons = {
          coredns = {
            configuration_values = jsonencode({ replicaCount = 3 })
          }
          kube-proxy = {}
          vpc-cni = {
            resolve_conflicts_on_update = "PRESERVE"
          }
        }

        logs = {
          retention_in_days = 90
        }
      }

      node_groups = {
        system = {
          instance_types = ["m7i.large"]
          scaling_config = {
            desired_size = 2
            min_size     = 2
            max_size     = 4
          }
          labels = {
            workload = "system"
          }
          taints = {
            critical = {
              key    = "CriticalAddonsOnly"
              effect = "NO_SCHEDULE"
            }
          }
          launch_template = {
            block_device_mappings = [{
              device_name = "/dev/xvda"
              ebs = {
                volume_size = 50
                volume_type = "gp3"
              }
            }]
          }
        }

        applications = {
          capacity_type  = "SPOT"
          instance_types = ["m7i.large", "m7a.large", "m6i.large"]
          scaling_config = {
            desired_size = 3
            min_size     = 1
            max_size     = 20
          }
          labels = {
            workload = "applications"
          }
        }
      }
    }
  }
}

output "cluster" {
  description = "Created EKS cluster attributes."
  value       = module.eks.clusters["production"]
}
