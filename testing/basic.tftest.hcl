# Provider mocking requires Terraform 1.7 or newer and no AWS credentials.
mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/terraform-test"
      user_id    = "AIDATEST"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock-role"
    }
  }

  mock_resource "aws_kms_key" {
    defaults = {
      arn    = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
      key_id = "00000000-0000-0000-0000-000000000000"
    }
  }

  mock_resource "aws_eks_cluster" {
    defaults = {
      arn              = "arn:aws:eks:us-east-1:123456789012:cluster/test-cluster"
      endpoint         = "https://example.eks.amazonaws.com"
      platform_version = "eks.1"
      status           = "ACTIVE"
      certificate_authority = [{
        data = "dGVzdA=="
      }]
      identity = [{
        oidc = [{
          issuer = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
        }]
      }]
    }
  }

  mock_resource "aws_launch_template" {
    defaults = {
      arn             = "arn:aws:ec2:us-east-1:123456789012:launch-template/lt-0123456789abcdef0"
      default_version = 1
      id              = "lt-0123456789abcdef0"
      latest_version  = 1
      name            = "test-cluster-system-abc123"
    }
  }

  mock_resource "aws_eks_node_group" {
    defaults = {
      arn       = "arn:aws:eks:us-east-1:123456789012:nodegroup/test-cluster/system/example"
      id        = "test-cluster:system"
      resources = []
      status    = "ACTIVE"
    }
  }

  mock_resource "aws_eks_capability" {
    defaults = {
      arn     = "arn:aws:eks:us-east-1:123456789012:capability/test-cluster/example"
      version = "1.0.0"
    }
  }

  mock_resource "aws_iam_openid_connect_provider" {
    defaults = {
      arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
    }
  }
}

mock_provider "tls" {
  mock_data "tls_certificate" {
    defaults = {
      certificates = [{
        sha1_fingerprint = "0000000000000000000000000000000000000000"
      }]
    }
  }
}

run "creates_a_secure_cluster_with_plug_and_play_defaults" {
  command = apply

  variables {
    default_tags = {
      Environment = "test"
      Owner       = "platform"
      Project     = "eks-module"
    }

    eks_config = {
      primary = {
        control_plane = {
          name = "test-cluster"
          vpc_config = {
            subnet_ids = [
              "subnet-0123456789abcdef0",
              "subnet-0123456789abcdef1",
            ]
          }
        }

        node_groups = {
          system = {}
        }
      }
    }
  }

  assert {
    condition = (
      aws_eks_cluster.this["primary"].vpc_config[0].endpoint_private_access &&
      !aws_eks_cluster.this["primary"].vpc_config[0].endpoint_public_access
    )
    error_message = "The EKS API endpoint must be private-only by default."
  }

  assert {
    condition = (
      length(aws_kms_key.eks) == 1 &&
      aws_kms_key.eks["primary"].enable_key_rotation &&
      aws_eks_cluster.this["primary"].encryption_config[0].resources == toset(["secrets"])
    )
    error_message = "Envelope encryption must create a rotating KMS key for Kubernetes secrets by default."
  }

  assert {
    condition = (
      length(aws_eks_addon.this) == 3 &&
      contains(keys(aws_eks_addon.this), "primary||coredns") &&
      contains(keys(aws_eks_addon.this), "primary||kube-proxy") &&
      contains(keys(aws_eks_addon.this), "primary||vpc-cni")
    )
    error_message = "The three baseline EKS add-ons must be managed without hard-coded versions."
  }

  assert {
    condition = (
      aws_eks_node_group.this["primary||system"].ami_type == "AL2023_x86_64_STANDARD" &&
      aws_launch_template.node["primary||system"].metadata_options[0].http_tokens == "required" &&
      aws_eks_node_group.this["primary||system"].node_repair_config[0].enabled
    )
    error_message = "Managed nodes must default to AL2023, IMDSv2, and automatic node repair."
  }

  assert {
    condition = contains(
      [for spec in aws_launch_template.node["primary||system"].tag_specifications : spec.resource_type],
      "network-interface",
    )
    error_message = "Managed node launch templates must propagate organizational tags to network interfaces."
  }

  assert {
    condition = alltrue([
      for key in ["Environment", "Owner", "Project"] :
      aws_eks_cluster.this["primary"].tags[key] != ""
    ])
    error_message = "Required organizational tags must reach the EKS cluster."
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.this) == 1
    error_message = "IRSA must be enabled for every supported Kubernetes version by default."
  }
}

run "supports_external_roles_and_kms_keys" {
  command = apply

  variables {
    default_tags = {
      Environment = "test"
      Owner       = "platform"
      Project     = "eks-module"
    }

    eks_config = {
      external = {
        control_plane = {
          name     = "external-dependencies"
          role_arn = "arn:aws:iam::123456789012:role/external-cluster-role"
          vpc_config = {
            subnet_ids = [
              "subnet-0123456789abcdef0",
              "subnet-0123456789abcdef1",
            ]
          }
          encryption_config = {
            key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
          }
          irsa = {
            enabled = false
          }
        }
        node_groups = {
          workers = {
            node_role_arn = "arn:aws:iam::123456789012:role/external-node-role"
          }
        }
      }
    }
  }

  assert {
    condition = (
      length(aws_iam_role.cluster) == 0 &&
      length(aws_iam_role.node) == 0 &&
      length(aws_kms_key.eks) == 0 &&
      length(aws_iam_openid_connect_provider.this) == 0
    )
    error_message = "Supplying external roles and a KMS key must avoid creating replacement dependencies."
  }
}

run "supports_explicit_kms_opt_out_and_absolute_node_updates" {
  command = apply

  variables {
    default_tags = {
      Environment = "test"
      Owner       = "platform"
      Project     = "eks-module"
    }

    eks_config = {
      explicit = {
        control_plane = {
          name = "explicit-options"
          vpc_config = {
            subnet_ids = [
              "subnet-0123456789abcdef0",
              "subnet-0123456789abcdef1",
            ]
          }
          encryption_config = {
            enabled = false
          }
          irsa = {
            enabled = false
          }
        }
        node_groups = {
          workers = {
            update_config = {
              max_unavailable = 1
            }
          }
        }
      }
    }
  }

  assert {
    condition = (
      length(aws_kms_key.eks) == 0 &&
      length(aws_eks_cluster.this["explicit"].encryption_config) == 0 &&
      aws_eks_node_group.this["explicit||workers"].update_config[0].max_unavailable == 1 &&
      aws_eks_node_group.this["explicit||workers"].update_config[0].max_unavailable_percentage == null
    )
    error_message = "Consumers must be able to opt out of a CMK and select absolute node-update limits explicitly."
  }
}

run "creates_access_entries_and_scoped_policy_associations" {
  command = apply

  variables {
    default_tags = {
      Environment = "test"
      Owner       = "platform"
      Project     = "eks-module"
    }

    eks_config = {
      access = {
        control_plane = {
          name = "access-cluster"
          vpc_config = {
            subnet_ids = [
              "subnet-0123456789abcdef0",
              "subnet-0123456789abcdef1",
            ]
          }
          irsa = {
            enabled = false
          }
          access_entries = {
            developers = {
              principal_arn = "arn:aws:iam::123456789012:role/developers"
              policy_associations = {
                view = {
                  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
                  access_scope = {
                    type       = "namespace"
                    namespaces = ["apps"]
                  }
                }
              }
            }
          }
          pod_identity_associations = {
            external_dns = {
              namespace       = "networking"
              service_account = "external-dns"
              role_arn        = "arn:aws:iam::123456789012:role/external-dns"
            }
          }
        }
      }
    }
  }

  assert {
    condition = (
      length(aws_eks_access_entry.this) == 1 &&
      length(aws_eks_access_policy_association.this) == 1 &&
      aws_eks_access_policy_association.this["access||developers||view"].access_scope[0].namespaces == toset(["apps"]) &&
      length(aws_eks_pod_identity_association.this) == 1 &&
      contains(keys(aws_eks_addon.this), "access||eks-pod-identity-agent")
    )
    error_message = "EKS API access and Pod Identity must support modern, scoped authorization."
  }
}

run "supports_bottlerocket_and_managed_eks_capabilities" {
  command = apply

  variables {
    default_tags = {
      Environment = "test"
      Owner       = "platform"
      Project     = "eks-module"
    }

    eks_config = {
      modern = {
        control_plane = {
          name = "modern-cluster"
          vpc_config = {
            subnet_ids = [
              "subnet-0123456789abcdef0",
              "subnet-0123456789abcdef1",
            ]
          }
          irsa = {
            enabled = false
          }
          capabilities = {
            ack = {
              type = "ACK"
              role_inline_policy = jsonencode({
                Version = "2012-10-17"
                Statement = [{
                  Effect   = "Allow"
                  Action   = "sts:AssumeRole"
                  Resource = "arn:aws:iam::123456789012:role/ack-resource-role"
                }]
              })
            }
            argocd = {
              type = "ARGOCD"
              role_policy_arns = {
                repository_read = "arn:aws:iam::123456789012:policy/argocd-repository-read"
              }
              argo_cd = {
                aws_idc = {
                  idc_instance_arn = "arn:aws:sso:::instance/ssoins-0123456789abcdef"
                  idc_region       = "us-east-1"
                }
                rbac_role_mappings = {
                  administrators = {
                    role = "ADMIN"
                    identities = [{
                      id   = "1234567890-abcdef"
                      type = "SSO_GROUP"
                    }]
                  }
                }
              }
            }
            kro = {
              type = "KRO"
            }
          }
        }

        node_groups = {
          bottlerocket = {
            ami_type       = "BOTTLEROCKET_x86_64"
            instance_types = ["m7i.large"]
            launch_template = {
              user_data = <<-TOML
                [settings.kubernetes]
                max-pods = 42
              TOML
            }
          }
        }
      }
    }
  }

  assert {
    condition = (
      aws_eks_node_group.this["modern||bottlerocket"].ami_type == "BOTTLEROCKET_x86_64" &&
      aws_launch_template.node["modern||bottlerocket"].image_id == null &&
      base64decode(aws_launch_template.node["modern||bottlerocket"].user_data) == "[settings.kubernetes]\nmax-pods = 42\n"
    )
    error_message = "Bottlerocket must use an EKS-managed AMI and preserve TOML launch-template user data."
  }

  assert {
    condition = (
      length(aws_eks_capability.this) == 3 &&
      aws_eks_capability.this["modern||ack"].type == "ACK" &&
      aws_eks_capability.this["modern||argocd"].configuration[0].argo_cd[0].aws_idc[0].idc_region == "us-east-1" &&
      aws_eks_capability.this["modern||kro"].type == "KRO"
    )
    error_message = "ACK, Argo CD, and KRO capabilities must be created from the typed map."
  }

  assert {
    condition = (
      length(aws_iam_role.capability) == 3 &&
      length(aws_iam_role_policy.capability) == 1 &&
      length(aws_iam_role_policy_attachment.capability) == 1
    )
    error_message = "Capabilities must receive dedicated managed roles and only the explicitly configured policies."
  }
}

run "supports_an_external_capability_role" {
  command = apply

  variables {
    default_tags = {
      Environment = "test"
      Owner       = "platform"
      Project     = "eks-module"
    }

    eks_config = {
      external_capability = {
        control_plane = {
          name = "external-capability"
          vpc_config = {
            subnet_ids = ["subnet-a", "subnet-b"]
          }
          irsa = {
            enabled = false
          }
          capabilities = {
            ack = {
              type     = "ACK"
              role_arn = "arn:aws:iam::123456789012:role/external-ack-capability-role"
            }
          }
        }
      }
    }
  }

  assert {
    condition = (
      length(aws_eks_capability.this) == 1 &&
      length(aws_iam_role.capability) == 0 &&
      aws_eks_capability.this["external_capability||ack"].role_arn == "arn:aws:iam::123456789012:role/external-ack-capability-role"
    )
    error_message = "An external capability role must bypass managed IAM role creation."
  }
}

run "creates_a_pure_auto_mode_cluster_with_managed_iam" {
  command = apply

  variables {
    default_tags = {
      Environment = "test"
      Owner       = "platform"
      Project     = "eks-module"
    }

    eks_config = {
      auto = {
        control_plane = {
          name      = "auto-mode-cluster"
          auto_mode = {}
          vpc_config = {
            subnet_ids = ["subnet-a", "subnet-b"]
          }
          irsa = {
            enabled = false
          }
          pod_identity_associations = {
            workload = {
              namespace       = "apps"
              service_account = "workload"
              role_arn        = "arn:aws:iam::123456789012:role/workload"
            }
          }
        }
      }
    }
  }

  assert {
    condition = (
      aws_eks_cluster.this["auto"].compute_config[0].enabled &&
      aws_eks_cluster.this["auto"].compute_config[0].node_pools == toset(["general-purpose", "system"]) &&
      aws_eks_cluster.this["auto"].storage_config[0].block_storage[0].enabled &&
      aws_eks_cluster.this["auto"].kubernetes_network_config[0].elastic_load_balancing[0].enabled
    )
    error_message = "Auto Mode must enable compute, built-in pools, block storage, and load balancing together."
  }

  assert {
    condition = (
      length(aws_iam_role.auto_mode_node) == 1 &&
      length(aws_iam_role_policy_attachment.auto_mode_node) == 2 &&
      length(aws_iam_role_policy_attachment.cluster) == 5 &&
      contains(keys(aws_iam_role_policy_attachment.cluster), "auto||AmazonEKSBlockStoragePolicyV2")
    )
    error_message = "Managed Auto Mode roles must receive the AWS-recommended cluster and minimal node policies."
  }

  assert {
    condition = (
      length(aws_eks_node_group.this) == 0 &&
      length(aws_eks_addon.this) == 0 &&
      length(aws_eks_pod_identity_association.this) == 1
    )
    error_message = "Pure Auto Mode must not create standard node groups or core add-ons, including the built-in Pod Identity agent."
  }
}

run "supports_hybrid_auto_mode_and_managed_node_groups" {
  command = apply

  variables {
    default_tags = {
      Environment = "test"
      Owner       = "platform"
      Project     = "eks-module"
    }

    eks_config = {
      hybrid = {
        control_plane = {
          name      = "hybrid-cluster"
          auto_mode = {}
          vpc_config = {
            subnet_ids = ["subnet-a", "subnet-b"]
          }
          irsa = {
            enabled = false
          }
        }
        node_groups = {
          existing = {}
        }
      }
    }
  }

  assert {
    condition = (
      length(aws_eks_node_group.this) == 1 &&
      length(aws_iam_role.node) == 1 &&
      length(aws_iam_role.auto_mode_node) == 1 &&
      length(aws_eks_addon.this) == 3
    )
    error_message = "Hybrid Auto Mode must preserve managed node groups and their three standard add-ons."
  }
}

run "supports_auto_mode_without_builtin_node_pools" {
  command = apply

  variables {
    default_tags = {
      Environment = "test"
      Owner       = "platform"
      Project     = "eks-module"
    }

    eks_config = {
      custom_pools = {
        control_plane = {
          name = "custom-pools-cluster"
          auto_mode = {
            node_pools = []
          }
          vpc_config = {
            subnet_ids = ["subnet-a", "subnet-b"]
          }
          irsa = {
            enabled = false
          }
        }
      }
    }
  }

  assert {
    condition = (
      aws_eks_cluster.this["custom_pools"].compute_config[0].enabled &&
      length(aws_eks_cluster.this["custom_pools"].compute_config[0].node_pools) == 0 &&
      aws_eks_cluster.this["custom_pools"].compute_config[0].node_role_arn == null &&
      length(aws_iam_role.auto_mode_node) == 0
    )
    error_message = "Empty built-in pools must leave node-role ownership to custom NodeClasses."
  }
}

run "supports_an_external_auto_mode_node_role" {
  command = apply

  variables {
    default_tags = {
      Environment = "test"
      Owner       = "platform"
      Project     = "eks-module"
    }

    eks_config = {
      external_auto_role = {
        control_plane = {
          name = "external-auto-role-cluster"
          auto_mode = {
            node_role_arn = "arn:aws:iam::123456789012:role/external-auto-node-role"
          }
          vpc_config = {
            subnet_ids = ["subnet-a", "subnet-b"]
          }
          irsa = {
            enabled = false
          }
        }
      }
    }
  }

  assert {
    condition = (
      aws_eks_cluster.this["external_auto_role"].compute_config[0].node_role_arn == "arn:aws:iam::123456789012:role/external-auto-node-role" &&
      length(aws_iam_role.auto_mode_node) == 0 &&
      length(aws_iam_role_policy_attachment.auto_mode_node) == 0
    )
    error_message = "An external Auto Mode node role must bypass managed node-role creation and attachments."
  }
}

run "disables_all_auto_mode_capabilities_together" {
  command = apply

  variables {
    default_tags = {
      Environment = "test"
      Owner       = "platform"
      Project     = "eks-module"
    }

    eks_config = {
      disabled_auto = {
        control_plane = {
          name = "disabled-auto-mode-cluster"
          auto_mode = {
            enabled = false
          }
          vpc_config = {
            subnet_ids = ["subnet-a", "subnet-b"]
          }
          irsa = {
            enabled = false
          }
        }
      }
    }
  }

  assert {
    condition = (
      !aws_eks_cluster.this["disabled_auto"].compute_config[0].enabled &&
      !aws_eks_cluster.this["disabled_auto"].storage_config[0].block_storage[0].enabled &&
      !aws_eks_cluster.this["disabled_auto"].kubernetes_network_config[0].elastic_load_balancing[0].enabled &&
      length(aws_iam_role.auto_mode_node) == 0 &&
      length(aws_iam_role_policy_attachment.cluster) == 1 &&
      length(aws_eks_addon.this) == 3
    )
    error_message = "Disabled Auto Mode must turn off all three capabilities and restore standard add-on defaults without Auto Mode IAM."
  }
}

run "rejects_auto_mode_with_config_map_only_authentication" {
  command = plan

  variables {
    default_tags = {
      Environment = "test"
      Owner       = "platform"
      Project     = "eks-module"
    }

    eks_config = {
      legacy_auth = {
        control_plane = {
          name      = "legacy-auth-cluster"
          auto_mode = {}
          access_config = {
            authentication_mode = "CONFIG_MAP"
          }
          vpc_config = {
            subnet_ids = ["subnet-a", "subnet-b"]
          }
        }
      }
    }
  }

  expect_failures = [var.eks_config]
}

run "rejects_auto_mode_with_self_managed_addon_bootstrap" {
  command = plan

  variables {
    default_tags = {
      Environment = "test"
      Owner       = "platform"
      Project     = "eks-module"
    }

    eks_config = {
      bootstrap_conflict = {
        control_plane = {
          name                          = "bootstrap-conflict-cluster"
          auto_mode                     = {}
          bootstrap_self_managed_addons = true
          vpc_config = {
            subnet_ids = ["subnet-a", "subnet-b"]
          }
        }
      }
    }
  }

  expect_failures = [var.eks_config]
}

run "rejects_unknown_auto_mode_builtin_node_pools" {
  command = plan

  variables {
    default_tags = {
      Environment = "test"
      Owner       = "platform"
      Project     = "eks-module"
    }

    eks_config = {
      invalid_pool = {
        control_plane = {
          name = "invalid-pool-cluster"
          auto_mode = {
            node_pools = ["custom"]
          }
          vpc_config = {
            subnet_ids = ["subnet-a", "subnet-b"]
          }
        }
      }
    }
  }

  expect_failures = [var.eks_config]
}

run "rejects_managed_auto_mode_role_settings_with_an_external_role" {
  command = plan

  variables {
    default_tags = {
      Environment = "test"
      Owner       = "platform"
      Project     = "eks-module"
    }

    eks_config = {
      conflicting_role = {
        control_plane = {
          name = "conflicting-role-cluster"
          auto_mode = {
            node_role_arn  = "arn:aws:iam::123456789012:role/external-auto-node-role"
            node_role_name = "must-not-be-used"
          }
          vpc_config = {
            subnet_ids = ["subnet-a", "subnet-b"]
          }
        }
      }
    }
  }

  expect_failures = [var.eks_config]
}

run "rejects_auto_mode_role_settings_when_disabled" {
  command = plan

  variables {
    default_tags = {
      Environment = "test"
      Owner       = "platform"
      Project     = "eks-module"
    }

    eks_config = {
      disabled_role = {
        control_plane = {
          name = "disabled-role-cluster"
          auto_mode = {
            enabled        = false
            node_role_name = "unused-role"
          }
          vpc_config = {
            subnet_ids = ["subnet-a", "subnet-b"]
          }
        }
      }
    }
  }

  expect_failures = [var.eks_config]
}

run "rejects_duplicate_capability_types" {
  command = plan

  variables {
    default_tags = {
      Environment = "test"
      Owner       = "platform"
      Project     = "eks-module"
    }

    eks_config = {
      duplicate = {
        control_plane = {
          name = "duplicate-capabilities"
          vpc_config = {
            subnet_ids = ["subnet-a", "subnet-b"]
          }
          capabilities = {
            kro_primary = {
              type = "KRO"
            }
            kro_secondary = {
              type = "kro"
            }
          }
        }
      }
    }
  }

  expect_failures = [var.eks_config]
}

run "rejects_ack_without_explicit_permissions" {
  command = plan

  variables {
    default_tags = {
      Environment = "test"
      Owner       = "platform"
      Project     = "eks-module"
    }

    eks_config = {
      unsafe_ack = {
        control_plane = {
          name = "unsafe-ack"
          vpc_config = {
            subnet_ids = ["subnet-a", "subnet-b"]
          }
          capabilities = {
            ack = {
              type = "ACK"
            }
          }
        }
      }
    }
  }

  expect_failures = [var.eks_config]
}

run "rejects_argocd_without_identity_center_configuration" {
  command = plan

  variables {
    default_tags = {
      Environment = "test"
      Owner       = "platform"
      Project     = "eks-module"
    }

    eks_config = {
      incomplete_argocd = {
        control_plane = {
          name = "incomplete-argocd"
          vpc_config = {
            subnet_ids = ["subnet-a", "subnet-b"]
          }
          capabilities = {
            argocd = {
              type = "ARGOCD"
            }
          }
        }
      }
    }
  }

  expect_failures = [var.eks_config]
}

run "rejects_an_unrestricted_public_endpoint" {
  command = plan

  variables {
    default_tags = {
      Environment = "test"
      Owner       = "platform"
      Project     = "eks-module"
    }

    eks_config = {
      unsafe = {
        control_plane = {
          name = "unsafe-cluster"
          vpc_config = {
            subnet_ids             = ["subnet-a", "subnet-b"]
            endpoint_public_access = true
            public_access_cidrs    = ["0.0.0.0/0"]
          }
        }
      }
    }
  }

  expect_failures = [var.eks_config]
}

run "rejects_missing_required_tags" {
  command = plan

  variables {
    default_tags = {
      Environment = "test"
      Project     = "eks-module"
    }
    eks_config = {}
  }

  expect_failures = [var.default_tags]
}
