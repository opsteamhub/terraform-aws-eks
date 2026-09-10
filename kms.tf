data "aws_iam_policy_document" "eks_kms" {
  for_each = local.managed_kms_clusters

  statement {
    sid       = "EnableAccountAdministration"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid    = "AllowEKSClusterRoleUse"
    effect = "Allow"
    actions = [
      "kms:CreateGrant",
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ListGrants",
      "kms:ReEncrypt*",
      "kms:RevokeGrant",
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [local.cluster_role_arns[each.key]]
    }
  }
}

resource "aws_kms_key" "eks" {
  for_each = local.managed_kms_clusters

  description = coalesce(
    each.value.control_plane.encryption_config.description,
    "Envelope encryption for ${each.value.control_plane.name} EKS secrets"
  )
  deletion_window_in_days = each.value.control_plane.encryption_config.deletion_window_in_days
  enable_key_rotation     = each.value.control_plane.encryption_config.enable_key_rotation
  policy                  = data.aws_iam_policy_document.eks_kms[each.key].json
  tags                    = local.cluster_tags[each.key]
}

resource "aws_kms_alias" "eks" {
  for_each = local.managed_kms_clusters

  name = startswith(
    coalesce(each.value.control_plane.encryption_config.alias, "eks-${each.value.control_plane.name}"),
    "alias/"
    ) ? coalesce(
    each.value.control_plane.encryption_config.alias,
    "alias/eks-${each.value.control_plane.name}"
  ) : "alias/${coalesce(each.value.control_plane.encryption_config.alias, "eks-${each.value.control_plane.name}")}"

  target_key_id = aws_kms_key.eks[each.key].key_id
}

locals {
  cluster_kms_key_arns = {
    for key, cluster in local.clusters : key => (
      !cluster.control_plane.encryption_config.enabled ? null : coalesce(
        cluster.control_plane.encryption_config.key_arn,
        try(aws_kms_key.eks[key].arn, null)
      )
    )
  }
}
