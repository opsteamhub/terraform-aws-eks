module "multi_nodegroup_eks" {
  source = "../"

  eks_config = {
    "multi-nodegroup" = {
      control_plane = {
        name    = "multi-nodegroup-eks"
        version = "1.27"
        
        vpc_config = {
          vpc_id     = "vpc-12345678"
          subnet_ids = ["subnet-private-1", "subnet-private-2", "subnet-private-3"]
        }
        
        enabled_cluster_log_types = ["api", "audit", "authenticator"]
        
        encryption_config = {
          resources = ["secrets"]
          provider = {
            create = true
          }
        }
      }
      
      node_groups = {
        # Node group para sistema (CoreDNS, kube-proxy, etc.)
        "system" = {
          instance_types = ["t3.small", "t3.medium"]
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
          
          subnet_ids = ["subnet-private-1", "subnet-private-2"]
        }
        
        # Node group para aplicações web
        "web-apps" = {
          instance_types = ["t3.medium", "t3.large"]
          capacity_type  = "ON_DEMAND"
          
          scaling_config = {
            desired_size = 3
            min_size     = 2
            max_size     = 10
          }
          
          labels = {
            "node-type" = "web"
            "workload"  = "web-applications"
          }
          
          launch_template = {
            block_device_mappings = [
              {
                device_name = "/dev/xvda"
                ebs = {
                  volume_size = 50
                  volume_type = "gp3"
                  encrypted   = true
                }
              }
            ]
          }
          
          subnet_ids = ["subnet-private-1", "subnet-private-2", "subnet-private-3"]
        }
        
        # Node group para processamento de dados (CPU intensivo)
        "data-processing" = {
          instance_types = ["c5.xlarge", "c5.2xlarge"]
          capacity_type  = "SPOT"
          
          scaling_config = {
            desired_size = 0
            min_size     = 0
            max_size     = 20
          }
          
          labels = {
            "node-type" = "compute"
            "workload"  = "data-processing"
          }
          
          taint = [
            {
              key    = "workload"
              value  = "data-processing"
              effect = "NO_SCHEDULE"
            }
          ]
          
          launch_template = {
            instance_requirements = {
              vcpu_count = {
                min = 4
                max = 16
              }
              memory_mib = {
                min = 8192
              }
              cpu_manufacturers = ["intel", "amd"]
            }
            
            instance_market_options = {
              market_type = "spot"
              spot_options = {
                instance_interruption_behavior = "terminate"
              }
            }
          }
          
          subnet_ids = ["subnet-private-1", "subnet-private-2"]
        }
        
        # Node group para machine learning (GPU)
        "ml-gpu" = {
          instance_types = ["g4dn.xlarge", "g4dn.2xlarge"]
          capacity_type  = "ON_DEMAND"
          
          scaling_config = {
            desired_size = 0
            min_size     = 0
            max_size     = 5
          }
          
          labels = {
            "node-type"        = "gpu"
            "workload"         = "machine-learning"
            "nvidia.com/gpu"   = "true"
          }
          
          taint = [
            {
              key    = "nvidia.com/gpu"
              value  = "true"
              effect = "NO_SCHEDULE"
            }
          ]
          
          launch_template = {
            # AMI otimizada para GPU
            ami = {
              ami_filters = [
                {
                  name   = "name"
                  values = ["amazon-eks-gpu-node-1.27*"]
                }
              ]
              owners = ["amazon"]
            }
            
            block_device_mappings = [
              {
                device_name = "/dev/xvda"
                ebs = {
                  volume_size = 100
                  volume_type = "gp3"
                  encrypted   = true
                }
              }
            ]
          }
          
          subnet_ids = ["subnet-private-1", "subnet-private-2"]
        }
        
        # Node group para bancos de dados (storage otimizado)
        "database" = {
          instance_types = ["r5.large", "r5.xlarge"]
          capacity_type  = "ON_DEMAND"
          
          scaling_config = {
            desired_size = 1
            min_size     = 1
            max_size     = 3
          }
          
          labels = {
            "node-type" = "database"
            "workload"  = "stateful-services"
          }
          
          taint = [
            {
              key    = "workload"
              value  = "database"
              effect = "NO_SCHEDULE"
            }
          ]
          
          launch_template = {
            # Storage adicional para dados
            block_device_mappings = [
              {
                device_name = "/dev/xvda"
                ebs = {
                  volume_size = 50
                  volume_type = "gp3"
                  encrypted   = true
                }
              },
              {
                device_name = "/dev/xvdb"
                ebs = {
                  volume_size = 200
                  volume_type = "gp3"
                  encrypted   = true
                  iops        = 4000
                  throughput  = 250
                }
              }
            ]
          }
          
          subnet_ids = ["subnet-private-1", "subnet-private-2"]
        }
      }
    }
  }
}

# Outputs para cada tipo de node group
output "system_nodegroup_arn" {
  description = "ARN do node group de sistema"
  value       = module.multi_nodegroup_eks.node_groups["system"].arn
}

output "web_nodegroup_arn" {
  description = "ARN do node group de aplicações web"
  value       = module.multi_nodegroup_eks.node_groups["web-apps"].arn
}

output "gpu_nodegroup_arn" {
  description = "ARN do node group GPU para ML"
  value       = module.multi_nodegroup_eks.node_groups["ml-gpu"].arn
}