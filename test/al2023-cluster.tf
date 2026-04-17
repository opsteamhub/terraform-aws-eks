##
## Example: EKS cluster with AL2023 node groups (EKS 1.35+)
##
## AL2 (Amazon Linux 2) is not supported on EKS 1.35+.
## You must use AL2023 and set ami_type accordingly.
##
## Key differences from AL2:
##   - ami_type must be "AL2023_x86_64_STANDARD" (or AL2023_ARM_64_STANDARD for ARM)
##   - The module automatically uses nodeadm (NodeConfig) userdata instead of bootstrap.sh
##   - AMI filter must target "amazon-eks-node-al2023-*" images
##

locals {
  cluster_name_al2023 = "my-eks-cluster"
  vpc_id_al2023       = "vpc-12345678"
  private_subnets_al2023 = ["subnet-private-1", "subnet-private-2", "subnet-private-3"]

  common_tags_al2023 = {
    Environment = "development"
    Team        = "platform"
  }
}

module "eks_al2023" {
  source = "../"

  eks_config = {
    "my-cluster" = {
      control_plane = {
        name    = local.cluster_name_al2023
        version = "1.35"

        vpc_config = {
          vpc_id                  = local.vpc_id_al2023
          subnet_ids              = local.private_subnets_al2023
          endpoint_private_access = true
          endpoint_public_access  = true
        }

        addons = [
          {
            addon_name        = "vpc-cni"
            addon_version     = "v1.19.2-eksbuild.1"
            resolve_conflicts = "OVERWRITE"
          },
          {
            addon_name        = "coredns"
            addon_version     = "v1.11.4-eksbuild.2"
            resolve_conflicts = "OVERWRITE"
          },
          {
            addon_name        = "kube-proxy"
            addon_version     = "v1.35.3-eksbuild.1"
            resolve_conflicts = "OVERWRITE"
          }
        ]

        tags = local.common_tags_al2023
      }

      node_groups = {
        ## AL2023 node group
        "services" = {
          ami_type       = "AL2023_x86_64_STANDARD"
          version        = "1.35"
          instance_types = ["t3.medium"]
          capacity_type  = "ON_DEMAND"

          launch_template = {
            ami = {
              ami_filters = [
                {
                  name   = "name"
                  values = ["amazon-eks-node-al2023-x86_64-standard-1.35-*"]
                }
              ]
              owners = ["amazon"]
            }
          }

          scaling_config = {
            desired_size = 2
            min_size     = 1
            max_size     = 10
          }

          labels = {
            "node-type" = "services"
          }

          subnet_ids = local.private_subnets_al2023
          tags       = local.common_tags_al2023
          enable_instance_tags = true
        }

        ## Karpenter node group (AL2023) with taint
        "karpenter" = {
          ami_type       = "AL2023_x86_64_STANDARD"
          version        = "1.35"
          instance_types = ["t3.medium"]
          capacity_type  = "ON_DEMAND"

          launch_template = {
            ami = {
              ami_filters = [
                {
                  name   = "name"
                  values = ["amazon-eks-node-al2023-x86_64-standard-1.35-*"]
                }
              ]
              owners = ["amazon"]
            }
          }

          scaling_config = {
            desired_size = 1
            min_size     = 1
            max_size     = 5
          }

          taint = [
            {
              key    = "karpenter"
              value  = "true"
              effect = "NO_SCHEDULE"
            }
          ]

          subnet_ids = local.private_subnets_al2023
          tags       = local.common_tags_al2023
          enable_instance_tags = true
        }
      }
    }
  }
}
