# Configuration reference

## Root inputs

| Input | Type | Required | Notes |
| --- | --- | --- | --- |
| `default_tags` | `map(string)` | Yes | Must contain non-empty `Environment`, `Project`, and `Owner` values. |
| `eks_config` | `map(object)` | Yes | Clusters keyed by a stable Terraform identifier. The key does not alter the AWS cluster name. |

Provider configuration, credentials, Region, aliases, backend, state encryption, and state locking belong to the calling root module.

## Control plane

Each `eks_config` item requires `control_plane.name` and `control_plane.vpc_config.subnet_ids`. The subnets should span at least two Availability Zones and have the routing required by the selected endpoint and node egress model.

| Field | Default | Notes |
| --- | --- | --- |
| `name` | Required | Exact AWS EKS cluster name; no suffix is added. |
| `version` | `1.35` | Pin explicitly for production and manage upgrades deliberately. |
| `role_arn` | Managed role | Supplying an ARN disables creation of the cluster role and its attachments. |
| `role_name` | `<cluster>-cluster-role` | Used only for a managed role. |
| `role_permissions_boundary` | `null` | Optional boundary for a managed role. |
| `role_additional_policy_arns` | `{}` | Named map of additional policy ARNs for a managed role. |
| `enabled_cluster_log_types` | All five types | API, audit, authenticator, controller manager, and scheduler logs. |
| `bootstrap_self_managed_addons` | `false` | The module manages baseline add-ons as separate resources. |
| `deletion_protection` | `false` | Enable in critical environments after validating your lifecycle process. |

### Networking

`vpc_config.subnet_ids` is required. This module performs no tag-based VPC or subnet discovery.

| Field | Default | Notes |
| --- | --- | --- |
| `endpoint_private_access` | `true` | Requires operator and automation connectivity to the VPC. |
| `endpoint_public_access` | `false` | When enabled, restricted CIDRs are mandatory. |
| `public_access_cidrs` | `[]` | `0.0.0.0/0` and `::/0` are rejected. |
| `security_group_ids` | `[]` | Additional control-plane security groups. |

The service network defaults to IPv4 `172.20.0.0/16`. Set `kubernetes_network_config.service_ipv4_cidr` before creation if that range overlaps connected networks. Changing the service CIDR or IP family replaces a cluster.

### Encryption and logs

`encryption_config = {}` creates a dedicated KMS key with rotation and a 30-day deletion window. Set `key_arn` to reuse an approved key or `enabled = false` to skip a customer-managed key. The KMS key policy delegates account administration and grants the cluster role only the cryptographic and grant operations required by EKS.

CloudWatch logs use `/aws/eks/<cluster-name>/cluster`, retain data for 30 days, and can use an external `logs.kms_key_id`.

### Add-ons

`addons` is a map keyed by the EKS add-on name. CoreDNS, kube-proxy, and VPC CNI are enabled by default. Leave `addon_version` unset to allow EKS to choose a compatible build; pin a tested version where release governance requires it.

```hcl
addons = {
  coredns = {
    configuration_values = jsonencode({ replicaCount = 3 })
  }
  kube-proxy = {}
  vpc-cni = {
    resolve_conflicts_on_update = "PRESERVE"
  }
}
```

### EKS Capabilities

`capabilities` is an opt-in map for the EKS-managed `ACK`, `ARGOCD`, and `KRO` services. The map key is the stable Terraform identity and becomes `capability_name` unless `name` is supplied. AWS permits only one capability of each type per cluster.

| Field | Default | Notes |
| --- | --- | --- |
| `name` | Map key | AWS capability name. Changing it replaces the resource. |
| `type` | Required | `ACK`, `ARGOCD`, or `KRO`; changing it replaces the resource. |
| `role_arn` | Managed role | External same-account capability role. Supplying it disables managed role creation. |
| `role_name` | `<cluster>-<capability>-capability-role` | Used only for a managed role. |
| `role_permissions_boundary` | `null` | Optional boundary for a managed role. |
| `role_policy_arns` | `{}` | Explicit policy attachments for a managed role. |
| `role_inline_policy` | `null` | Explicit JSON policy for a managed role. |
| `delete_propagation_policy` | `RETAIN` | The only value currently supported by EKS. |
| `argo_cd` | `null` | Required only for `ARGOCD`; configures Identity Center, optional VPC endpoints, and RBAC mappings. |

When the module creates the role, its trust policy allows only `sts:AssumeRole` and `sts:TagSession` from `capabilities.eks.amazonaws.com`. It does not attach administrator policies. KRO can use a trust-only role, although composed resources may require separate Kubernetes RBAC. Argo CD needs additional IAM permissions only for AWS-backed repositories, secrets, images, or other integrations. ACK must receive an external role or explicit managed-role policies; prefer role selectors and narrowly scoped target roles over broad permissions.

```hcl
capabilities = {
  ack = {
    type     = "ACK"
    role_arn = aws_iam_role.ack_capability.arn
  }

  argocd = {
    type = "ARGOCD"
    argo_cd = {
      aws_idc = {
        idc_instance_arn = var.idc_instance_arn
        idc_region       = "us-east-1"
      }
      rbac_role_mappings = {
        administrators = {
          role = "ADMIN"
          identities = [{
            id   = var.idc_admin_group_id
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
```

Argo CD requires AWS Identity Center and at least one RBAC mapping. The optional `network_access.vpce_ids` field restricts its network path to configured VPC endpoints. The returned `capabilities` output includes the Argo CD server URL when AWS makes it available.

EKS creates an access entry and baseline capability policy automatically. Argo CD still needs explicit RBAC on every target cluster. ACK users who can create its custom resources can manage AWS resources within the capability role's permissions. Capability deletion retains CRDs and managed Kubernetes resources, so delete or transfer those resources before removing the Terraform entry.

Capabilities incur hourly charges while active; AWS resources created through them are billed separately. See the [EKS Capabilities overview](https://docs.aws.amazon.com/eks/latest/userguide/capabilities.html), [capability IAM role guidance](https://docs.aws.amazon.com/eks/latest/userguide/capability-role.html), and [security considerations](https://docs.aws.amazon.com/eks/latest/userguide/capabilities-security.html).

## Access and workload identity

The default authentication mode is `API_AND_CONFIG_MAP` to support staged migration from the legacy `aws-auth` ConfigMap. `access_entries` are unavailable with `CONFIG_MAP` mode.

```hcl
access_entries = {
  developers = {
    principal_arn = "arn:aws:iam::123456789012:role/developers"
    policy_associations = {
      view_apps = {
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
        access_scope = {
          type       = "namespace"
          namespaces = ["apps"]
        }
      }
    }
  }
}
```

IRSA is enabled by default and creates an IAM OIDC provider for every Kubernetes version. Prefer a supplied `thumbprint_list` in restricted environments where the TLS endpoint cannot be read during planning.

`pod_identity_associations` creates EKS Pod Identity associations. When the map is non-empty, the module also enables `eks-pod-identity-agent` automatically.

```hcl
pod_identity_associations = {
  external_dns = {
    namespace       = "networking"
    service_account = "external-dns"
    role_arn        = aws_iam_role.external_dns.arn
  }
}
```

The IAM role trust policy for a Pod Identity role is owned by the caller; this module only creates the EKS association.

## Managed node groups

Node groups inherit the control-plane subnets unless `subnet_ids` is set. Defaults are designed for a small, production-shaped starting point:

| Field | Default |
| --- | --- |
| `ami_type` | `AL2023_x86_64_STANDARD` |
| `capacity_type` | `ON_DEMAND` |
| `instance_types` | `t3.medium` |
| `scaling_config` | desired 1, min 1, max 3 |
| `update_config` | maximum unavailable 33 percent |
| `node_repair_config.enabled` | `true` |
| Root volume | encrypted 20 GiB gp3 |
| Instance metadata | IMDSv2 required, hop limit 2 |

Terraform ignores only `scaling_config.desired_size` after creation so a Kubernetes autoscaler can own that value. Terraform continues to manage minimum and maximum size.

Supplying `launch_template.image_id` makes the node group use a custom AMI and suppresses EKS-managed `ami_type`, Kubernetes `version`, and `release_version`. The caller must provide correct bootstrap user data for a custom AMI. `launch_template.user_data` accepts plain text and the module base64-encodes it.

For EKS-managed Bottlerocket, set `ami_type` to `BOTTLEROCKET_x86_64` or `BOTTLEROCKET_ARM_64`, choose matching instance types, and leave `launch_template.image_id` unset. Optional `launch_template.user_data` must be valid Bottlerocket TOML; EKS merges it with its managed bootstrap settings. With a custom Bottlerocket `image_id`, EKS does not merge bootstrap data and the caller owns the complete configuration. See the [Bottlerocket example](../examples/bottlerocket) and [EKS launch-template requirements](https://docs.aws.amazon.com/eks/latest/userguide/launch-templates.html).

Supplying `launch_template.security_group_ids` replaces the security groups EKS would normally apply through the launch template. Include the required cluster-to-node connectivity and validate it in a sandbox.

External cluster, node, or capability role ARNs are never modified by this module. The caller must attach all required policies and trust before EKS creation.
