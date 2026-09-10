variable "ack_capability_role_arn" {
  description = "Same-account IAM role trusted by capabilities.eks.amazonaws.com and scoped to the AWS resources ACK may manage."
  type        = string
}

variable "aws_region" {
  description = "AWS Region where the cluster is created."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Stable EKS cluster name."
  type        = string
  default     = "capabilities-example-eks"
}

variable "environment" {
  description = "Environment tag."
  type        = string
  default     = "development"
}

variable "idc_admin_group_id" {
  description = "AWS Identity Center group ID mapped to the Argo CD ADMIN role."
  type        = string
}

variable "idc_instance_arn" {
  description = "AWS Identity Center instance ARN used by the Argo CD capability."
  type        = string
}

variable "idc_region" {
  description = "AWS Region containing the Identity Center instance."
  type        = string
  default     = "us-east-1"
}

variable "owner" {
  description = "Owner tag."
  type        = string
  default     = "platform"
}

variable "private_subnet_ids" {
  description = "At least two private subnet IDs in distinct Availability Zones."
  type        = set(string)
}

variable "project" {
  description = "Project tag."
  type        = string
  default     = "eks-capabilities-example"
}
