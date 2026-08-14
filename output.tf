output "cluster_names" {
  description = "EKS cluster names keyed by eks_config key."
  value       = { for key, cluster in aws_eks_cluster.this : key => cluster.name }
}

output "eks_clusters_name" {
  description = "Deprecated compatibility alias for cluster_names."
  value       = { for key, cluster in aws_eks_cluster.this : key => cluster.name }
}

output "clusters" {
  description = "Non-sensitive EKS cluster connection and identity attributes."
  value = {
    for key, cluster in aws_eks_cluster.this : key => {
      arn                       = cluster.arn
      endpoint                  = cluster.endpoint
      name                      = cluster.name
      platform_version          = cluster.platform_version
      status                    = cluster.status
      version                   = cluster.version
      cluster_security_group_id = cluster.vpc_config[0].cluster_security_group_id
      oidc_issuer_url           = try(cluster.identity[0].oidc[0].issuer, null)
    }
  }
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data keyed by cluster."
  value       = { for key, cluster in aws_eks_cluster.this : key => cluster.certificate_authority[0].data }
  sensitive   = true
}

output "node_groups" {
  description = "Managed node group attributes keyed as cluster_key||node_group_key."
  value = {
    for key, node_group in aws_eks_node_group.this : key => {
      arn           = node_group.arn
      id            = node_group.id
      node_role_arn = node_group.node_role_arn
      resources     = node_group.resources
      status        = node_group.status
    }
  }
}

output "auto_mode" {
  description = "EKS Auto Mode configuration for clusters that declare the auto_mode block."
  value = {
    for key, cluster in aws_eks_cluster.this : key => {
      enabled                        = try(cluster.compute_config[0].enabled, false)
      node_pools                     = try(cluster.compute_config[0].node_pools, toset([]))
      node_role_arn                  = try(cluster.compute_config[0].node_role_arn, null)
      block_storage_enabled          = try(cluster.storage_config[0].block_storage[0].enabled, false)
      elastic_load_balancing_enabled = try(cluster.kubernetes_network_config[0].elastic_load_balancing[0].enabled, false)
    }
    if local.clusters[key].control_plane.auto_mode != null
  }
}

output "auto_mode_node_role_arns" {
  description = "IAM role ARNs assigned to enabled built-in EKS Auto Mode node pools."
  value       = local.auto_mode_node_role_arns
}

output "launch_templates" {
  description = "Managed launch template attributes keyed as cluster_key||node_group_key."
  value = {
    for key, launch_template in aws_launch_template.node : key => {
      arn             = launch_template.arn
      default_version = launch_template.default_version
      id              = launch_template.id
      latest_version  = launch_template.latest_version
      name            = launch_template.name
    }
  }
}

output "kms_key_arns" {
  description = "KMS key ARNs used for EKS secret encryption, including externally supplied keys."
  value       = local.cluster_kms_key_arns
}

output "oidc_provider_arns" {
  description = "IAM OIDC provider ARNs for clusters with IRSA enabled."
  value       = { for key, provider in aws_iam_openid_connect_provider.this : key => provider.arn }
}

output "pod_identity_association_arns" {
  description = "EKS Pod Identity association ARNs keyed as cluster_key||association_key."
  value = {
    for key, association in aws_eks_pod_identity_association.this :
    key => association.association_arn
  }
}

output "capabilities" {
  description = "EKS Capability attributes keyed as cluster_key||capability_key."
  value = {
    for key, capability in aws_eks_capability.this : key => {
      arn                = capability.arn
      capability_name    = capability.capability_name
      cluster_name       = capability.cluster_name
      role_arn           = capability.role_arn
      type               = capability.type
      version            = capability.version
      argo_cd_server_url = try(capability.configuration[0].argo_cd[0].server_url, null)
    }
  }
}

output "capability_role_arns" {
  description = "IAM role ARNs used by EKS Capabilities, including externally supplied roles."
  value       = local.capability_role_arns
}

output "cluster_role_arns" {
  description = "IAM role ARNs used by the EKS control planes."
  value       = local.cluster_role_arns
}

output "node_role_arns" {
  description = "IAM role ARNs used by managed node groups."
  value       = local.node_role_arns
}
