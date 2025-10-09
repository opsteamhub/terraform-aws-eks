module "spot_eks_cluster" {
  source = "../"

  eks_config = {
    "spot-cluster" = {
      control_plane = {
        name    = "spot-eks-cluster"
        version = "1.27"
        
        vpc_config = {
          vpc_id     = "vpc-12345678"
          subnet_ids = ["subnet-private-1", "subnet-private-2"]
        }
        
        enabled_cluster_log_types = ["api", "audit"]
      }
      
      node_groups = {
        "spot-workers" = {
          capacity_type = "SPOT"
          
          # Usar instance requirements para maior flexibilidade
          launch_template = {
            instance_requirements = {
              memory_mib = {
                min = 4096  # Mínimo 4GB RAM
                max = 16384 # Máximo 16GB RAM
              }
              vcpu_count = {
                min = 2
                max = 8
              }
              instance_generations = ["current"]
              
              # Permitir várias famílias de instância para maior disponibilidade
              allowed_instance_types = [
                "t3.medium", "t3.large", "t3.xlarge",
                "t3a.medium", "t3a.large", "t3a.xlarge",
                "m5.large", "m5.xlarge",
                "m5a.large", "m5a.xlarge"
              ]
            }
            
            # Configuração de spot instances
            instance_market_options = {
              market_type = "spot"
              spot_options = {
                instance_interruption_behavior = "terminate"
                spot_instance_type             = "one-time"
              }
            }
            
            # Storage otimizado
            block_device_mappings = [
              {
                device_name = "/dev/xvda"
                ebs = {
                  volume_size           = 50
                  volume_type           = "gp3"
                  encrypted             = true
                  delete_on_termination = true
                  iops                  = 3000
                  throughput            = 125
                }
              }
            ]
          }
          
          scaling_config = {
            desired_size = 3
            min_size     = 1
            max_size     = 10
          }
          
          # Labels para identificar nodes spot
          labels = {
            "node-type"     = "spot"
            "capacity-type" = "spot"
            "workload"      = "batch-processing"
          }
          
          # Taint para que apenas workloads tolerantes a spot sejam agendados
          taint = [
            {
              key    = "spot-instance"
              value  = "true"
              effect = "NO_SCHEDULE"
            }
          ]
          
          subnet_ids = ["subnet-private-1", "subnet-private-2"]
        }
        
        # Node group on-demand para workloads críticos
        "on-demand-critical" = {
          instance_types = ["t3.medium"]
          capacity_type  = "ON_DEMAND"
          
          scaling_config = {
            desired_size = 1
            min_size     = 1
            max_size     = 3
          }
          
          labels = {
            "node-type"     = "critical"
            "capacity-type" = "on-demand"
            "workload"      = "critical-services"
          }
          
          subnet_ids = ["subnet-private-1", "subnet-private-2"]
        }
      }
    }
  }
}

# Exemplo de deployment que tolera spot instances
resource "kubernetes_deployment" "spot_tolerant_app" {
  metadata {
    name = "spot-tolerant-app"
    labels = {
      app = "spot-tolerant-app"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "spot-tolerant-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "spot-tolerant-app"
        }
      }

      spec {
        # Tolerância para spot instances
        toleration {
          key      = "spot-instance"
          operator = "Equal"
          value    = "true"
          effect   = "NoSchedule"
        }
        
        # Node selector para spot instances
        node_selector = {
          "capacity-type" = "spot"
        }
        
        container {
          image = "nginx:1.21"
          name  = "nginx"
          
          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }
}