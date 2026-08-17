# Architecture and ownership boundaries

## Design goal

The module is a self-contained EKS composition layer. It consumes explicit network and IAM identifiers, creates EKS-specific resources, and exposes stable outputs for Kubernetes and GitOps layers. It has no dependency on another OpsTeamHub Terraform module and no SSH-based module source.

```text
Calling root module
├── AWS provider, credentials, aliases, Region, backend and state
├── VPC/subnet outputs
├── optional external IAM/KMS resources
└── terraform-aws-eks
    ├── EKS control plane and CloudWatch log group
    ├── optional managed KMS key
    ├── managed or external cluster/node IAM roles
    ├── optional EKS Auto Mode and its managed or external node role
    ├── baseline EKS add-ons for standard and hybrid compute
    ├── optional managed ACK, Argo CD, and KRO capabilities
    ├── managed or external capability IAM roles
    ├── launch templates and managed node groups
    ├── Access API entries and policy associations
    ├── IAM OIDC provider for IRSA
    └── EKS Pod Identity associations
```

## Invariants

- The `eks_config` key is the stable Terraform identity; `control_plane.name` is the exact AWS name.
- At least two subnet IDs are explicit. No data source selects networks by mutable tags.
- `Environment`, `Project`, and `Owner` tags are present on every taggable resource.
- A public EKS API endpoint cannot be configured with an unrestricted CIDR through the module contract.
- Managed node launch templates require IMDSv2 and encrypted storage by default.
- Core add-on versions are not hard-coded to a Kubernetes minor release.
- EKS Auto Mode is opt-in; compute, Elastic Load Balancing, and block storage are always enabled or disabled together.
- Pure Auto Mode omits standard core add-ons, while hybrid clusters retain them for managed node groups.
- EKS Capabilities are opt-in, limited to one per type per cluster, and never receive implicit AWS administrator permissions.
- Provider and backend configuration never live inside the reusable module.
- Mocked tests never contact or mutate an AWS account.

## Resource ordering

The managed cluster IAM role and its policy attachments are created before the EKS control plane. Auto Mode adds its four AWS-managed cluster policies only while enabled. Its managed node role and minimal policy attachments also precede the cluster so the role is ready when compute is enabled. A managed KMS key policy references the resolved cluster role, and the cluster references the key. CloudWatch log-group creation also precedes the cluster so EKS writes to the intended retention policy from the beginning.

Node IAM attachments and launch templates precede managed node groups. Access, identity-provider, add-on, capability, IRSA, and Pod Identity resources use the created cluster name. Pod Identity associations wait for add-ons, including the automatically inserted Pod Identity agent on standard and hybrid clusters; pure Auto Mode supplies that agent as a core component. A module-managed capability role and its explicit policies precede the capability resource.

## Trust boundaries

The module creates only baseline IAM permissions. Additional policies are explicit maps, and external role ARNs are treated as opaque caller-owned dependencies. Auto Mode expands the managed cluster role with the four AWS policies required to provision compute, networking, load balancers, and storage; its managed node role trusts only EC2 and has the two AWS-recommended minimal policies. A module-managed capability role trusts only `capabilities.eks.amazonaws.com`; KRO and Argo CD can start with that trust-only role, while ACK must receive explicit permissions or an external role. The module does not create Kubernetes RBAC objects, custom Auto Mode NodePool/NodeClass resources, service-account trust policies, security-group rules, or network routes.

EKS automatically creates a capability access entry and baseline Kubernetes policy. That does not replace caller-owned RBAC for Argo CD target clusters or least-privilege authorization for users creating ACK custom resources. Deleting a capability uses `RETAIN`; its managed Kubernetes resources and CRDs must be handled deliberately before deletion.

Kubernetes API access has two separate paths:

1. Network reachability, controlled by endpoint settings, VPC routing, and security groups owned by the caller.
2. Authentication and authorization, controlled by EKS access entries, policies, legacy ConfigMap compatibility, and optional external OIDC identity providers.

Both paths must be reviewed before disabling bootstrap creator permissions or the legacy ConfigMap mode.

## Change and release policy

Changes to names, subnet IDs, IP family, service CIDR, KMS ownership, Auto Mode node role ARN, or launch-template AMIs can replace stateful infrastructure or nodes. Treat plans containing an EKS cluster replacement as blocked until the migration is explicitly approved. Enabling, disabling, or changing Auto Mode pools also requires an explicit workload migration and disruption review.

The repository CI validates formatting, provider schemas, mocked tests, examples, lint, agent configuration, and high/critical IaC findings. A baseline AWS Dev smoke on 2026-08-17 validated organization policies, restricted endpoint reachability, EKS 1.35, AL2023 managed-node joins, core add-ons, Pod Identity, Karpenter controller/CRD readiness, and clean destroy behavior. Provider mocks and that baseline do not validate private-only endpoint access, Bottlerocket node joins, capability or Auto Mode readiness, custom provisioning, Kubernetes RBAC, workload migration, interruption handling, or every account quota, so those scenarios remain explicit release gates.
