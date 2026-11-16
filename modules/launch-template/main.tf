############################################################
# Reusable launch template for Spoke application instances.
############################################################

data "aws_ami" "app" {
  count = var.ami_id == null ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Needed by the SSM bootstrap script to build the regional S3 URL used as a
# fallback installer source on distributions that don't package the agent.
data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# SSM Agent bootstrap (see modules/launch-template/README.md "SSM Agent
# bootstrap"). Verifies/installs/enables/starts the SSM Agent before the
# caller-supplied application bootstrap runs. Does not assume the AMI
# already includes the agent, and does not alter the caller's own script.
# ---------------------------------------------------------------------------
locals {
  ssm_bootstrap_script = templatefile("${path.module}/templates/ssm-bootstrap.sh.tftpl", {
    region = data.aws_region.current.name
  })

  # The caller-supplied user_data keeps its own "#!/bin/bash" line, which is
  # harmless mid-script (cloud-init runs the whole thing as one shell
  # script, so a second shebang line is just a comment) - this preserves
  # var.user_data byte-for-byte as a suffix rather than rewriting it.
  rendered_user_data = var.manage_ssm_agent ? join("\n", [
    local.ssm_bootstrap_script,
    "",
    "# ---- Caller-supplied application bootstrap (var.user_data) below ----",
    var.user_data,
  ]) : var.user_data
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.name_prefix}-lt-"
  image_id      = coalesce(var.ami_id, try(data.aws_ami.app[0].id, null))
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = var.instance_profile_name
  }

  # Application instances get NO public IP - Spoke workloads are private-only.
  # Security groups are set on the network_interfaces block (required when
  # associate_public_ip_address is explicitly controlled here) rather than
  # via the top-level vpc_security_group_ids, which cannot be combined with
  # an explicit network_interfaces block.
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.security_group_id]
    delete_on_termination       = true
  }

  user_data = base64encode(local.rendered_user_data)

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1 # no container/overlay hop needed for a plain EC2 instance
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = var.enable_detailed_monitoring
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name_prefix}-app" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(var.tags, { Name = "${var.name_prefix}-app-volume" })
  }

  lifecycle {
    create_before_destroy = true
  }
}
