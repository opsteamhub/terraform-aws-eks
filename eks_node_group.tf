resource "aws_launch_template" "node" {
  for_each = local.node_groups

  name_prefix = coalesce(
    each.value.launch_template.name_prefix,
    "${local.clusters[each.value.cluster_key].control_plane.name}-${each.value.resolved_name}-"
  )
  image_id               = each.value.launch_template.image_id
  key_name               = each.value.launch_template.key_name
  update_default_version = true
  user_data = each.value.launch_template.user_data == null ? null : base64encode(
    each.value.launch_template.user_data
  )
  vpc_security_group_ids = length(each.value.launch_template.security_group_ids) > 0 ? sort(
    tolist(each.value.launch_template.security_group_ids)
  ) : null

  dynamic "block_device_mappings" {
    for_each = each.value.launch_template.block_device_mappings

    content {
      device_name  = block_device_mappings.value.device_name
      no_device    = block_device_mappings.value.no_device
      virtual_name = block_device_mappings.value.virtual_name

      dynamic "ebs" {
        for_each = block_device_mappings.value.ebs == null ? [] : [block_device_mappings.value.ebs]

        content {
          delete_on_termination = ebs.value.delete_on_termination
          encrypted             = ebs.value.encrypted
          iops                  = ebs.value.iops
          kms_key_id            = ebs.value.kms_key_id
          snapshot_id           = ebs.value.snapshot_id
          throughput            = ebs.value.throughput
          volume_size           = ebs.value.volume_size
          volume_type           = ebs.value.volume_type
        }
      }
    }
  }

  metadata_options {
    http_endpoint               = each.value.launch_template.metadata_options.http_endpoint
    http_protocol_ipv6          = each.value.launch_template.metadata_options.http_protocol_ipv6
    http_put_response_hop_limit = each.value.launch_template.metadata_options.http_put_response_hop_limit
    http_tokens                 = each.value.launch_template.metadata_options.http_tokens
    instance_metadata_tags      = each.value.launch_template.metadata_options.instance_metadata_tags
  }

  monitoring {
    enabled = each.value.launch_template.monitoring.enabled
  }

  dynamic "tag_specifications" {
    for_each = toset(["instance", "network-interface", "volume"])

    content {
      resource_type = tag_specifications.value
      tags = merge(
        local.cluster_tags[each.value.cluster_key],
        each.value.tags,
        { Name = "${local.clusters[each.value.cluster_key].control_plane.name}-${each.value.resolved_name}" }
      )
    }
  }

  tags = merge(
    local.cluster_tags[each.value.cluster_key],
    each.value.tags,
    { Name = "${local.clusters[each.value.cluster_key].control_plane.name}-${each.value.resolved_name}-launch-template" }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eks_node_group" "this" {
  for_each = local.node_groups

  cluster_name         = aws_eks_cluster.this[each.value.cluster_key].name
  node_group_name      = each.value.resolved_name
  node_role_arn        = local.node_role_arns[each.key]
  subnet_ids           = sort(tolist(coalesce(each.value.subnet_ids, local.clusters[each.value.cluster_key].control_plane.vpc_config.subnet_ids)))
  ami_type             = each.value.launch_template.image_id == null ? each.value.ami_type : null
  capacity_type        = upper(each.value.capacity_type)
  force_update_version = each.value.force_update_version
  instance_types       = sort(tolist(each.value.instance_types))
  labels               = each.value.labels
  release_version      = each.value.launch_template.image_id == null ? each.value.release_version : null
  version              = each.value.launch_template.image_id == null ? coalesce(each.value.version, local.clusters[each.value.cluster_key].control_plane.version) : null

  launch_template {
    id      = aws_launch_template.node[each.key].id
    version = tostring(aws_launch_template.node[each.key].latest_version)
  }

  scaling_config {
    desired_size = each.value.scaling_config.desired_size
    max_size     = each.value.scaling_config.max_size
    min_size     = each.value.scaling_config.min_size
  }

  update_config {
    max_unavailable            = each.value.update_config.max_unavailable
    max_unavailable_percentage = each.value.update_config.max_unavailable_percentage
  }

  node_repair_config {
    enabled = each.value.node_repair_config.enabled
  }

  dynamic "taint" {
    for_each = each.value.taints

    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = merge(
    local.cluster_tags[each.value.cluster_key],
    each.value.tags,
    { Name = "${aws_eks_cluster.this[each.value.cluster_key].name}-${each.value.resolved_name}" }
  )

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [aws_iam_role_policy_attachment.node]
}
