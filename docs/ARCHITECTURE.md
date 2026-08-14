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
    ├── baseline EKS add-ons
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
- Provider and backend configuration never live inside the reusable module.
- Mocked tests never contact or mutate an AWS account.

## Resource ordering

The managed cluster IAM role and its policy attachments are created before the EKS control plane. A managed KMS key policy references the resolved cluster role, and the cluster references the key. CloudWatch log-group creation also precedes the cluster so EKS writes to the intended retention policy from the beginning.

Node IAM attachments and launch templates precede managed node groups. Access, identity-provider, add-on, IRSA, and Pod Identity resources use the created cluster name. Pod Identity associations wait for add-ons, including the automatically inserted Pod Identity agent.

## Trust boundaries

The module creates only baseline IAM permissions. Additional policies are explicit maps, and external role ARNs are treated as opaque caller-owned dependencies. It does not create Kubernetes RBAC objects, service-account trust policies, security-group rules, or network routes.

Kubernetes API access has two separate paths:

1. Network reachability, controlled by endpoint settings, VPC routing, and security groups owned by the caller.
2. Authentication and authorization, controlled by EKS access entries, policies, legacy ConfigMap compatibility, and optional external OIDC identity providers.

Both paths must be reviewed before disabling bootstrap creator permissions or the legacy ConfigMap mode.

## Change and release policy

Changes to names, subnet IDs, IP family, service CIDR, KMS ownership, or launch-template AMIs can replace stateful infrastructure or nodes. Treat plans containing an EKS cluster replacement as blocked until the migration is explicitly approved.

The repository CI validates formatting, provider schemas, mocked tests, examples, lint, agent configuration, and high/critical IaC findings. A real sandbox plan/apply remains a release gate for a major version because provider mocks cannot validate AWS quotas, organization policies, network reachability, add-on compatibility, or EKS API behavior.
