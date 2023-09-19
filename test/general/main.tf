module "eks_general_config" {
  source = "../.."
  eks_config = {
    "opsteam-tst-eks-0002" = {
      node_groups = {
        y = {
          capacity_type = "spot"
          launch_template = {
            disable_api_stop = false
            tag_specifications = [
              {
                resource_type = "instance"
                tags          = { "a" = 5 }
              }
            ]
          }
        }
      #  x = {
      #   # "iam_role" = {
      #   #   override_policy_attachments = true
      #   #   "policy_attachments" = ["AdministratorAccess"]
      #   # }
      #  }
      }
    }    
  }
}


output "test" {
  value = module.eks_general_config.teste
}
