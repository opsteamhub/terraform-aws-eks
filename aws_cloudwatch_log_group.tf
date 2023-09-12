resource "aws_cloudwatch_log_group" "eks-log-group" {
  for_each = var.eks_config

  name              = format("/aws/eks/cluster/%s", local.cluster_name[each.key])
  retention_in_days = each.value["control_plane"]["logs"]["retention_in_days"]
  tags              = merge(
    each.value["control_plane"]["tags"],
    each.value["control_plane"]["logs"]["tags"]
  )
}