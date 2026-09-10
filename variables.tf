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

      auto_mode = optional(object({
        enabled                          = optional(bool, true)
        node_pools                       = optional(set(string), ["general-purpose", "system"])
        node_role_arn                    = optional(string)
        node_role_name                   = optional(string)
        node_role_permissions_boundary   = optional(string)
        node_role_additional_policy_arns = optional(map(string), {})
      }))

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
      })))

      capabilities = optional(map(object({
        name                      = optional(string)
        type                      = string
        role_arn                  = optional(string)
        role_name                 = optional(string)
        role_permissions_boundary = optional(string)
        role_policy_arns          = optional(map(string), {})
        role_inline_policy        = optional(string)
        delete_propagation_policy = optional(string, "RETAIN")

        argo_cd = optional(object({
          namespace = optional(string)
          aws_idc = object({
            idc_instance_arn = string
            idc_region       = optional(string)
          })
          network_access = optional(object({
            vpce_ids = set(string)
          }))
          rbac_role_mappings = optional(map(object({
            role = string
            identities = set(object({
              id   = string
              type = string
            }))
          })), {})
        }))

        tags = optional(map(string), {})
      })), {})

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
      !try(cluster.control_plane.auto_mode.enabled, false) ||
      contains(["API", "API_AND_CONFIG_MAP"], cluster.control_plane.access_config.authentication_mode)
    ])
    error_message = "EKS Auto Mode requires authentication_mode API or API_AND_CONFIG_MAP."
  }

  validation {
    condition = alltrue([
      for cluster in values(var.eks_config) :
      !try(cluster.control_plane.auto_mode.enabled, false) || !cluster.control_plane.bootstrap_self_managed_addons
    ])
    error_message = "EKS Auto Mode requires bootstrap_self_managed_addons to be false."
  }

  validation {
    condition = alltrue([
      for cluster in values(var.eks_config) : alltrue([
        for node_pool in try(cluster.control_plane.auto_mode.node_pools, toset([])) :
        contains(["general-purpose", "system"], node_pool)
      ])
    ])
    error_message = "auto_mode.node_pools can contain only the built-in general-purpose and system pools; create custom NodePool resources outside this module."
  }

  validation {
    condition = alltrue([
      for cluster in values(var.eks_config) :
      try(cluster.control_plane.auto_mode.node_role_arn, null) == null || (
        try(cluster.control_plane.auto_mode.node_role_name, null) == null &&
        try(cluster.control_plane.auto_mode.node_role_permissions_boundary, null) == null &&
        length(try(cluster.control_plane.auto_mode.node_role_additional_policy_arns, {})) == 0
      )
    ])
    error_message = "Managed Auto Mode node-role settings must be omitted when auto_mode.node_role_arn is supplied."
  }

  validation {
    condition = alltrue([
      for cluster in values(var.eks_config) :
      try(cluster.control_plane.auto_mode.enabled, true) || (
        try(cluster.control_plane.auto_mode.node_role_arn, null) == null &&
        try(cluster.control_plane.auto_mode.node_role_name, null) == null &&
        try(cluster.control_plane.auto_mode.node_role_permissions_boundary, null) == null &&
        length(try(cluster.control_plane.auto_mode.node_role_additional_policy_arns, {})) == 0
      )
    ])
    error_message = "Auto Mode node-role settings must be omitted when auto_mode.enabled is false."
  }

  validation {
    condition = alltrue([
      for cluster in values(var.eks_config) :
      !try(cluster.control_plane.auto_mode.enabled, false) ||
      length(try(cluster.control_plane.auto_mode.node_pools, toset([]))) > 0 || (
        try(cluster.control_plane.auto_mode.node_role_arn, null) == null &&
        try(cluster.control_plane.auto_mode.node_role_name, null) == null &&
        try(cluster.control_plane.auto_mode.node_role_permissions_boundary, null) == null &&
        length(try(cluster.control_plane.auto_mode.node_role_additional_policy_arns, {})) == 0
      )
    ])
    error_message = "Auto Mode node-role settings must be omitted when node_pools is empty; custom NodeClasses own their node roles."
  }

  validation {
    condition = alltrue([
      for cluster in values(var.eks_config) :
      !try(cluster.control_plane.auto_mode.enabled, false) ||
      length(try(cluster.control_plane.auto_mode.node_pools, toset([]))) == 0 ||
      try(cluster.control_plane.auto_mode.node_role_arn, null) != null ||
      length(coalesce(
        try(cluster.control_plane.auto_mode.node_role_name, null),
        "${cluster.control_plane.name}-auto-node-role"
      )) <= 64
    ])
    error_message = "Managed Auto Mode node IAM role names must be 64 characters or fewer; set auto_mode.node_role_name explicitly when needed."
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

  validation {
    condition = alltrue(flatten([
      for cluster in values(var.eks_config) : [
        for capability_key, capability in cluster.control_plane.capabilities :
        contains(["ACK", "ARGOCD", "KRO"], upper(capability.type)) &&
        length(trimspace(coalesce(capability.name, capability_key))) >= 1 &&
        length(trimspace(coalesce(capability.name, capability_key))) <= 100 &&
        can(regex("^[A-Za-z0-9_-]+$", coalesce(capability.name, capability_key)))
      ]
    ]))
    error_message = "Each capability type must be ACK, ARGOCD, or KRO, and its resolved name must contain 1 to 100 alphanumeric, hyphen, or underscore characters."
  }

  validation {
    condition = alltrue([
      for cluster in values(var.eks_config) :
      length(distinct([
        for capability in values(cluster.control_plane.capabilities) : upper(capability.type)
      ])) == length(cluster.control_plane.capabilities)
    ])
    error_message = "Each cluster can configure at most one capability of each type."
  }

  validation {
    condition = alltrue(flatten([
      for cluster in values(var.eks_config) : [
        for capability in values(cluster.control_plane.capabilities) :
        upper(capability.delete_propagation_policy) == "RETAIN"
      ]
    ]))
    error_message = "EKS Capabilities currently support only RETAIN as delete_propagation_policy."
  }

  validation {
    condition = alltrue(flatten([
      for cluster in values(var.eks_config) : [
        for capability in values(cluster.control_plane.capabilities) :
        upper(capability.type) == "ARGOCD" ? (
          capability.argo_cd != null &&
          trimspace(capability.argo_cd.aws_idc.idc_instance_arn) != "" &&
          (capability.argo_cd.namespace == null || trimspace(capability.argo_cd.namespace) != "") &&
          (capability.argo_cd.network_access == null || length(capability.argo_cd.network_access.vpce_ids) > 0) &&
          length(capability.argo_cd.rbac_role_mappings) > 0 &&
          alltrue([
            for mapping in values(capability.argo_cd.rbac_role_mappings) :
            contains(["ADMIN", "EDITOR", "VIEWER"], upper(mapping.role)) &&
            length(mapping.identities) > 0 && alltrue([
              for identity in mapping.identities :
              trimspace(identity.id) != "" &&
              contains(["SSO_GROUP", "SSO_USER"], upper(identity.type))
            ])
          ])
        ) : capability.argo_cd == null
      ]
    ]))
    error_message = "ARGOCD requires aws_idc and an ADMIN, EDITOR, or VIEWER mapping to non-empty SSO_GROUP or SSO_USER identities; configured namespace and network_access values cannot be empty, and argo_cd must be omitted for ACK and KRO."
  }

  validation {
    condition = alltrue(flatten([
      for cluster in values(var.eks_config) : [
        for capability in values(cluster.control_plane.capabilities) :
        upper(capability.type) != "ACK" || capability.role_arn != null ||
        length(capability.role_policy_arns) > 0 || capability.role_inline_policy != null
      ]
    ]))
    error_message = "ACK requires an external role_arn or explicit managed-role permissions through role_policy_arns or role_inline_policy."
  }

  validation {
    condition = alltrue(flatten([
      for cluster in values(var.eks_config) : [
        for capability in values(cluster.control_plane.capabilities) :
        capability.role_arn == null || (
          capability.role_name == null &&
          capability.role_permissions_boundary == null &&
          length(capability.role_policy_arns) == 0 &&
          capability.role_inline_policy == null
        )
      ]
    ]))
    error_message = "Managed capability role settings must be omitted when role_arn is supplied."
  }

  validation {
    condition = alltrue(flatten([
      for cluster in values(var.eks_config) : [
        for capability_key, capability in cluster.control_plane.capabilities :
        capability.role_arn != null || length(coalesce(
          capability.role_name,
          "${cluster.control_plane.name}-${coalesce(capability.name, capability_key)}-capability-role"
        )) <= 64
      ]
    ]))
    error_message = "Managed capability IAM role names must be 64 characters or fewer; set role_name explicitly when needed."
  }

  validation {
    condition = alltrue(flatten([
      for cluster in values(var.eks_config) : [
        for capability in values(cluster.control_plane.capabilities) :
        capability.role_inline_policy == null || can(jsondecode(capability.role_inline_policy))
      ]
    ]))
    error_message = "role_inline_policy must contain valid JSON."
  }
}
