output "eks_clusters_name" {
  value = { for k,v in aws_eks_cluster.eks_cp:
    k => v.name
  }
}