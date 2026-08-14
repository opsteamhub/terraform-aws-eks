variable "default_tags" {
  description = "Tags applied to every taggable resource. Environment, Project, and Owner are required."
  type        = map(string)

  validation {
    condition = alltrue([
      for key in ["Environment", "Project", "Owner"] :
      try(trimspace(var.default_tags[key]) != "", false)
    ])
    error_message = "default_tags must contain non-empty Environment, Project, and Owner values."
  }
}

variable "eks_config" {
  description = "EKS clusters keyed by a stable Terraform identifier."

  type = map(object({
    control_plane = object({
      name    = string
      version = optional(string, "1.35")

      role_arn                      = optional(string)
      role_name                     = optional(string)
      role_permissions_boundary     = optional(string)
      role_additional_policy_arns   = optional(map(string), {})
      enabled_cluster_log_types     = optional(set(string), ["api", "audit", "authenticator", "controllerManager", "scheduler"])
      bootstrap_self_managed_addons = optional(bool, false)
      deletion_protection           = optional(bool, false)

      vpc_config = object({
        subnet_ids              = set(string)
        security_group_ids      = optional(set(string), [])
        endpoint_private_access = optional(bool, true)
        endpoint_public_access  = optional(bool, false)
        public_access_cidrs     = optional(set(string), [])
      })

      access_config = optional(object({
        authentication_mode                         = optional(string, "API_AND_CONFIG_MAP")
        bootstrap_cluster_creator_admin_permissions = optional(bool, true)
      }), {})

      kubernetes_network_config = optional(object({
        ip_family         = optional(string, "ipv4")
        service_ipv4_cidr = optional(string, "172.20.0.0/16")
        service_ipv6_cidr = optional(string)
      }), {})

      upgrade_policy = optional(object({
        support_type = optional(string, "STANDARD")
      }), {})

      logs = optional(object({
        retention_in_days = optional(number, 30)
        kms_key_id        = optional(string)
      }), {})

      encryption_config = optional(object({
        enabled                 = optional(bool, true)
        resources               = optional(set(string), ["secrets"])
        key_arn                 = optional(string)
        alias                   = optional(string)
        description             = optional(string)
        deletion_window_in_days = optional(number, 30)
        enable_key_rotation     = optional(bool, true)
      }), {})

      irsa = optional(object({
        enabled         = optional(bool, true)
        client_id_list  = optional(set(string), ["sts.amazonaws.com"])
        thumbprint_list = optional(set(string), [])
      }), {})

      addons = optional(map(object({
        addon_version               = optional(string)
        configuration_values        = optional(string)
        preserve                    = optional(bool, true)
        resolve_conflicts_on_create = optional(string, "OVERWRITE")
        resolve_conflicts_on_update = optional(string, "OVERWRITE")
        service_account_role_arn    = optional(string)
        tags                        = optional(map(string), {})
        })), {
        coredns    = {}
        kube-proxy = {}
        vpc-cni    = {}
      })

      identity_providers = optional(map(object({
        client_id       = string
        issuer_url      = string
        groups_claim    = optional(string)
        groups_prefix   = optional(string)
        required_claims = optional(map(string), {})
        username_claim  = optional(string)
        username_prefix = optional(string)
        tags            = optional(map(string), {})
      })), {})

      access_entries = optional(map(object({
        principal_arn     = string
        type              = optional(string, "STANDARD")
        kubernetes_groups = optional(set(string), [])
        username          = optional(string)
        policy_associations = optional(map(object({
          policy_arn = string
          access_scope = object({
            type       = string
            namespaces = optional(set(string), [])
          })
        })), {})
      })), {})

      pod_identity_associations = optional(map(object({
        namespace            = string
        service_account      = string
        role_arn             = string
        target_role_arn      = optional(string)
        disable_session_tags = optional(bool, false)
        policy               = optional(string)
        tags                 = optional(map(string), {})
      })), {})

      tags = optional(map(string), {})
    })

    node_groups = optional(map(object({
      name                             = optional(string)
      ami_type                         = optional(string, "AL2023_x86_64_STANDARD")
      capacity_type                    = optional(string, "ON_DEMAND")
      force_update_version             = optional(bool, false)
      instance_types                   = optional(set(string), ["t3.medium"])
      labels                           = optional(map(string), {})
      node_role_arn                    = optional(string)
      node_role_name                   = optional(string)
      node_role_permissions_boundary   = optional(string)
      node_role_additional_policy_arns = optional(map(string), {})
      release_version                  = optional(string)
      subnet_ids                       = optional(set(string))
      tags                             = optional(map(string), {})
      version                          = optional(string)

      scaling_config = optional(object({
        desired_size = optional(number, 1)
        max_size     = optional(number, 3)
        min_size     = optional(number, 1)
      }), {})

      update_config = optional(object({
        max_unavailable            = optional(number)
        max_unavailable_percentage = optional(number)
        }), {
        max_unavailable_percentage = 33
      })

      node_repair_config = optional(object({
        enabled = optional(bool, true)
      }), {})

      taints = optional(map(object({
        key    = string
        value  = optional(string)
        effect = string
      })), {})

      launch_template = optional(object({
        image_id    = optional(string)
        key_name    = optional(string)
        name_prefix = optional(string)
        user_data   = optional(string)

        metadata_options = optional(object({
          http_endpoint               = optional(string, "enabled")
          http_protocol_ipv6          = optional(string, "disabled")
          http_put_response_hop_limit = optional(number, 2)
          http_tokens                 = optional(string, "required")
          instance_metadata_tags      = optional(string, "disabled")
        }), {})

        monitoring = optional(object({
          enabled = optional(bool, false)
        }), {})

        security_group_ids = optional(set(string), [])

        block_device_mappings = optional(list(object({
          device_name  = string
          no_device    = optional(string)
          virtual_name = optional(string)
          ebs = optional(object({
            delete_on_termination = optional(bool, true)
            encrypted             = optional(bool, true)
            iops                  = optional(number)
            kms_key_id            = optional(string)
            snapshot_id           = optional(string)
            throughput            = optional(number)
            volume_size           = optional(number, 20)
            volume_type           = optional(string, "gp3")
          }))
          })), [{
          device_name = "/dev/xvda"
          ebs = {
            delete_on_termination = true
            encrypted             = true
            volume_size           = 20
            volume_type           = "gp3"
          }
        }])
      }), {})
    })), {})
  }))

  validation {
    condition = alltrue([
      for cluster in values(var.eks_config) :
      trimspace(cluster.control_plane.name) != "" && length(cluster.control_plane.vpc_config.subnet_ids) >= 2
    ])
    error_message = "Each cluster must have a non-empty name and at least two control-plane subnet_ids."
  }

  validation {
    condition = alltrue([
      for cluster in values(var.eks_config) :
      !cluster.control_plane.vpc_config.endpoint_public_access || (
        length(cluster.control_plane.vpc_config.public_access_cidrs) > 0 &&
        !contains(cluster.control_plane.vpc_config.public_access_cidrs, "0.0.0.0/0") &&
        !contains(cluster.control_plane.vpc_config.public_access_cidrs, "::/0")
      )
    ])
    error_message = "Public endpoints require explicit restricted public_access_cidrs; 0.0.0.0/0 and ::/0 are rejected."
  }

  validation {
    condition = alltrue(flatten([
      for cluster in values(var.eks_config) : [
        for node_group in values(cluster.node_groups) :
        node_group.scaling_config.min_size <= node_group.scaling_config.desired_size &&
        node_group.scaling_config.desired_size <= node_group.scaling_config.max_size
      ]
    ]))
    error_message = "Each node group must satisfy min_size <= desired_size <= max_size."
  }

  validation {
    condition = alltrue(flatten([
      for cluster in values(var.eks_config) : [
        for node_group in values(cluster.node_groups) :
        (node_group.update_config.max_unavailable == null) != (node_group.update_config.max_unavailable_percentage == null)
      ]
    ]))
    error_message = "Set exactly one of max_unavailable or max_unavailable_percentage for each node group."
  }

  validation {
    condition = alltrue([
      for cluster in values(var.eks_config) :
      contains(["API", "API_AND_CONFIG_MAP", "CONFIG_MAP"], cluster.control_plane.access_config.authentication_mode)
    ])
    error_message = "authentication_mode must be API, API_AND_CONFIG_MAP, or CONFIG_MAP."
  }

  validation {
    condition = alltrue([
      for cluster in values(var.eks_config) :
      cluster.control_plane.access_config.authentication_mode != "CONFIG_MAP" || length(cluster.control_plane.access_entries) == 0
    ])
    error_message = "access_entries require authentication_mode API or API_AND_CONFIG_MAP."
  }

  validation {
    condition = alltrue([
      for cluster in values(var.eks_config) :
      contains(["STANDARD", "EXTENDED"], cluster.control_plane.upgrade_policy.support_type)
    ])
    error_message = "upgrade_policy.support_type must be STANDARD or EXTENDED."
  }

  validation {
    condition = alltrue([
      for cluster in values(var.eks_config) :
      !cluster.control_plane.encryption_config.enabled || (
        cluster.control_plane.encryption_config.deletion_window_in_days >= 7 &&
        cluster.control_plane.encryption_config.deletion_window_in_days <= 30
      )
    ])
    error_message = "KMS deletion_window_in_days must be between 7 and 30."
  }

  validation {
    condition = alltrue([
      for cluster in values(var.eks_config) :
      cluster.control_plane.role_arn != null || length(coalesce(cluster.control_plane.role_name, "${cluster.control_plane.name}-cluster-role")) <= 64
    ])
    error_message = "Managed cluster IAM role names must be 64 characters or fewer; set role_name explicitly for long cluster names."
  }

  validation {
    condition = alltrue(flatten([
      for cluster in values(var.eks_config) : [
        for node_group_key, node_group in cluster.node_groups :
        node_group.node_role_arn != null || length(coalesce(node_group.node_role_name, "${cluster.control_plane.name}-${coalesce(node_group.name, node_group_key)}-node-role")) <= 64
      ]
    ]))
    error_message = "Managed node IAM role names must be 64 characters or fewer; set node_role_name explicitly when needed."
  }
}
