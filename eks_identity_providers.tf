data "tls_certificate" "oidc" {
  for_each = {
    for key, cluster in local.irsa_clusters : key => cluster
    if length(cluster.control_plane.irsa.thumbprint_list) == 0
  }

  url = aws_eks_cluster.this[each.key].identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  for_each = local.irsa_clusters

  url            = aws_eks_cluster.this[each.key].identity[0].oidc[0].issuer
  client_id_list = sort(tolist(each.value.control_plane.irsa.client_id_list))
  thumbprint_list = length(each.value.control_plane.irsa.thumbprint_list) > 0 ? sort(
    tolist(each.value.control_plane.irsa.thumbprint_list)
  ) : [data.tls_certificate.oidc[each.key].certificates[length(data.tls_certificate.oidc[each.key].certificates) - 1].sha1_fingerprint]
  tags = merge(
    local.cluster_tags[each.key],
    { Name = "${each.value.control_plane.name}-irsa" }
  )
}

resource "aws_eks_identity_provider_config" "this" {
  for_each = local.identity_providers

  cluster_name = aws_eks_cluster.this[each.value.cluster_key].name

  oidc {
    client_id                     = each.value.client_id
    identity_provider_config_name = each.value.provider_name
    issuer_url                    = each.value.issuer_url
    groups_claim                  = each.value.groups_claim
    groups_prefix                 = each.value.groups_prefix
    required_claims               = each.value.required_claims
    username_claim                = each.value.username_claim
    username_prefix               = each.value.username_prefix
  }

  tags = merge(
    local.cluster_tags[each.value.cluster_key],
    each.value.tags,
    { Name = "${aws_eks_cluster.this[each.value.cluster_key].name}-${each.value.provider_name}" }
  )
}
