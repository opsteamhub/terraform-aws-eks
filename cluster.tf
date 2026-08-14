resource "aws_eks_cluster" "this" {
  for_each = local.clusters

  name                          = each.value.control_plane.name
  role_arn                      = local.cluster_role_arns[each.key]
  version                       = each.value.control_plane.version
  enabled_cluster_log_types     = sort(tolist(each.value.control_plane.enabled_cluster_log_types))
  bootstrap_self_managed_addons = each.value.control_plane.bootstrap_self_managed_addons
  deletion_protection           = each.value.control_plane.deletion_protection

  access_config {
    authentication_mode                         = each.value.control_plane.access_config.authentication_mode
    bootstrap_cluster_creator_admin_permissions = each.value.control_plane.access_config.bootstrap_cluster_creator_admin_permissions
  }

  vpc_config {
    subnet_ids              = sort(tolist(each.value.control_plane.vpc_config.subnet_ids))
    security_group_ids      = sort(tolist(each.value.control_plane.vpc_config.security_group_ids))
    endpoint_private_access = each.value.control_plane.vpc_config.endpoint_private_access
    endpoint_public_access  = each.value.control_plane.vpc_config.endpoint_public_access
    public_access_cidrs = each.value.control_plane.vpc_config.endpoint_public_access ? sort(
      tolist(each.value.control_plane.vpc_config.public_access_cidrs)
    ) : null
  }

  kubernetes_network_config {
    ip_family         = each.value.control_plane.kubernetes_network_config.ip_family
    service_ipv4_cidr = each.value.control_plane.kubernetes_network_config.ip_family == "ipv4" ? each.value.control_plane.kubernetes_network_config.service_ipv4_cidr : null
    service_ipv6_cidr = each.value.control_plane.kubernetes_network_config.ip_family == "ipv6" ? each.value.control_plane.kubernetes_network_config.service_ipv6_cidr : null
  }

  dynamic "encryption_config" {
    for_each = each.value.control_plane.encryption_config.enabled ? [each.value.control_plane.encryption_config] : []

    content {
      resources = sort(tolist(encryption_config.value.resources))

      provider {
        key_arn = local.cluster_kms_key_arns[each.key]
      }
    }
  }

  upgrade_policy {
    support_type = each.value.control_plane.upgrade_policy.support_type
  }

  tags = local.cluster_tags[each.key]

  depends_on = [
    aws_cloudwatch_log_group.cluster,
    aws_iam_role_policy_attachment.cluster,
  ]
}
