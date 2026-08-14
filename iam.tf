data "aws_iam_policy_document" "cluster_assume_role" {
  for_each = {
    for key, cluster in local.clusters : key => cluster
    if cluster.control_plane.role_arn == null
  }

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  for_each = data.aws_iam_policy_document.cluster_assume_role

  name                 = coalesce(local.clusters[each.key].control_plane.role_name, "${local.clusters[each.key].control_plane.name}-cluster-role")
  assume_role_policy   = each.value.json
  permissions_boundary = local.clusters[each.key].control_plane.role_permissions_boundary
  tags                 = local.cluster_tags[each.key]
}

locals {
  cluster_role_arns = {
    for key, cluster in local.clusters : key => coalesce(
      cluster.control_plane.role_arn,
      try(aws_iam_role.cluster[key].arn, null)
    )
  }

  cluster_role_policy_attachments = merge({}, [
    for cluster_key, cluster in local.clusters : cluster.control_plane.role_arn == null ? merge(
      {
        "${cluster_key}||AmazonEKSClusterPolicy" = {
          cluster_key = cluster_key
          policy_arn  = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
        }
      },
      {
        for name, policy_arn in cluster.control_plane.role_additional_policy_arns :
        "${cluster_key}||${name}" => {
          cluster_key = cluster_key
          policy_arn  = policy_arn
        }
      }
    ) : {}
  ]...)
}

resource "aws_iam_role_policy_attachment" "cluster" {
  for_each = local.cluster_role_policy_attachments

  role       = aws_iam_role.cluster[each.value.cluster_key].name
  policy_arn = each.value.policy_arn
}

data "aws_iam_policy_document" "node_assume_role" {
  for_each = {
    for key, node_group in local.node_groups : key => node_group
    if node_group.node_role_arn == null
  }

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  for_each = data.aws_iam_policy_document.node_assume_role

  name = coalesce(
    local.node_groups[each.key].node_role_name,
    "${local.clusters[local.node_groups[each.key].cluster_key].control_plane.name}-${local.node_groups[each.key].resolved_name}-node-role"
  )
  assume_role_policy   = each.value.json
  permissions_boundary = local.node_groups[each.key].node_role_permissions_boundary
  tags = merge(
    local.cluster_tags[local.node_groups[each.key].cluster_key],
    local.node_groups[each.key].tags,
    { Name = "${local.clusters[local.node_groups[each.key].cluster_key].control_plane.name}-${local.node_groups[each.key].resolved_name}-node-role" }
  )
}

locals {
  node_role_arns = {
    for key, node_group in local.node_groups : key => coalesce(
      node_group.node_role_arn,
      try(aws_iam_role.node[key].arn, null)
    )
  }

  default_node_policy_arns = {
    AmazonEKSWorkerNodePolicy          = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    AmazonEKS_CNI_Policy               = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
    AmazonEC2ContainerRegistryPullOnly = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
  }

  node_role_policy_attachments = merge({}, [
    for node_group_key, node_group in local.node_groups : node_group.node_role_arn == null ? merge(
      {
        for name, policy_arn in local.default_node_policy_arns :
        "${node_group_key}||${name}" => {
          node_group_key = node_group_key
          policy_arn     = policy_arn
        }
      },
      {
        for name, policy_arn in node_group.node_role_additional_policy_arns :
        "${node_group_key}||${name}" => {
          node_group_key = node_group_key
          policy_arn     = policy_arn
        }
      }
    ) : {}
  ]...)
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = local.node_role_policy_attachments

  role       = aws_iam_role.node[each.value.node_group_key].name
  policy_arn = each.value.policy_arn
}
