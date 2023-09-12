#
# Random ID.
#
resource "random_integer" "eks-id" {
  for_each    = var.eks_config
  min = 100000
  max = 999999
  #lifecycle {
  #  create_before_destroy      = local.test
  #  prevent_destroy            = local.test
  #}
}

locals {

  #
  # The cluster ID(name) defined by the user.
  #
  cluster_id = { for k, v in var.eks_config:
    k => coalesce(
      v["control_plane"]["name"],
      k
    )
  }


  #  
  # The cluster ID concatenated with the ID.
  #
  cluster_name = { for k, v in var.eks_config:
    k => format(
      "%s-%s",
      coalesce(
        v["control_plane"]["name"],
        k
      ),
      random_integer.eks-id[k].id
    )
  }
}


#
# Retrieving Subnets IDs from 
#
data "aws_subnets" "eks-cp-subnets" {
  for_each = var.eks_config

  filter {  
    name   = "vpc-id"
    values = coalesce(
      data.aws_vpcs.eks-vpc[each.key].ids,
      toset(
        [
          try(
            each.value["control_plane"]["vpc_config"]["vpc_id"],
            null
          )
        ]
      )
    )
  }

  dynamic "filter" {
    for_each = coalesce(
      try(
        each.value["control_plane"]["vpc_config"]["subnet_filter"],
        null
      ),
      [
        {
          name   = format(
            "tag:ops.team/eks/cluster/%s",
            local.cluster_id[each.key]
          )
          values = toset([true])
        }
      ]
    )
  
    content {
      name   = filter.value["name"]
      values = filter.value["values"]
    }
  }  
}

#
# The default AssumeRole Policy to be attached in the EKS Control Plane.
#
data "aws_iam_policy_document" "default_eks-cp_assume_role_policy" {
  
  statement {
    sid = "DefaultEKSAssumeRole"

    actions = [
      "sts:AssumeRole"
    ]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

#
# Custom AssumeRole Policy to be attached in the EKS Control Plane.
#
data "aws_iam_policy_document" "eks-cp_assume_role_policy" {
  for_each = {  for k, v in var.eks_config:
    k => v if v["control_plane"]["iam_role"]["assume_role_policy_statements"] != null
  } 

  source_policy_documents = (
    each.value["control_plane"]["iam_role"]["override_default_assume_role_policy"] ? 
      toset([])
    :
      toset(
        [
          data.aws_iam_policy_document.default_eks-cp_assume_role_policy.json
        ]
      )      
  )


  dynamic "statement" {
    for_each = each.value["control_plane"]["iam_role"]["assume_role_policy_statements"]

    content {
      actions = statement.value["actions"]
      
      dynamic "condition" {
        for_each = coalesce(statement.value["condition"], [])
        content {
          test     = condition.value["test"]
          variable = condition.value["variable"]
          values   = condition.value["values"]
        }
      }
      
      effect  = statement.value["effect"]
      not_actions = statement.value["not_actions"]
      
      dynamic "not_principals" {
        for_each = coalesce(statement.value["not_principals"], [])
        content {
          type        = not_principals.value["type"]
          identifiers = not_principals.value["identifiers"]  
        }
      }

      dynamic "principals" {
        for_each = coalesce(statement.value["principals"], [])
        content {
          type        = principals.value["type"]
          identifiers = principals.value["identifiers"]  
        }
      }

      sid = statement.value["sid"]
    }
  }

}


#
# The EKS Control Plane's IAM Role.
#
resource "aws_iam_role" "eks_cp_iamrole" {
  for_each = { for k, v in var.eks_config:
    k => v if v["control_plane"]["iam_role"]["create"] == true  
  }
  
  name_prefix = format("%s@", local.cluster_name[each.key])

  path        = each.value["control_plane"]["iam_role"]["path"]
  description = each.value["control_plane"]["iam_role"]["description"]

  assume_role_policy = try(
    data.aws_iam_policy_document.eks-cp_assume_role_policy[each.key].json,
    data.aws_iam_policy_document.default_eks-cp_assume_role_policy.json
  )

  permissions_boundary  = each.value["control_plane"]["iam_role"]["permissions_boundary"]
  force_detach_policies = each.value["control_plane"]["iam_role"]["force_detach_policies"]


  #dynamic "inline_policy" {
  #  for_each = var.create_cloudwatch_log_group ? [1] : []
  #  content {
  #    name = local.iam_role_name
  #
  #    policy = jsonencode({
  #      Version = "2012-10-17"
  #      Statement = [
  #        {
  #          Action   = ["logs:CreateLogGroup"]
  #          Effect   = "Deny"
  #          Resource = "*"
  #        },
  #      ]
  #    })
  #  }
  #}

  tags = merge(
    each.value["control_plane"]["tags"],
    each.value["control_plane"]["iam_role"]["tags"],
  )
}


#
# Attach Policies to EKS CP's IAM Role.
#
resource "aws_iam_role_policy_attachment" "eks_cp_iamrole" {
  for_each = zipmap(
    flatten(
      [ for k, v in var.eks_config:
        [
          for x in v["control_plane"]["iam_role"]["policy_attachments"]:
            format("%s|%s", k, x) if v["control_plane"]["iam_role"]["create"] == true
        ]
      ]
    ),
    flatten(
      [ for k, v in var.eks_config:
        [
          for x in v["control_plane"]["iam_role"]["policy_attachments"]:
            x if v["control_plane"]["iam_role"]["create"] == true
        ]
      ]
    )
  )

  policy_arn = format("arn:aws:iam::aws:policy/%s", each.value)
  role       = aws_iam_role.eks_cp_iamrole[ replace(each.key, "/^(.*)\\|(.*)$/",  "$1") ].name
}

#
# Random shuffle ID to get one CIDR
#
resource "random_shuffle" "kubernetes_network_config_netprefix" {
  for_each     = var.eks_config
  input        = ["10.0.0.0/16", "172.16.0.0/16"]
  result_count = 1
}

#
# Random generated netnum to define the internal k8s network.
#
resource "random_integer" "kubernetes_network_config_netnum" {
  for_each = var.eks_config
  min      = 1
  max      = 32
}

#
# Deploy EKS Control Plane
#
resource "aws_eks_cluster" "eks_cp" {
  for_each                  = var.eks_config

  enabled_cluster_log_types = each.value["control_plane"]["enabled_cluster_log_types"]

  dynamic "encryption_config" {
    for_each = each.value["control_plane"]["encryption_config"] != null ? toset([each.value["control_plane"]["encryption_config"]]) : []
    content {
      dynamic "provider" {
        for_each = toset([encryption_config.value["provider"]])
        content {
          #key_arn =  provider.value["key_arn"]
          key_arn = coalesce(
            try(
              provider.value["key_arn"],
              null
            ),
            module.kms.kms_key[each.key].arn
          )
        }
      }
      resources = encryption_config.value["resources"]
    }
  }

  #
  #
  #
  kubernetes_network_config {

    #
    # The CIDR block to assign Kubernetes pod and service IP addresses from. 
    # If you don't specify a block, Kubernetes assigns addresses from either 
    # the 10.100.0.0/16 or 172.20.0.0/16 CIDR blocks. We recommend that you 
    # specify a block that does not overlap with resources in other networks 
    # that are peered or connected to your VPC. You can only specify a custom 
    # CIDR block when you create a cluster, changing this value will force a 
    # new cluster to be created. 
    #
    # This parameter is configured by one random choice generated from random 
    # resources.
    #
    service_ipv4_cidr = coalesce(
      try(
        each.value["control_plane"]["kubernetes_network_config"]["service_ipv4_cidr"],
        null
      ),
      cidrsubnet(
        element(
          random_shuffle.kubernetes_network_config_netprefix[each.key].result,
          0
        ),
        6, # newbits. 16+6 /22 CIDR
        random_integer.kubernetes_network_config_netnum[each.key].result
      )
    )

    #
    # The IP family used to assign Kubernetes pod and service addresses. Valid 
    # values are ipv4 (default) and ipv6. You can only specify an IP family 
    # when you create a cluster, changing this value will force a new cluster 
    # to be created.
    #
    ip_family               = try(
      each.value["control_plane"]["kubernetes_network_config"]["ip_family"],
      null
    )
  }

  #
  #
  #
  name                      = local.cluster_name[each.key]
  
  #
  # EKS CP Role
  # 
  role_arn                  = coalesce(
    each.value["control_plane"]["iam_role"]["role_arn"],
    aws_iam_role.eks_cp_iamrole[each.key].arn,
  )
  
  #
  # EKS CP network setting.
  #
  vpc_config {
    endpoint_private_access = try(each.value["control_plane"]["vpc_config"]["endpoint_private_access"], null)
    endpoint_public_access  = try(each.value["control_plane"]["vpc_config"]["endpoint_public_access"], null)
    public_access_cidrs     = try(each.value["control_plane"]["vpc_config"]["public_access_cidrs"], null)
    security_group_ids      = try(each.value["control_plane"]["vpc_config"]["security_group_ids"], null)
    
    subnet_ids = coalescelist(
      tolist(
        try(
          each.value["control_plane"]["vpc_config"]["subnet_ids"],
          null
        )
      ),
      data.aws_subnets.eks-cp-subnets[each.key].ids,
    )
  }

  tags =  each.value["control_plane"]["tags"]
  
  depends_on = [
    aws_cloudwatch_log_group.eks-log-group,
    aws_iam_role_policy_attachment.eks_cp_iamrole
  ]
  
  lifecycle {
    ignore_changes = [
      kubernetes_network_config
    ]
  }

  timeouts {
    create = try(each.value["control_plane"]["cluster_timeouts"]["create"], null)
    update = try(each.value["control_plane"]["cluster_timeouts"]["update"], null)
    delete = try(each.value["control_plane"]["cluster_timeouts"]["delete"], null)
  }
}