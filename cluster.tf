resource "aws_eks_cluster" "this" {
  for_each = local.clusters

  name                          = each.value.control_plane.name
  role_arn                      = local.cluster_role_arns[each.key]
  version                       = each.value.control_plane.version
  enabled_cluster_log_types     = sort(tolist(each.value.control_plane.enabled_cluster_log_types))
  bootstrap_self_managed_addons = each.value.control_plane.bootstrap_self_managed_addons
  deletion_protection           = each.value.control_plane.deletion_protection

  dynamic "compute_config" {
    for_each = each.value.control_plane.auto_mode != null ? [each.value.control_plane.auto_mode] : []

    content {
      enabled = compute_config.value.enabled
      node_pools = compute_config.value.enabled ? sort(
        tolist(compute_config.value.node_pools)
      ) : null
      node_role_arn = compute_config.value.enabled && length(compute_config.value.node_pools) > 0 ? local.auto_mode_node_role_arns[each.key] : null
    }
  }

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

    dynamic "elastic_load_balancing" {
      for_each = each.value.control_plane.auto_mode != null ? [each.value.control_plane.auto_mode] : []

      content {
        enabled = elastic_load_balancing.value.enabled
      }
    }
  }

  dynamic "storage_config" {
    for_each = each.value.control_plane.auto_mode != null ? [each.value.control_plane.auto_mode] : []

    content {
      block_storage {
        enabled = storage_config.value.enabled
      }
    }
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
    aws_iam_role_policy_attachment.auto_mode_node,
  ]
}
