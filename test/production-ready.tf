locals {
  cluster_name = "production-eks"
  vpc_id       = "vpc-12345678"
  
  private_subnets = ["subnet-private-1", "subnet-private-2", "subnet-private-3"]
  public_subnets  = ["subnet-public-1", "subnet-public-2", "subnet-public-3"]
  
  common_tags = {
    Environment = "production"
    Team        = "platform"
    Project     = "kubernetes-platform"
  }
}

module "production_eks" {
  source = "../"

  eks_config = {
    "production" = {
      control_plane = {
        name    = local.cluster_name
        version = "1.27"
        
        vpc_config = {
          vpc_id                  = local.vpc_id
          subnet_ids              = local.private_subnets
          endpoint_private_access = true
          endpoint_public_access  = true
          public_access_cidrs     = ["10.0.0.0/8"]
        }
        
        enabled_cluster_log_types = [
          "api", "audit", "authenticator", 
          "controllerManager", "scheduler"
        ]
        
        logs = {
          retention_in_days = 30
        }
        
        encryption_config = {
          resources = ["secrets"]
          provider = {
            create                  = true
            kms_key_description     = "EKS production cluster encryption"
            enable_kms_key_rotation = true
          }
        }
        
        addons = [
          {
            addon_name    = "vpc-cni"
            addon_version = "v1.12.6-eksbuild.2"
            resolve_conflicts = "OVERWRITE"
          },
          {
            addon_name    = "coredns"
            addon_version = "v1.10.1-eksbuild.1"
            configuration_values = jsonencode({
              replicaCount = 4
              resources = {
                limits = {
                  cpu    = "100m"
                  memory = "150Mi"
                }
                requests = {
                  cpu    = "30m"
                  memory = "30Mi"
                }
              }
            })
          },
          {
            addon_name    = "kube-proxy"
            addon_version = "v1.27.1-eksbuild.1"
            resolve_conflicts = "OVERWRITE"
          }
        ]
        
        tags = local.common_tags
      }
      
      node_groups = {
        "system" = {
          instance_types = ["t3.medium"]
          capacity_type  = "ON_DEMAND"
          
          scaling_config = {
            desired_size = 2
            min_size     = 2
            max_size     = 4
          }
          
          labels = {
            "node-type" = "system"
            "workload"  = "system-pods"
          }
          
          taint = [
            {
              key    = "node-type"
              value  = "system"
              effect = "NO_SCHEDULE"
            }
          ]
          
          subnet_ids = local.private_subnets
          tags       = merge(local.common_tags, { NodeGroup = "system" })
        }
        
        "applications" = {
          instance_types = ["t3.large", "t3.xlarge"]
          capacity_type  = "ON_DEMAND"
          
          scaling_config = {
            desired_size = 3
            min_size     = 2
            max_size     = 20
          }
          
          labels = {
            "node-type" = "application"
            "workload"  = "user-pods"
          }
          
          launch_template = {
            block_device_mappings = [
              {
                device_name = "/dev/xvda"
                ebs = {
                  volume_size           = 100
                  volume_type           = "gp3"
                  encrypted             = true
                  delete_on_termination = true
                }
              }
            ]
            
            metadata_options = {
              http_endpoint = "enabled"
              http_tokens   = "required"
              http_put_response_hop_limit = 2
            }
          }
          
          subnet_ids = local.private_subnets
          tags       = merge(local.common_tags, { NodeGroup = "applications" })
        }
      }
    }
  }
}

# Outputs para monitoramento
output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.production_eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.production_eks.cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.production_eks.cluster_certificate_authority_data
  sensitive   = true
}