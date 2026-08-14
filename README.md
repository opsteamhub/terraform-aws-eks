# Terraform AWS EKS module

Reusable Terraform module for Amazon EKS clusters, managed node groups, baseline add-ons, EKS Capabilities, IAM, envelope encryption, access entries, IRSA, and EKS Pod Identity.

The v2 contract is intentionally explicit: the caller supplies subnet IDs and provider configuration, while this module owns the EKS-specific resources. It has no Git or registry module dependencies, so a private cluster with one managed node group can be created from a small configuration.

> Upgrading from the current `master` implementation is a major migration. Read [Migration to v2](docs/MIGRATION-v2.md) before changing a live state.

## What it manages

- One or more EKS control planes with stable, caller-defined names.
- Private-only API endpoints by default; public endpoints require restricted CIDRs.
- Customer-managed KMS encryption for Kubernetes secrets by default.
- All five control-plane log types and a correctly named CloudWatch log group.
- `coredns`, `kube-proxy`, and `vpc-cni` add-ons without stale hard-coded versions.
- Managed node groups on AL2023 or Bottlerocket with IMDSv2, encrypted gp3 root volumes, and node repair.
- Cluster and node IAM roles, or caller-supplied external roles.
- Opt-in managed ACK, Argo CD, and KRO EKS Capabilities with dedicated or external IAM roles.
- EKS Access API entries and scoped access-policy associations.
- IRSA on every supported Kubernetes version and EKS Pod Identity on demand.
- Organizational tags on every taggable resource.

The module deliberately does not discover or create a VPC, subnets, NAT, route tables, security boundaries outside EKS, Kubernetes workloads, or a remote state backend. Pass outputs from a VPC stack directly to `subnet_ids`.

## Compatibility

| Component | Supported range |
| --- | --- |
| Terraform | `>= 1.7.0, < 2.0.0` |
| AWS provider | `>= 6.25, < 7.0` |
| TLS provider | `>= 4.0, < 5.0` |
| Default Kubernetes version | `1.35` |
| Default managed-node AMI | `AL2023_x86_64_STANDARD` |

The default Kubernetes version is a convenience, not an evergreen guarantee. Pin it explicitly in production and review the [Amazon EKS version lifecycle](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html) before upgrades.

## Quick start

```hcl
module "eks" {
  source = "git::https://github.com/opsteamhub/terraform-aws-eks.git?ref=<released-version>"

  default_tags = {
    Environment = "development"
    Owner       = "platform"
    Project     = "container-platform"
  }

  eks_config = {
    primary = {
      control_plane = {
        name = "development-eks"
        vpc_config = {
          subnet_ids = module.vpc.private_subnet_ids
        }
      }

      node_groups = {
        system = {}
      }
    }
  }
}
```

The consumer must configure the AWS provider and pass at least two suitable subnet IDs. Do not consume an unreviewed branch or an unpinned `master` reference in production.

## Secure defaults and operational choices

| Behavior | Default | How to change it |
| --- | --- | --- |
| EKS API | Private enabled, public disabled | Set `endpoint_public_access = true` and explicit restricted `public_access_cidrs` |
| Secret encryption | New rotating customer-managed KMS key | Pass `encryption_config.key_arn` or set `encryption_config.enabled = false` |
| Control-plane logs | All five types, retained 30 days | Change `enabled_cluster_log_types` or `logs` |
| Cluster access | `API_AND_CONFIG_MAP`, creator admin enabled | Configure `access_config` and `access_entries` |
| Add-ons | CoreDNS, kube-proxy, VPC CNI | Override the `addons` map; omit hard-coded versions to let EKS select compatible builds |
| EKS Capabilities | Disabled | Add `capabilities` entries for ACK, Argo CD, or KRO; only one of each type per cluster |
| IRSA | Enabled | Set `irsa.enabled = false` |
| Nodes | AL2023, IMDSv2 required, encrypted 20 GiB gp3, repair enabled | Configure each node group's `launch_template`, `ami_type`, and `node_repair_config` |
| Desired size | Ignored after creation | Designed for Cluster Autoscaler/Karpenter ownership; change min/max in Terraform |

Creating a KMS key, CloudWatch Logs, the EKS control plane, EC2 nodes, EKS Capabilities, and optional public IPv4 traffic can incur AWS charges. Each active capability is billed hourly, and resources managed through ACK, Argo CD, or KRO may add their own charges. A private endpoint also requires a network path from operators and automation to the VPC.

## Documentation

- [Configuration reference](docs/CONFIGURATION.md)
- [Architecture and ownership boundaries](docs/ARCHITECTURE.md)
- [Migration to v2](docs/MIGRATION-v2.md)
- [Gap analysis and future scope](docs/GAP_ANALYSIS.md)
- [Basic example](examples/basic)
- [Complete example](examples/complete)
- [Bottlerocket example](examples/bottlerocket)
- [EKS Capabilities example](examples/capabilities)
- [Repository instructions for humans and agents](AGENTS.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)

## Outputs

The main outputs are `clusters`, `cluster_names`, `node_groups`, `launch_templates`, `capabilities`, `capability_role_arns`, `kms_key_arns`, `oidc_provider_arns`, `pod_identity_association_arns`, `cluster_role_arns`, and `node_role_arns`. Certificate authority data is exposed separately as the sensitive `cluster_certificate_authority_data` output.

`eks_clusters_name` remains as a deprecated alias for `cluster_names` during the v2 transition.

## Verification

The test suite uses mocked providers and requires no AWS credentials:

```bash
terraform fmt -check -recursive
terraform init -backend=false -input=false
terraform validate
terraform test -test-directory=testing

terraform -chdir=examples/basic init -backend=false -input=false
terraform -chdir=examples/basic validate
terraform -chdir=examples/complete init -backend=false -input=false
terraform -chdir=examples/complete validate
terraform -chdir=examples/bottlerocket init -backend=false -input=false
terraform -chdir=examples/bottlerocket validate
terraform -chdir=examples/capabilities init -backend=false -input=false
terraform -chdir=examples/capabilities validate
```

Mocked tests validate contracts and the Terraform graph; they do not replace a reviewed plan and a controlled apply in a disposable AWS sandbox before a major release.
