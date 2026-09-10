resource "aws_eks_access_entry" "this" {
  for_each = local.access_entries

  cluster_name      = aws_eks_cluster.this[each.value.cluster_key].name
  principal_arn     = each.value.principal_arn
  type              = each.value.type
  kubernetes_groups = length(each.value.kubernetes_groups) > 0 ? sort(tolist(each.value.kubernetes_groups)) : null
  user_name         = each.value.username
  tags = merge(
    local.cluster_tags[each.value.cluster_key],
    { Name = "${aws_eks_cluster.this[each.value.cluster_key].name}-${each.value.entry_name}" }
  )
}

resource "aws_eks_access_policy_association" "this" {
  for_each = local.access_policy_associations

  cluster_name  = aws_eks_cluster.this[each.value.cluster_key].name
  policy_arn    = each.value.policy_arn
  principal_arn = aws_eks_access_entry.this[each.value.entry_key].principal_arn

  access_scope {
    type       = each.value.access_scope.type
    namespaces = length(each.value.access_scope.namespaces) > 0 ? sort(tolist(each.value.access_scope.namespaces)) : null
  }
}

resource "aws_eks_pod_identity_association" "this" {
  for_each = local.pod_identity_associations

  cluster_name         = aws_eks_cluster.this[each.value.cluster_key].name
  namespace            = each.value.namespace
  service_account      = each.value.service_account
  role_arn             = each.value.role_arn
  target_role_arn      = each.value.target_role_arn
  disable_session_tags = each.value.disable_session_tags
  policy               = each.value.policy
  tags = merge(
    local.cluster_tags[each.value.cluster_key],
    each.value.tags,
    { Name = "${aws_eks_cluster.this[each.value.cluster_key].name}-${each.value.association_name}" }
  )

  depends_on = [aws_eks_addon.this]
}
