module "eks_general_config" {
  source = "../.."
  eks_config = {
    "opsteam-tst-eks-0002" = {
      #node_groups = {
      #  y = {  
      # }
      #  x = {
      #   # "iam_role" = {
      #   #   override_policy_attachments = true
      #   #   "policy_attachments" = ["AdministratorAccess"]
      #   # }
      #  }
      #}
    }    
  }
}


output "test" {
  value = module.eks_general_config.teste
}
