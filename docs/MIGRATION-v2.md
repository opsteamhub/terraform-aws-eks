# Migration to v2

Version 2 is a breaking redesign. Do not point a live state at v2 and apply immediately. The v1 module generated cluster names and service CIDRs, discovered subnets by tags, called unpinned SSH Git modules, and exposed a different resource-address graph.

## Before changing module source

1. Pin the current v1 commit and save a reviewed state backup using your normal backend procedure.
2. Record the actual EKS cluster name, Kubernetes service CIDR, subnet IDs, cluster/node role ARNs, KMS key ARN, add-on versions, OIDC provider ARN, and node-group launch-template IDs.
3. Confirm that the execution identity can read the cluster and move/import state but do not apply infrastructure changes.
4. Upgrade Terraform to at least 1.7 and the AWS provider to 6.25 or newer in a separate, reviewed change where practical.
5. Test the migration against a copy of state or a disposable environment first.

## Input changes

| v1 | v2 |
| --- | --- |
| `control_plane.name` plus a random suffix | `control_plane.name` is required and exact. Use the existing full AWS name, including its old suffix, for an in-place migration. |
| Tag-filter VPC/subnet discovery and `vpc_id` | Explicit `control_plane.vpc_config.subnet_ids`; node groups inherit them. |
| Random service CIDR | Stable default `172.20.0.0/16`; set the existing cluster's actual CIDR before state migration. |
| `control_plane.iam_role` object | Flat `role_arn`, `role_name`, `role_permissions_boundary`, and `role_additional_policy_arns`. |
| Node `iam_role` object | `node_role_arn`, `node_role_name`, `node_role_permissions_boundary`, and `node_role_additional_policy_arns`. |
| `addons` list and commented resource | `addons` map with live resources; core add-ons are enabled by default. |
| `encryption_config.provider` | Flat `encryption_config.key_arn` or a managed key by default. |
| `taint` list | `taints` map with stable keys. |
| External launch-template module and AMI filters | Built-in launch template; use EKS-managed AL2023 by default or pass an explicit `image_id` and bootstrap `user_data`. |
| Version-gated OIDC provider | `irsa.enabled`, available for every supported version. |
| One `eks_clusters_name` output | Structured cluster, node, IAM, KMS, OIDC, Pod Identity, capability, and launch-template outputs. The old output name remains as an alias. |

`default_tags` is new and mandatory with `Environment`, `Project`, and `Owner`.

## State-address changes

For a module instance named `module.eks` and cluster key `primary`, representative moves are:

```bash
terraform state mv \
  'module.eks.aws_eks_cluster.eks_cp["primary"]' \
  'module.eks.aws_eks_cluster.this["primary"]'

terraform state mv \
  'module.eks.aws_cloudwatch_log_group.eks-log-group["primary"]' \
  'module.eks.aws_cloudwatch_log_group.cluster["primary"]'

terraform state mv \
  'module.eks.aws_iam_role.eks_cp_iamrole["primary"]' \
  'module.eks.aws_iam_role.cluster["primary"]'

terraform state mv \
  'module.eks.aws_eks_node_group.ng["primary||system"]' \
  'module.eks.aws_eks_node_group.this["primary||system"]'

terraform state mv \
  'module.eks.aws_iam_role.eks_ng_iamrole["primary||system"]' \
  'module.eks.aws_iam_role.node["primary||system"]'
```

These are examples, not a script. Inspect `terraform state list` because v1 optional resources and nested launch-template/KMS module addresses vary by configuration. Import an existing launch template, KMS key, add-on, or OIDC provider into its v2 address only when the v2 configuration is intended to own it. Otherwise pass an external ARN or remove the corresponding v2 feature.

## Safe migration sequence

1. Translate inputs without changing the actual cluster name, subnet IDs, service CIDR, IAM role ARNs, KMS key ARN, Kubernetes version, endpoint mode, or add-on versions.
2. Use external role and KMS ARNs initially if v1 already owns those resources through nested modules and an in-place state move is unclear.
3. Disable new optional ownership temporarily where necessary: `irsa.enabled = false`, `encryption_config.enabled = false`, or an explicit `addons` map matching existing ownership.
4. Move/import state addresses one resource class at a time.
5. Run `terraform plan -refresh-only`, then a normal saved plan.
6. Treat any EKS control-plane replacement as a migration error until deliberately approved. Node-group replacement may also disrupt workloads and must respect PodDisruptionBudgets and capacity.
7. Enable modern EKS features such as Access API, Pod Identity, managed add-ons, a customer-managed KMS key, or EKS Capabilities in separate reviewed changes.

## Rollback

Before any apply, rollback is source/config reversion plus reversing the state moves. After an apply, rollback depends on the changed AWS resource and may not be lossless: EKS names, service CIDRs, IP families, KMS ownership, and deleted node groups cannot always be restored in place. Preserve the prior state backup, v1 source pin, translated v2 configuration, and all migration commands until the sandbox and production plans are accepted.
