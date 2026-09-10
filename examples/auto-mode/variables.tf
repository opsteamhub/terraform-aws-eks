variable "aws_region" {
  description = "AWS Region where the cluster is created."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Stable EKS cluster name."
  type        = string
  default     = "auto-mode-example-eks"
}

variable "environment" {
  description = "Environment tag."
  type        = string
  default     = "development"
}

variable "owner" {
  description = "Owner tag."
  type        = string
  default     = "platform"
}

variable "project" {
  description = "Project tag."
  type        = string
  default     = "eks-auto-mode-example"
}

variable "private_subnet_ids" {
  description = "At least two private subnet IDs in distinct Availability Zones."
  type        = set(string)
}
