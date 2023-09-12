#
# Get TLS Certificate from EKS Clustter
#
data "tls_certificate" "eks_tls_certchain" {
  for_each = var.eks_config
  url      = aws_eks_cluster.eks_cp[each.key].identity[0].oidc[0].issuer
}

#
# Create OpenID Provider
#
resource "aws_iam_openid_connect_provider" "oidc_provider" {
  for_each = var.eks_config

  client_id_list  = toset(
    ["sts.${data.aws_partition.session.dns_suffix}"]
  )
  thumbprint_list = data.tls_certificate.eks_tls_certchain[each.key].certificates[*].sha1_fingerprint
  url             = aws_eks_cluster.eks_cp[each.key].identity[0].oidc[0].issuer  
}

#
# Create EKS Identity Provider  
#
resource "aws_eks_identity_provider_config" "eks_idp" {
  for_each = var.eks_config

  cluster_name = local.cluster_name[each.key]

  oidc {
    client_id                     = format("sts.%s", data.aws_partition.session.dns_suffix)
    groups_claim                  = try(each.value["control_plane"]["idp_config"]["groups_claim"], null)
    groups_prefix                 = try(each.value["control_plane"]["idp_config"]["groups_prefix"], null)
    identity_provider_config_name = aws_eks_cluster.eks_cp[
      local.cluster_id[each.key]
    ]["name"]
    issuer_url                    = aws_eks_cluster.eks_cp[
      local.cluster_id[each.key]
    ].identity[0].oidc[0].issuer
    required_claims               = try(each.value["control_plane"]["idp_config"]["required_claims"], null)
    username_claim                = try(each.value["control_plane"]["idp_config"]["username_claim"], null)
    username_prefix               = try(each.value["control_plane"]["idp_config"]["username_prefix"], null)
  }
}