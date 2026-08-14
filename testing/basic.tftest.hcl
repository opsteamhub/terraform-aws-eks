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
