module "basic_eks_cluster" {
  source = "../"

  eks_config = {
    "basic-cluster" = {
      control_plane = {
        name    = "basic-eks-cluster"
        version = "1.27"
        
        vpc_config = {
          vpc_id     = "vpc-12345678"
          subnet_ids = ["subnet-12345", "subnet-67890"]
        }
        
        enabled_cluster_log_types = ["api", "audit"]
      }
      
      node_groups = {
        "workers" = {
          instance_types = ["t3.medium"]
          capacity_type  = "ON_DEMAND"
          
          scaling_config = {
            desired_size = 2
            min_size     = 1
            max_size     = 5
          }
          
          subnet_ids = ["subnet-12345", "subnet-67890"]
        }
      }
    }
  }
}