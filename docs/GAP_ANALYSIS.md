# Gap analysis and future scope

This document records the v1 audit so future maintainers and coding agents do not reintroduce removed behavior or infer unsupported features from old README claims.

## Resolved in v2

| v1 issue | v2 resolution |
| --- | --- |
| Terraform `~> 1.5.1` rejected current Terraform; AWS provider was pinned to an old 5.x patch | Terraform 1.7+ and AWS provider 6.25+ ranges, tested with current schemas |
| KMS and launch templates used unpinned SSH Git sources | Both are native resources inside this module; no direct module dependencies |
| VPC and subnet selection depended on mutable tag queries | At least two explicit subnet IDs are required |
| Cluster name and service CIDR were random | Exact caller-defined name and stable configurable service CIDR |
| CloudWatch log group path did not match EKS | `/aws/eks/<cluster-name>/cluster` with managed retention |
| Add-on resource was commented out and versions were stale | Live add-on resources with no hard-coded compatible build by default |
| OIDC creation was limited to EKS 1.28 and 1.29 | IRSA works independently of the selected supported version |
| External OIDC resource referenced the wrong cluster and omitted required fields | Fully typed identity-provider map and correct resource keys |
| AL2 bootstrap and CNI versions were stale; `null_data_source` was deprecated | EKS-managed AL2023 bootstrap by default; custom user data is explicit |
| IAM included obsolete or accidental principals, a debug policy name, and wrong inline-policy iteration | Minimal service trusts and current managed-policy attachments |
| Node update settings and repair were not applied | Both are implemented and tested |
| Bottlerocket was possible only through an untested `ami_type` escape hatch | EKS-managed x86_64 Bottlerocket has a validating example and mocked TOML user-data test; ARM remains configurable but needs sandbox evidence |
| EKS Auto Mode was absent | Typed, opt-in pure and hybrid Auto Mode with coordinated cluster capabilities, managed/external IAM roles, built-in-pool controls, outputs, tests, example, and migration guidance |
| ACK, Argo CD, and KRO were absent | Typed, opt-in EKS Capability resources with managed/external IAM roles, guardrails, outputs, tests, and examples |
| Debug output and README-only outputs/features drifted from code | Structured outputs and docs match the resource graph |
| Examples were stale, non-validating, and included an undeclared Kubernetes provider | Credential-free mocked tests plus basic and complete validating examples |
| No CI, security policy, migration guide, or agent context | Pinned CI, IaC scan, security/reporting policy, migration runbook, `AGENTS.md`, and Kiro agent configuration |

## Deliberate non-goals

- VPC, subnet, NAT, routing, endpoint security-group rules, private DNS, and operator connectivity.
- Kubernetes resources, Helm releases, self-managed GitOps bootstrap, Cluster Autoscaler, or Karpenter installation. Managed Argo CD is available only through EKS Capabilities.
- Creation of application IAM roles and their trust policies; the module only associates supplied roles through IRSA or Pod Identity.
- Fargate profiles, EKS Hybrid Nodes, Outposts, and EKS Anywhere. Auto Mode coexistence with managed node groups is supported, but EKS Hybrid Nodes is a separate product feature.
- Windows, GPU, and custom AMI bootstrap automation. These can use explicit `ami_type` or `image_id`/`user_data`, but require separate tested examples before becoming supported presets.
- Automatic Kubernetes or add-on upgrades. Production versions remain an explicit release decision.
- Automatic state migration from v1; resource ownership varies too much for a safe generic script.

## Candidate follow-ups

1. Run the v2 graph through a disposable AWS sandbox, including private endpoint access, add-on, capability, and Auto Mode readiness, pure and hybrid compute, AL2023 and Bottlerocket node joins, Access API, IRSA, Pod Identity, and destroy behavior.
2. Publish a versioned v2 release only after the dependency-free EKS PR is approved and the sandbox evidence is attached.
3. Add dedicated presets only when there is a real consumer and acceptance test for Bottlerocket ARM/GPU, Fargate, custom Auto Mode NodePool/NodeClass resources, or self-managed Karpenter.
4. Evaluate OPA/Conftest organization policy and Terraform plan fixtures after the first stable state migration.
5. Add environment-specific `moved` blocks or import manifests in consumer repositories, not in this generic module.
