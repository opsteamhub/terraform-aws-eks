#
# Retrieving Subnets IDs default for NGs
#
data "aws_subnets" "eks-ng-default-subnets" {

  for_each = zipmap(
    flatten(
      [
        for k,v in var.eks_config:
          [
            for x, y in coalesce(
                v["node_groups"],
                {}
              ):
              format("%s||%s", k, x)
          ] 
      ]
    ),
    flatten(
      [
        for k,v in var.eks_config:
          [
            for x, y in coalesce(
              v["node_groups"],
              {}
            ):
              merge(
                y,
                tomap(
                  {
                    "cluster_tf_id": k
                    "node_group_name": x
                    "vpc_id": try(
                      v["control_plane"]["vpc_config"]["vpc_id"],
                      null
                    )
                  }
                )
              )
          ] 
      ]
    )
  )

  filter {
    name   = "vpc-id"
    values = coalesce(
      data.aws_vpcs.eks-vpc[each.value["cluster_tf_id"]].ids,
      toset(
        [
          each.value["vpc_id"]
        ]
      )
    )
  }

  dynamic "filter" {
    for_each = coalesce(
      each.value["subnet_filter"],
      [
        {
          name = format(
            "tag:ops.team/eks/cluster/%s/node_group/default",
            local.cluster_id[each.value["cluster_tf_id"]]
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
# Retrieving Subnets IDs specific for each NG
#
data "aws_subnets" "eks-ng-subnets" {
  
  for_each = zipmap(
    flatten(
      [
        for k,v in var.eks_config:
          [
            for x, y in coalesce(
                v["node_groups"],
                {}
            ):
              format("%s||%s", k, x)
          ] 
      ]
    ),
    flatten(
      [
        for k,v in var.eks_config:
          [
            for x, y in coalesce(
              v["node_groups"],
              {}
            ):
              merge(
                y,
                tomap(
                  {
                    "cluster_tf_id": k
                    "node_group_name": x
                    "vpc_id": try(
                      v["control_plane"]["vpc_config"]["vpc_id"],
                      null
                    )
                  }
                )
              )
          ] 
      ]
    )
  )

  filter {
    name   = "vpc-id"
    values = coalesce(
      data.aws_vpcs.eks-vpc[each.value["cluster_tf_id"]].ids,
      toset(
        [
          each.value["vpc_id"]
        ]
      )
    )
  }

  dynamic "filter" {
    for_each = coalesce(
      each.value["subnet_filter"],
      [
        {
          name = format(
            "tag:ops.team/eks/cluster/%s/node_group/%s",
            local.cluster_id[each.value["cluster_tf_id"]],
            each.value["node_group_name"]
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
# Generate the Default IAM Policy document to AssumeRole for NodeGroup IAM Role's. 
#
data "aws_iam_policy_document" "default_eks-ng_assume_role_policy" {

  for_each    = var.eks_config

  statement {
    sid = "DefaultEKSAssumeRole"

    actions = [
      "sts:AssumeRole"
    ]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    principals {
      type        = "AWS"
      identifiers = toset(
        [
          aws_iam_role.eks_cp_iamrole[each.key].arn
        ]
      )
    }

  }
}



#
# Generate IAM Policy document to AssumeRole for NodeGroup IAM Role's. 
#
data "aws_iam_policy_document" "eks-ng_assume_role_policy" {

  for_each = zipmap(
    flatten(
      [
        for k,v in var.eks_config:
          [
            for x,y in coalesce(
              v["node_groups"],
              {}
            ):
              format("%s-%s", k, x) if y["iam_role"]["assume_role_policy_statements"] != null    
          ]
      ]
    ),
    flatten(
      [
        for k,v in var.eks_config:
          [
            for x in coalesce(
              v["node_groups"],
              {}
            ):
              merge(
                x,
                tomap(
                  {
                    "cluster_tf_id" = k
                  }
                )
              ) if x["iam_role"]["assume_role_policy_statements"] != null
          ]
      ]
    )
  )

  source_policy_documents = (
    each.value["iam_role"]["override_default_assume_role_policy"] ? 
      toset([])
    :
      toset(
        [
          data.aws_iam_policy_document.default_eks-ng_assume_role_policy[each.value["cluster_tf_id"]].json
        ]
      )      
  )

  dynamic "statement" {
    for_each = each.value["iam_role"]["assume_role_policy_statements"]

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


data "aws_iam_policy_document" "eks-ng_role_inline_policy" {

  for_each = zipmap(
    flatten(
      [
        for k,v in var.eks_config:
          [
            for x,y in coalesce(
              v["node_groups"],
              {}
            ):
              format("%s-%s", k, x) if y["iam_role"]["inline_policy"] != null    
          ]
      ]
    ),
    flatten(
      [
        for k,v in var.eks_config:
          [
            for x in coalesce(
              v["node_groups"],
              {}
            ):
              x if x["iam_role"]["inline_policy"] != null
          ]
      ]
    )
  )

  dynamic "statement" {
    for_each = each.value["iam_role"]["assume_role_policy_statements"]

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
# Create NodeGroup's Role
#
resource "aws_iam_role" "eks_ng_iamrole" {
  for_each = zipmap(
    flatten(
      [
        for k,v in var.eks_config:
          [
            for x,y in coalesce(
              v["node_groups"],
              {}
            ):
              format("%s||%s", k, x) if y["iam_role"]["create"]
          ]
      ]
    ),
    flatten(
      [
        for k,v in var.eks_config:
          [
            for x,y in coalesce(
              v["node_groups"],
              {}
            ):
              merge(
                y,
                tomap(
                  {
                    "cluster_tf_id"   = k,
                    "node_group_name" = x, 
                  }
                )
              ) if y["iam_role"]["create"]
          ]
      ]
    )
  )
  
  name_prefix = format("%s@", each.value["node_group_name"])

  path        = each.value["iam_role"]["path"]
  description = each.value["iam_role"]["description"]

  assume_role_policy = try(
    data.aws_iam_policy_document.eks-ng_assume_role_policy[each.key].json,
    data.aws_iam_policy_document.default_eks-ng_assume_role_policy[each.value["cluster_tf_id"]].json
  )

  permissions_boundary  = each.value["iam_role"]["permissions_boundary"]
  force_detach_policies = each.value["iam_role"]["force_detach_policies"]


  dynamic "inline_policy" {
    for_each = can(data.aws_iam_policy_document.eks-ng_role_inline_policy[each.key].json) ? [1] : toset([])
    content {
      name = "teste"
  
      policy = data.aws_iam_policy_document.eks-ng_role_inline_policy[each.key].json
    }
  }

  tags = merge(
    each.value["tags"],
    each.value["iam_role"]["tags"],
  )
}

#
#
#
locals {
  default_ng_iam_role_policy_attachments = toset(
    [
      "AmazonEKSWorkerNodePolicy",
      "AmazonEC2ContainerRegistryReadOnly",
      "AmazonEKS_CNI_Policy"
    ]
  )
}

#
# Attach IAM Policy to NodeGroups's Role.
#
resource "aws_iam_role_policy_attachment" "eks_ng_iamrole" {
  for_each = zipmap(
    flatten(
      [ for k, v in var.eks_config:
        [
          for x, y in coalesce(
            v["node_groups"],
            {}
          ):
            [
              for w in (y["iam_role"]["override_policy_attachments"] == true ? y["iam_role"]["policy_attachments"] : setunion(y["iam_role"]["policy_attachments"], local.default_ng_iam_role_policy_attachments)):
                format("%s||%s||%s", k, x, w) if y["iam_role"]["create"] == true
            ]
        ]
      ]
    ),
    flatten(
      [ for k, v in var.eks_config:
        [
          for y in coalesce(
            v["node_groups"],
            {}
          ):
            [
              for w in (y["iam_role"]["override_policy_attachments"] == true ? y["iam_role"]["policy_attachments"] : setunion(y["iam_role"]["policy_attachments"], local.default_ng_iam_role_policy_attachments)):
                w if y["iam_role"]["create"] == true
            ]
        ]
      ]
    )
  )

  policy_arn = format("arn:aws:iam::aws:policy/%s", each.value)
  role       = aws_iam_role.eks_ng_iamrole[ replace(each.key, "/^(.*)\\|\\|(.*)$/",  "$1") ].name
}

#
#
#
###data "aws_launch_template" "eks_ng_launchtemplate" {
###  
###  for_each = zipmap(
###    flatten(
###      [
###        for k, v in var.eks_config:
###          [
###            for x,y in coalesce(
###              v["node_groups"],
###              {}
###            ): 
###              [
###                for z in toset(
###                  [
###                    y["launch_template"]
###                  ]
###                ):
###                  format("%s||%s", k, x) if try(z["config"], {a="a"}) == null
###              ] 
###          ]
###      ]
###    ),
###    flatten(
###      [
###        for k, v in var.eks_config:
###          [
###            for x,y in coalesce(
###              v["node_groups"],
###              {}
###            ): 
###              [
###                for z in toset(
###                  [
###                    y["launch_template"]
###                  ]
###                ):
###                  z if try(z["config"], {a="a"}) == null
###              ]  
###          ]
###      ]
###    )
###  )
###
###  id   = each.value["id"]
###  name = each.value["name"]
###
###}


#
# Deploy dedicated self contained NG's SG.
#
##module "ng_sg" {
##
##  for_each = zipmap(
##    flatten(
##      [
##        for k, v in var.eks_config:
##          [
##            for x,y in coalesce(
##              v["node_groups"],
##              {}
##            ): 
##              format("%s||%s", k, x)
##          ]
##      ]
##    ),
##    flatten(
##      [
##        for k, v in var.eks_config:
##          [
##            for x,y in coalesce(
##              v["node_groups"],
##              {}
##            ): 
##              merge(
##                y,
##                tomap(
##                  {
##                    "cluster_tf_id" = k
##                    "node_group_name_prefix" = x, 
##                  }
##                )
##              )
##          ]
##      ]
##    )
##  )
##
##  source = "git@github.com:opsteamhub/terraform-aws-vpc.git"
##
##  vpc_config = {
##    vpc = {
##      create = false
##      id     = each.value["cluster_tf_id"] 
##    }
##    security_groups = toset(
##      [
##        merge(
##          {
##            name = each.value["node_group_name_prefix"]
##            tags = {
##              "opsteam:eks_cluster" = ""
##              "opsteam:eks_cluster_ng" = "" 
##            }
##          },
##          each.value["security_groups"],
##        )
##      ]
##    )
##  }
##}

#
# Deploy NG LaunchTemplate
#
module "lt" {

for_each = zipmap(
    flatten(
      [
        for k, v in var.eks_config:
          [
            for x,y in coalesce(
              v["node_groups"],
              {}
            ): 
              format("%s||%s", k, x)
          ]
      ]
    ),
    flatten(
      [
        for k, v in var.eks_config:
          [
            for x,y in coalesce(
              v["node_groups"],
              {}
            ): 
              merge(
                y,
                tomap(
                  {
                    "cluster_tf_id" = k
                    "node_group_name" = x, 
                  }
                )
              )
          ]
      ]
    )
  )

  source = "git@github.com:opsteamhub/terraform-aws-ec2-launch-template.git" 
  launch_template_config = {
    format("%s", each.value["node_group_name"]) = merge(
      each.value["launch_template"],
      {
        user_data = base64encode(
          data.null_data_source.default_ng_userdata[each.key].outputs["userdata"]
        )
      },
      each.value["enable_instance_tags"] ? {
        tag_specifications = [
          {
            resource_type = "instance"
            tags = merge(
              var.eks_config[each.value["cluster_tf_id"]]["control_plane"]["tags"],
              each.value["tags"],
              {
                "Name" = format("%s-%s", aws_eks_cluster.eks_cp[each.value["cluster_tf_id"]]["name"], each.value["node_group_name"])
              }
            )
          },
          {
            resource_type = "volume"
            tags = {
              "Name" = format("%s-%s", aws_eks_cluster.eks_cp[each.value["cluster_tf_id"]]["name"], each.value["node_group_name"])
            }
          }
        ]
      } : {}
    )
  }
}




#
# Default NodeGroup UserData
#
data "null_data_source" "default_ng_userdata" {
  
  for_each = zipmap(
    flatten(
      [
        for k, v in var.eks_config:
          [
            for x,y in coalesce(
              v["node_groups"],
              {}
            ): 
              format("%s||%s", k, x)
          ]
      ]
    ),
    flatten(
      [
        for k, v in var.eks_config:
          [
            for x,y in coalesce(
              v["node_groups"],
              {}
            ): 
              merge(
                y,
                tomap(
                  {
                    "cluster_tf_id" = k
                    "node_group_name" = x, 
                  }
                )
              )
          ]
      ]
    )
  )

  inputs = {
    userdata = strcontains(each.value["ami_type"], "AL2023") ? templatefile(
      "${path.module}/ng_userdata_al2023.tmpl",
      {
        B64_CLUSTER_CA          = aws_eks_cluster.eks_cp[each.value["cluster_tf_id"]].certificate_authority[0]["data"]
        CLUSTER_NAME            = aws_eks_cluster.eks_cp[each.value["cluster_tf_id"]]["name"]
        API_SERVER_URL          = aws_eks_cluster.eks_cp[each.value["cluster_tf_id"]].endpoint
        K8S_CLUSTER_DNS_IP      = cidrhost(aws_eks_cluster.eks_cp[each.value["cluster_tf_id"]].kubernetes_network_config[0]["service_ipv4_cidr"], 10)
        SERVICE_CIDR            = aws_eks_cluster.eks_cp[each.value["cluster_tf_id"]].kubernetes_network_config[0]["service_ipv4_cidr"]
        NODEGROUP               = each.value["node_group_name"]
      }
    ) : templatefile(
      "${path.module}/ng_userdata.tmpl",
      {
        B64_CLUSTER_CA          = aws_eks_cluster.eks_cp[each.value["cluster_tf_id"]].certificate_authority[0]["data"]
        CLUSTER_NAME            = aws_eks_cluster.eks_cp[each.value["cluster_tf_id"]]["name"]
        API_SERVER_URL          = aws_eks_cluster.eks_cp[each.value["cluster_tf_id"]].endpoint
        K8S_CLUSTER_DNS_IP      = cidrhost(aws_eks_cluster.eks_cp[each.value["cluster_tf_id"]].kubernetes_network_config[0]["service_ipv4_cidr"], 10)
        NODEGROUP               = each.value["node_group_name"]
        CNI_VERSION             = "1.7.5"
        CNI_ADDON               = contains(
          flatten(
            [
              for k, v in var.eks_config:
                [
                  v["control_plane"]["addons"]
                ]
            ]
          )[*]["addon_name"],
          "vpc-cni"
        ) ? true : false
      }
    )
  }
}



output "teste" {
  #value = var.eks_config["opsteam-tst-eks-0001"]["node_groups"]["x"]["launch_template"]
  value = contains(
    flatten(
      [
        for k, v in var.eks_config:
          [
            v["control_plane"]["addons"]
          ]
      ]
    )[*]["addon_name"],
    "vpc-cni"
  )
}


#
# Deploy NodeGroup.
#
resource "aws_eks_node_group" "ng" {

  for_each = zipmap(
    flatten(
      [
        for k, v in var.eks_config:
          [
            for x,y in coalesce(
              v["node_groups"],
              {}
            ): 
              format("%s||%s", k, x)
          ]
      ]
    ),
    flatten(
      [
        for k, v in var.eks_config:
          [
            for x,y in coalesce(
              v["node_groups"],
              {}
            ): 
              merge(
                y,
                tomap(
                  {
                    "cluster_tf_id" = k
                    "node_group_name" = x, 
                  }
                )
              )
          ]
      ]
    )
  )

  #
  # As long as you set AMI Id in the Launch Template, you can't set up the AMI Type.
  #
  ami_type        = try(
    module.lt[each.key].lt_configs[each.value["node_group_name"]].image_id,
    null
  ) == null ? each.value["ami_type"] : "CUSTOM"

  capacity_type   = upper(each.value["capacity_type"])
  cluster_name    = aws_eks_cluster.eks_cp[each.value["cluster_tf_id"]]["name"]
  
  disk_size       = try(
    module.lt[each.key].lt_configs[each.value["node_group_name"]].id,
    null
  ) == null ? each.value["disk_size"] : null
  
  force_update_version   = each.value["force_update_version"]
  instance_types         = each.value["instance_types"]
  labels                 = each.value["labels"] 

  launch_template {
    id      = module.lt[each.key].lt_configs[each.value["node_group_name"]].id
    version = module.lt[each.key].lt_configs[each.value["node_group_name"]].default_version
  }

  node_group_name = each.value["node_group_name"]
  
  #
  # The NG IAM Role to be attached
  #
  node_role_arn   = coalesce(
    each.value["node_role_arn"],
    aws_iam_role.eks_ng_iamrole[each.key].arn,
  )

  release_version = each.value["release_version"]
  
  dynamic "remote_access" { 
    for_each = each.value["remote_access"] != null ? toset([each.value["remote_access"]]) : toset([])
    
    content {
      ec2_ssh_key               = remote_access.value["ec2_ssh_key"]
      source_security_group_ids = remote_access.value["source_security_group_ids"]
    }
  }

  subnet_ids = coalesce(
    each.value["subnet_ids"],
    (
      length(
        data.aws_subnets.eks-ng-subnets[each.key].ids
      ) > 0 ?
        data.aws_subnets.eks-ng-subnets[each.key].ids
      :
        data.aws_subnets.eks-ng-default-subnets[each.key].ids
    )
  )

  scaling_config {
    desired_size = each.value["scaling_config"]["desired_size"]
    max_size     = each.value["scaling_config"]["max_size"]
    min_size     = each.value["scaling_config"]["min_size"]
  }

  tags = merge(
    var.eks_config[each.value["cluster_tf_id"]]["control_plane"]["tags"],
    each.value["tags"],
    {
      "Name" = format("%s-%s", aws_eks_cluster.eks_cp[each.value["cluster_tf_id"]]["name"], each.value["node_group_name"])
    }
  )

  dynamic "taint" {
    for_each = coalesce(
      each.value["taint"],
      []
    )
    content {
      key    = taint.value["key"]
      value  = taint.value["value"]
      effect = taint.value["effect"]
    }
  }

  #
  # As long as you set AMI Id in the Launch Template, you can't set up the EKS NG Version.
  #
  version = (
    try(
      module.lt[each.key].lt_configs[format("%s", each.value["node_group_name"])].image_id, null
    ) == null
  ) ? each.value["version"] : null

  #
  # 
  #
  lifecycle {
    ignore_changes = [
      ami_type,
      disk_size,
      scaling_config["desired_size"],
    ]
    #create_before_destroy = true
  }

  depends_on = [ module.lt ]
}