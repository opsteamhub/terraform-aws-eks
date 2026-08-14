variable "aws_region" {
  description = "AWS Region where the cluster is created."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Stable EKS cluster name."
  type        = string
  default     = "production-eks"
}

variable "platform_admin_role_arn" {
  description = "IAM role granted cluster administrator access through the EKS Access API."
  type        = string
}

variable "private_subnet_ids" {
  description = "At least two private subnet IDs in distinct Availability Zones."
  type        = set(string)
}
