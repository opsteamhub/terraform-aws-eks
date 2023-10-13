variable "eks_config" {
  description = "Deploy EKS configs"
  type = map(
    object(
      {
        node_groups = optional(
          map(
            object(
              {
                ami_type               = optional(string, "AL2_x86_64")
                capacity_type          = optional(string, "ON_DEMAND")
                disk_size              = optional(string, 40)
                force_update_version   = optional(bool, false)
                instance_types         = optional(set(string), ["t3.medium"])
                exclusion_instance_types = optional(set(string))
                iam_role = optional(
                  object(
                    {
                      override_default_assume_role_policy = optional(bool, false)
                      assume_role_policy_statements = optional(
                        set(
                          object(
                            {
                              actions        = optional(set(string))
                              condition      = optional(
                                set(
                                  object(    
                                    {
                                      test     = optional(string)
                                      variable = optional(string)
                                      values   = optional(set(string))
                                    }
                                  )
                                )
                              )
                              effect         = optional(string, "Deny")
                              not_actions    = optional(set(string))
                              not_principals = optional(
                                set(
                                  object(
                                    {  
                                    identifiers = optional(set(string))
                                    type        = optional(string)  
                                    }
                                  )
                                )
                              )
                              not_resources  = optional(set(string))
                              principals     = optional(
                                set(
                                  object(
                                    {  
                                    identifiers = optional(set(string))
                                    type        = optional(string)
                                    }
                                  )
                                )    
                              )
                              resources      = optional(set(string))
                              sid            = optional(string)
                            }
                          )
                        )
                      )
                      create                = optional(bool, true)
                      description           = optional(string)
                      force_detach_policies = optional(bool, true)
                      inline_policy         = optional(
                        set(
                          object(
                            {
                              actions        = optional(set(string))
                              condition      = optional(
                                set(
                                  object(    
                                    {
                                      test     = optional(string)
                                      variable = optional(string)
                                      values   = optional(set(string))
                                    }
                                  )
                                )
                              )
                              effect         = optional(string, "Deny")
                              not_actions    = optional(set(string))
                              not_principals = optional(
                                set(
                                  object(
                                    {  
                                    identifiers = optional(set(string))
                                    type        = optional(string)  
                                    }
                                  )
                                )
                              )
                              not_resources  = optional(set(string))
                              principals     = optional(
                                set(
                                  object(
                                    {  
                                    identifiers = optional(set(string))
                                    type        = optional(string)
                                    }
                                  )
                                )    
                              )
                              resources      = optional(set(string))
                              sid            = optional(string)
                            }
                          )
                        )
                      )
                      name_prefix                    = optional(string)
                      path                           = optional(string, "/")
                      permissions_boundary           = optional(string)
                      override_policy_attachments    = optional(bool, false)
                      policy_attachments             = optional(set(string), ["AmazonEKSWorkerNodePolicy", "AmazonEC2ContainerRegistryReadOnly", "AmazonEKS_CNI_Policy"])
                      role_arn                       = optional(string)
                      tags                           = optional(map(string))
                    }
                  ),
                  { }
                )
                labels                   = optional(map(string))
                launch_template          = optional(
                  object(
                    { 
                      ami = optional(
                        object(
                          {
                            ami_filters = optional(
                              list(
                                object(
                                  {
                                    name   = optional(string)
                                    values = optional(list(string))
                                  }
                                )
                              )
                            )
                            executable_users   = optional(set(string))
                            image_id           = optional(string)
                            include_deprecated = optional(bool, false)
                            most_recent        = optional(bool, true)
                            name_regex         = optional(string)
                            owners             = optional(set(string), ["self"])
                          }
                        ),
                        {
                          ami_filters = [
                            {
                              name   = "name"
                              values = ["amazon-eks-node-1.27*"]
                            },
                            {
                              name   = "root-device-type"
                              values = ["ebs"]
                            },
                            {
                              name   = "virtualization-type"
                              values = ["hvm"]
                            }
                          ]
                          owners = ["amazon"]
                        }
                      )
                      block_device_mappings = optional(
                        set(
                          object(
                            {
                              device_name  = optional(string)
                              ebs = optional(
                                object(  
                                  {
                                    delete_on_termination = optional(bool, true)
                                    encrypted             = optional(bool, true)
                                    iops                  = optional(string, 3000)
                                    kms_key_id            = optional(string)
                                    snapshot_id           = optional(string)
                                    throughput            = optional(string, 125)
                                    volume_size           = optional(string, 20)
                                    volume_type           = optional(string, "gp3")
                                  }
                                )
                              )
                              no_device    = optional(string)
                              virtual_name = optional(string)
                            }
                          )
                        )
                      )
                      capacity_reservation_specification = optional(
                        object(
                          {
                            capacity_reservation_preference = optional(string, "none")
                            capacity_reservation_target     = optional(
                              object(
                                {
                                  capacity_reservation_id                 = optional(string)
                                  capacity_reservation_resource_group_arn = optional(string)
                                }
                              )
                            )
                          }
                        )
                      ) 
                      cpu_options = optional(
                        object(  
                          {
                            amd_sev_snp      = optional(string, "disabled") ##
                            core_count       = optional(string, 1)          ##
                            threads_per_core = optional(string, 2)
                          }
                        ), { }
                      )
                      credit_specification               = optional(
                        object(
                          {
                            cpu_credits = optional(string, "unlimited")
                          }
                        ),
                        { }
                      )
                      default_version                    = optional(string)
                      description                        = optional(string)
                      disable_api_stop_compatible        = optional(bool, false)
                      #disable_api_stop                   = optional(bool, true)
                      disable_api_termination_compatible = optional(bool, false)
                      #disable_api_termination            = optional(bool, true)
                      ebs_optimized                      = optional(bool, true)
                      elastic_gpu_specifications         = optional(
                        object(
                          {
                            type = optional(string)
                          }
                        )
                      )
                      elastic_inference_accelerator = optional(
                        object(
                          {
                            type = optional(string)
                          }
                        )
                      )
                      enclave_options = optional(
                        object(
                          {
                            enable = optional(bool, false)
                          }
                        ), {}
                      )
                      hibernation_options = optional(
                        object(
                          {
                            enable = optional(bool, false)
                          }
                        )
                      )
                      iam_instance_profile = optional(
                        object(
                          {
                            arn  = optional(string)
                            name = optional(string)
                          }
                        )
                      )
                      instance_initiated_shutdown_behavior_compatible = optional(bool, false)
                      instance_market_options              = optional(
                        object(
                          {
                            market_type  = optional(string)
                            spot_options = optional(
                              object(
                                {
                                  block_duration_minutes         = optional(string)
                                  instance_interruption_behavior = optional(string, "terminate")
                                  max_price                      = optional(string)
                                  spot_instance_type             = optional(string)
                                  valid_until                    = optional(string)
                                }
                              )
                            )
                          }
                        )
                      )
                      instance_requirements = optional(
                        object(
                          {
                            accelerator_count = optional(
                              object(
                                {
                                  min = optional(string)
                                  max = optional(string)
                                }
                              )
                            )
                            accelerator_manufacturers = optional(set(string))
                            accelerator_names         = optional(set(string))
                            accelerator_total_memory_mib = optional(
                                      object(
                                        {
                                          min = optional(string)
                                          max = optional(string)
                                        }
                                      )
                            )
                            accelerator_types      = optional(set(string))
                            allowed_instance_types = optional(set(string))
                            bare_metal             = optional(string, "excluded")
                            baseline_ebs_bandwidth_mbps = optional(
                                      object(
                                        {
                                          min = optional(string)
                                          max = optional(string)
                                        }
                                      )
                            )
                            burstable_performance   = optional(string, "excluded")
                            cpu_manufacturers       = optional(set(string))
                            excluded_instance_types = optional(set(string))
                            instance_generations    = optional(set(string))
                            local_storage           = optional(string, "included")
                            local_storage_types     = optional(set(string), ["ssd"])
                            memory_gib_per_vcpu     = optional(
                                      object(
                                        {
                                          min = optional(string)
                                          max = optional(string)
                                        }
                                      )
                            )
                            memory_mib = optional(
                              object(
                                {
                                  min = optional(string, 4)
                                  max = optional(string)
                                }
                              )
                            )
                            network_bandwidth_gbps = optional(
                              object(
                                {
                                  min = optional(string)
                                  max = optional(string)
                                }
                              )
                            )
                            network_interface_count = optional(
                              object(
                                {
                                  min = optional(string)
                                  max = optional(string)
                                }
                              )
                            )
                            on_demand_max_price_percentage_over_lowest_price = optional(string, "20")
                            require_hibernate_support                        = optional(bool, false)
                            spot_max_price_percentage_over_lowest_price      = optional(string, "100")
                            total_local_storage_gb = optional(
                              object(
                                {
                                  min = optional(string)
                                  max = optional(string)
                                }
                              )
                            )
                            vcpu_count = optional(
                              object(
                                {
                                  min = optional(string, 2)
                                  max = optional(string)
                                }
                              )
                            )
                          }
                        )
                      )
                      instance_type                        = optional(string)
                      kernel_id                            = optional(string)
                      key_name                             = optional(string)
                      license_specification                = optional(
                        object(
                          {
                            license_configuration_arn = optional(string)
                          }
                        )
                      )
                      maintenance_options = optional(
                        object(
                          {
                            auto_recovery = optional(string, "default")
                          }
                        ),
                        { }
                      )
                      metadata_options = optional(
                        object(
                          {
                            http_endpoint               = optional(string, "enabled")
                            http_tokens                 = optional(string, "required")
                            http_put_response_hop_limit = optional(string, "1")
                            http_protocol_ipv6          = optional(string, "disabled")
                            instance_metadata_tags      = optional(string, "enabled")
                          }
                        ),
                        { }
                      )
                      monitoring = optional(
                        object(
                          {
                            enabled = optional(bool, true)
                          }
                        ), 
                        { }
                      )
                      name                                 = optional(string)
                      name_prefix                          = optional(string)
                      network_interfaces                   = optional(
                        object(
                          {
                            associate_carrier_ip_address = optional(bool)
                            associate_public_ip_address  = optional(bool, false)
                            delete_on_termination        = optional(bool, true)
                            description                  = optional(string)
                            device_index                 = optional(string, 0)
                            interface_type               = optional(string)
                            ipv4_prefix_count            = optional(string)
                            ipv4_prefixes                = optional(string)
                            ipv6_addresses               = optional(set(string))
                            ipv6_address_count           = optional(string)
                            ipv6_prefix_count            = optional(string)
                            ipv6_prefixes                = optional(string)
                            network_interface_id         = optional(string)
                            network_card_index           = optional(string, 0)
                            private_ip_address           = optional(string)
                            ipv4_address_count           = optional(string) 
                            ipv4_addresses               = optional(string)
                            security_groups              = optional(set(string))
                            subnet_id                    = optional(string)
                          }
                        )
                      )
                      placement                            = optional(
                        object(
                          {
                            affinity                = optional(string)
                            availability_zone       = optional(string)
                            group_name              = optional(string)
                            host_id                 = optional(string)
                            host_resource_group_arn = optional(string)
                            spread_domain           = optional(string)
                            tenancy                 = optional(string, "default")
                            partition_number        = optional(string)
                          }
                        )
                      )
                      private_dns_name_options = optional(
                        object(
                          {
                            enable_resource_name_dns_aaaa_record = optional(bool, false)
                            enable_resource_name_dns_a_record    = optional(bool, true)
                            hostname_type                        = optional(string, "ip-name")
                          }
                        )
                      )
                      ram_disk_id              = optional(string)
                      security_group_names     = optional(set(string))
                      tag_specifications       = optional(
                        set(
                          object(
                            {
                              resource_type = optional(string, "instance")
                              tags          = optional(map(string))
                            }
                          )
                        )
                      )
                      tags                     = optional(map(string))
                      update_default_version   = optional(string)
                      user_data                = optional(any)
                      vpc_security_group_ids   = optional(set(string))
                    }
                  ), { }
                )
                node_group_name_prefix = optional(string)
                node_role_arn          = optional(string)
                release_version        = optional(string)
                remote_access          = optional(
                  object(
                    {
                      ec2_ssh_key               = optional(string)
                      source_security_group_ids = optional(set(string))
                    }
                  )
                )
                scaling_config         = optional(
                  object(
                    {
                      desired_size = optional(string, 1)
                      max_size     = optional(string, 100)
                      min_size     = optional(string, 1)
                    }
                  ),
                  { }
                )
                security_groups = optional( # Security group configuration for the VPC                  
                  object(
                    {
                      egress = optional(             # Egress rule configuration for the security group
                        list(
                          object(
                            {
                              description      = optional(string)      # Description of the egress rule
                              from_port        = optional(string)      # Starting port range for the egress rule
                              to_port          = optional(string)      # Ending port range for the egress rule
                              protocol         = optional(string)      # Protocol to use for the egress rule
                              cidr_blocks      = optional(set(string)) # List of CIDR blocks for the egress rule
                              ipv6_cidr_blocks = optional(set(string)) # List of IPv6 CIDR blocks for the egress rule
                              prefix_list_ids  = optional(set(string)) # List of prefix list IDs for the egress rule
                              security_groups  = optional(set(string)) # List of security groups to associate with the egress rule
                            }
                          )
                        )
                      )
                      ingress = optional( # Ingress rule configuration for the security group
                        list(
                          object(
                            {
                              description      = optional(string)      # Description of the ingress rule
                              from_port        = optional(string)      # Starting port range for the ingress rule
                              to_port          = optional(string)      # Ending port range for the ingress rule
                              protocol         = optional(string)      # Protocol to use for the ingress rule
                              cidr_blocks      = optional(set(string)) # List of CIDR blocks for the ingress rule
                              ipv6_cidr_blocks = optional(set(string)) # List of IPv6 CIDR blocks for the ingress rule
                              prefix_list_ids  = optional(set(string)) # List of prefix list IDs for the ingress rule
                              security_groups  = optional(set(string)) # List of security groups to associate with the ingress rule
                            }
                          )
                        )
                      )
                      revoke_rules_on_delete = optional(bool, false)      # If 'true', will revoke all rules when the security group is deleted.  This is normally not needed, however certain AWS services such as Elastic Map Reduce may automatically add required rules to security groups used with the service, and those rules may contain a cyclic dependency that prevent the security groups from being destroyed without removing the dependency first. Default false.
                      tags                   = optional(map(string))      # Tags for the security group
                    }
                  )
                )
                subnet_filter = optional(
                  set(
                    object(
                      {
                        name   = optional(string)
                        values = optional(set(string))
                      }
                    )
                  )
                )
                subnet_ids = optional(set(string))
                taint = optional(
                  set(
                    object(
                      {
                        key    = optional(string)
                        value  = optional(string)
                        effect = optional(string, "NO_SCHEDULE")
                      }
                    )
                  )
                )
                update_config = optional(
                  object(
                    {    
                      max_unavailable            = optional(string)
                      max_unavailable_percentage = optional(string, 10)
                    }
                  )
                )
                version = optional(string, "1.27")
                tags    = optional(map(string))
              }
            )
          )
        )
        control_plane = optional(
          object(
            {
              addons = optional(
                list(
                  object(
                    {
                      addon_name           = optional(string)
                      addon_version        = optional(string)
                      configuration_values = optional(any)
                      resolve_conflicts    = optional(string, "OVERWRITE") 
                    }
                  )
                ), 
                [
                  {
                    addon_name           = "coredns"
                    addon_version        = "v1.10.1-eksbuild.1"
                    configuration_values = "{\"replicaCount\":4,\"resources\":{\"limits\":{\"cpu\":\"100m\",\"memory\":\"150Mi\"},\"requests\":{\"cpu\":\"30m\",\"memory\":\"30Mi\"}}}"
                    resolve_conflicts    = "OVERWRITE"
                  }
                ]
              )
              cluster_timeouts = optional(
                object(
                  {
                    create = optional(string)
                    update = optional(string)
                    delete = optional(string)
                  }
                )
              )
              create_before_destroy      = optional(bool, false)
              enabled_cluster_log_types = optional(set(string), ["api","audit","authenticator","controllerManager","scheduler"])
              encryption_config = optional(
                object(
                  {
                    provider  = optional(
                      object(
                        {
                          key_arn                           = optional(string)
                          create                            = optional(bool, true)
                          kms_key_description               = optional(string)
                          kms_key_deletion_window_in_days   = optional(string, 7)
                          enable_kms_key_rotation           = optional(bool, true)
                          kms_key_enable_default_policy     = optional(bool, false)
                          kms_key_owners                    = optional(set(string))
                          kms_key_administrators            = optional(set(string))
                          kms_key_users                     = optional(set(string))
                          kms_key_service_users             = optional(set(string))
                          kms_key_source_policy_documents   = optional(set(string))
                          kms_key_override_policy_documents = optional(set(string))
                          kms_key_aliases                   = optional(set(string))
                        }
                      )
                    )
                    resources = optional(set(string), ["secrets"])
                  }
                ), 
                { }
              )
              iam_role = optional(
                object(
                  {
                    override_default_assume_role_policy = optional(bool, false)
                    assume_role_policy_statements = optional(
                      set(
                        object(
                          {
                            actions        = optional(set(string))
                            condition      = optional(
                              set(
                                object(    
                                  {
                                    test     = optional(string)
                                    variable = optional(string)
                                    values   = optional(set(string))
                                  }
                                )
                              )
                            )
                            effect         = optional(string, "Deny")
                            not_actions    = optional(set(string))
                            not_principals = optional(
                              set(
                                object(
                                  {  
                                    identifiers = optional(set(string))
                                    type        = optional(string)  
                                  }
                                )
                              )
                            )
                            not_resources  = optional(set(string))
                            principals     = optional(
                              set(
                                object(
                                  {  
                                    identifiers = optional(set(string))
                                    type        = optional(string)
                                  }
                                )
                              )    
                            )
                            resources      = optional(set(string))
                            sid            = optional(string)
                          }
                        )
                      )
                    )
                    create                = optional(bool, true)
                    description           = optional(string)
                    force_detach_policies = optional(bool, true)
                    name_prefix           = optional(string)
                    path                  = optional(string, "/")
                    permissions_boundary  = optional(string)
                    policy_attachments    = optional(set(string), ["AmazonEKSClusterPolicy","AmazonEKSServicePolicy"])
                    role_arn              = optional(string)
                    tags                  = optional(map(string))
                  }
                ),
                { }
              )
              idp_config = optional(
                object(
                  {
                    groups_claim    = optional(string)
                    groups_prefix   = optional(string)
                    required_claims = optional(string)
                    username_claim  = optional(string)
                    username_prefix = optional(string)
                  }
                )
              )
              kubernetes_network_config = optional(
                object(
                  {
                    service_ipv4_cidr = optional(string, "172.16.0.0/23")
                    ip_family         = optional(string, "ipv4")
                  }
                )
              )
              logs = optional(
                object(
                  {
                    retention_in_days   = optional(string, 90)
                    tags                = optional(map(string))
                  }
                ),
                { }
              )
              name_prefix               = optional(string)
              name                      = optional(string)
              override_default_addons   = optional(bool, false)
              prevent_destroy           = optional(bool, false)
              role_arn                  = optional(string)
              vpc_config                = optional(
                object(
                  {
                    endpoint_private_access = optional(bool, true)                      ##
                    endpoint_public_access  = optional(bool, true)                      ##
                    public_access_cidrs     = optional(set(string), ["0.0.0.0/0"])      ##
                    security_group_ids      = optional(set(string))
                    subnet_filter = optional(
                      set(
                        object(
                          {
                            name   = optional(string)
                            values = optional(set(string))
                          }
                        )
                      )
                    )
                    subnet_ids      = optional(set(string))
                    vpc_id          = optional(string)
                    vpc_filter = optional(
                      set(
                        object(
                          {
                            name   = optional(string)
                            values = optional(set(string))
                          }
                        )
                      )
                    )                
                  }
                ), {}
              )
              version = optional(string, "1.27")
              tags    = optional(map(string))
            }
          ),
          { }
        )
      }
    )
  )
  default = {}
}