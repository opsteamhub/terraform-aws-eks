locals {

  default_addons = [
    {
      addon_name           = "coredns"
      addon_version        = "v1.10.1-eksbuild.1"
      configuration_values = "{\"replicaCount\":4,\"resources\":{\"limits\":{\"cpu\":\"100m\",\"memory\":\"150Mi\"},\"requests\":{\"cpu\":\"30m\",\"memory\":\"30Mi\"}}}"
      resolve_conflicts    = "OVERWRITE"
    }
  ]

}

#
# Deploy EKS Addons
#
resource "aws_eks_addon" "eks-addon" {
  for_each = zipmap(
    flatten(
      [ for k,v in var.eks_config:
        [
          for x in (
            v["control_plane"]["override_default_addons"] ?
              v["control_plane"]["addons"]
            :
              concat(
                coalesce(
                  v["control_plane"]["addons"], 
                  []
                ),
                local.default_addons
              )
          ):
            format("%s-%s", k, x["addon_name"])
        ]
      ]
    ),
    flatten(
      [ for k,v in var.eks_config:
        [
          for x in (
            v["control_plane"]["override_default_addons"] ?
              v["control_plane"]["addons"]
            :
              concat(
                coalesce(
                  v["control_plane"]["addons"],
                  []
                ),
                local.default_addons
              )
          ):
            merge(
              x,
              tomap(
                {
                  "cluster_tf_id" = k
                }
              )
            )
        ]
      ]
    )
  )

  cluster_name         = aws_eks_cluster.eks_cp[each.value["cluster_tf_id"]]["name"]
  addon_name           = each.value["addon_name"]
  addon_version        = each.value["addon_version"]
  #resolve_conflicts    = each.value["resolve_conflicts"]
  resolve_conflicts_on_create = "OVERWRITE"
  #resolve_conflicts_on_update
  configuration_values = each.value["configuration_values"]
}