resource "aws_eks_capability" "this" {
  for_each = local.capabilities

  capability_name           = each.value.resolved_name
  cluster_name              = aws_eks_cluster.this[each.value.cluster_key].name
  delete_propagation_policy = upper(each.value.delete_propagation_policy)
  role_arn                  = local.capability_role_arns[each.key]
  type                      = each.value.resolved_type

  dynamic "configuration" {
    for_each = each.value.resolved_type == "ARGOCD" ? [each.value.argo_cd] : []

    content {
      argo_cd {
        namespace = configuration.value.namespace

        aws_idc {
          idc_instance_arn = configuration.value.aws_idc.idc_instance_arn
          idc_region       = configuration.value.aws_idc.idc_region
        }

        dynamic "network_access" {
          for_each = configuration.value.network_access == null ? [] : [configuration.value.network_access]

          content {
            vpce_ids = network_access.value.vpce_ids
          }
        }

        dynamic "rbac_role_mapping" {
          for_each = configuration.value.rbac_role_mappings

          content {
            role = upper(rbac_role_mapping.value.role)

            dynamic "identity" {
              for_each = rbac_role_mapping.value.identities

              content {
                id   = identity.value.id
                type = upper(identity.value.type)
              }
            }
          }
        }
      }
    }
  }

  tags = merge(
    local.cluster_tags[each.value.cluster_key],
    each.value.tags,
    { Name = "${aws_eks_cluster.this[each.value.cluster_key].name}-${each.value.resolved_name}" }
  )

  depends_on = [
    aws_iam_role_policy.capability,
    aws_iam_role_policy_attachment.capability,
  ]
}
