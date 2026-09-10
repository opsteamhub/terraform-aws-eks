resource "aws_cloudwatch_log_group" "cluster" {
  for_each = local.clusters

  name              = "/aws/eks/${each.value.control_plane.name}/cluster"
  retention_in_days = each.value.control_plane.logs.retention_in_days
  kms_key_id        = each.value.control_plane.logs.kms_key_id
  tags              = local.cluster_tags[each.key]
}
