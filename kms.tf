#
# Address the KMS deploy to be used by the EKS
#
module "kms" {
  source   = "git@github.com:opsteamhub/terraform-aws-kms.git"
  kms_config = { 
    for k,v in var.eks_config:
      k => {
        grant = [
          {
            grantee_principal = coalesce(
              v["control_plane"]["iam_role"]["role_arn"],
              aws_iam_role.eks_cp_iamrole[k].arn,
            )
          }
        ]
      }
  }
  depends_on = [ aws_iam_role.eks_cp_iamrole, aws_cloudwatch_log_group.eks-log-group]
}