data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

locals {
  clusters = var.eks_config

  cluster_tags = {
    for key, cluster in local.clusters : key => merge(
      var.default_tags,
      cluster.control_plane.tags,
      { Name = cluster.control_plane.name }
    )
  }

  auto_mode_clusters = {
    for key, cluster in local.clusters : key => cluster
    if cluster.control_plane.auto_mode != null
  }

  enabled_auto_mode_clusters = {
    for key, cluster in local.auto_mode_clusters : key => cluster
    if cluster.control_plane.auto_mode.enabled
  }

  managed_auto_mode_node_role_clusters = {
    for key, cluster in local.enabled_auto_mode_clusters : key => cluster
    if length(cluster.control_plane.auto_mode.node_pools) > 0 && cluster.control_plane.auto_mode.node_role_arn == null
  }

  node_groups = merge({}, [
    for cluster_key, cluster in local.clusters : {
      for node_group_key, node_group in cluster.node_groups :
      "${cluster_key}||${node_group_key}" => merge(node_group, {
        cluster_key    = cluster_key
        node_group_key = node_group_key
        resolved_name  = coalesce(node_group.name, node_group_key)
      })
    }
  ]...)

  default_addons = {
    coredns = {
      addon_version               = null
      configuration_values        = null
      preserve                    = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
      service_account_role_arn    = null
      tags                        = {}
    }
    kube-proxy = {
      addon_version               = null
      configuration_values        = null
      preserve                    = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
      service_account_role_arn    = null
      tags                        = {}
    }
    vpc-cni = {
      addon_version               = null
      configuration_values        = null
      preserve                    = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
      service_account_role_arn    = null
      tags                        = {}
    }
  }

  resolved_addons = {
    for cluster_key, cluster in local.clusters : cluster_key => (
      cluster.control_plane.addons != null ? cluster.control_plane.addons : (
        try(cluster.control_plane.auto_mode.enabled, false) && length(cluster.node_groups) == 0 ? {} : local.default_addons
      )
    )
  }

  addons = merge({}, [
    for cluster_key, cluster in local.clusters : {
      for addon_name, addon in merge(
        local.resolved_addons[cluster_key],
        length(cluster.control_plane.pod_identity_associations) > 0 && (
          !try(cluster.control_plane.auto_mode.enabled, false) || length(cluster.node_groups) > 0
          ) ? {
          eks-pod-identity-agent = {
            addon_version               = null
            configuration_values        = null
            preserve                    = true
            resolve_conflicts_on_create = "OVERWRITE"
            resolve_conflicts_on_update = "OVERWRITE"
            service_account_role_arn    = null
            tags                        = {}
          }
        } : {}
      ) :
      "${cluster_key}||${addon_name}" => merge(addon, {
        cluster_key = cluster_key
        addon_name  = addon_name
      })
    }
  ]...)

  capabilities = merge({}, [
    for cluster_key, cluster in local.clusters : {
      for capability_key, capability in cluster.control_plane.capabilities :
      "${cluster_key}||${capability_key}" => merge(capability, {
        capability_key = capability_key
        cluster_key    = cluster_key
        resolved_name  = coalesce(capability.name, capability_key)
        resolved_type  = upper(capability.type)
      })
    }
  ]...)

  managed_capabilities = {
    for key, capability in local.capabilities : key => capability
    if capability.role_arn == null
  }

  identity_providers = merge({}, [
    for cluster_key, cluster in local.clusters : {
      for provider_name, provider in cluster.control_plane.identity_providers :
      "${cluster_key}||${provider_name}" => merge(provider, {
        cluster_key   = cluster_key
        provider_name = provider_name
      })
    }
  ]...)

  access_entries = merge({}, [
    for cluster_key, cluster in local.clusters : {
      for entry_name, entry in cluster.control_plane.access_entries :
      "${cluster_key}||${entry_name}" => merge(entry, {
        cluster_key = cluster_key
        entry_name  = entry_name
      })
    }
  ]...)

  access_policy_associations = merge({}, [
    for entry_key, entry in local.access_entries : {
      for association_name, association in entry.policy_associations :
      "${entry_key}||${association_name}" => merge(association, {
        entry_key   = entry_key
        cluster_key = entry.cluster_key
      })
    }
  ]...)

  pod_identity_associations = merge({}, [
    for cluster_key, cluster in local.clusters : {
      for association_name, association in cluster.control_plane.pod_identity_associations :
      "${cluster_key}||${association_name}" => merge(association, {
        association_name = association_name
        cluster_key      = cluster_key
      })
    }
  ]...)

  managed_kms_clusters = {
    for key, cluster in local.clusters : key => cluster
    if cluster.control_plane.encryption_config.enabled && cluster.control_plane.encryption_config.key_arn == null
  }

  irsa_clusters = {
    for key, cluster in local.clusters : key => cluster
    if cluster.control_plane.irsa.enabled
  }
}
