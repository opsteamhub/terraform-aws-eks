data "aws_partition" "session" {}
data "aws_caller_identity" "session" {}

data "aws_iam_session_context" "session" {
  arn = data.aws_caller_identity.session.arn
}

#
# Retrieving VPC IDs from 
#
data "aws_vpcs" "eks-vpc" {
  for_each = var.eks_config

  dynamic "filter" {  
    for_each = coalesce(
      try(
        each.value["control_plane"]["vpc_config"]["vpc_filter"],
        null
      ),
      [
        {
          name = format(
            "tag:ops.team/eks/cluster/%s", local.cluster_id[each.key]
          )
          values = toset([true]) 
        }
      ]
    )
    content {
      name   = filter.value["name"]
      values = filter.value["values"]
    }
  }

  lifecycle {

   #
   # It is important notice that the true return match with the Error condition output.
   # Each EKS should have just ONE VPC with a tag matching.
   #
    postcondition {
      condition = (
        can(
          zipmap(
            [
              for k, v in self:
                k
            ],
            [
              for k, v in self:
                v["ids"]
            ]
          ) 
        ) ?
          false
        : 
          true
      )
      error_message = "There are more than one VPC with the same tag. It is not permitted."
    }
  }
}