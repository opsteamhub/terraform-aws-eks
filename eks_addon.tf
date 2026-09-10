resource "aws_eks_addon" "this" {
  for_each = local.addons

  cluster_name                = aws_eks_cluster.this[each.value.cluster_key].name
  addon_name                  = each.value.addon_name
  addon_version               = each.value.addon_version
  configuration_values        = each.value.configuration_values
  preserve                    = each.value.preserve
  resolve_conflicts_on_create = each.value.resolve_conflicts_on_create
  resolve_conflicts_on_update = each.value.resolve_conflicts_on_update
  service_account_role_arn    = each.value.service_account_role_arn
  tags = merge(
    local.cluster_tags[each.value.cluster_key],
    each.value.tags,
    { Name = "${aws_eks_cluster.this[each.value.cluster_key].name}-${each.value.addon_name}" }
  )
}
