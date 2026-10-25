# The API host: one EC2 instance running deploy/host (Caddy, API, Redis) with
# Docker Compose. cloud-init installs Docker and writes the host files; the
# first deploy is `deploy.sh <tag>` over SSM Session Manager (see README).

data "aws_ec2_instance_type" "api" {
  instance_type = var.instance_type
}

locals {
  arch = contains(data.aws_ec2_instance_type.api.supported_architectures, "arm64") ? "arm64" : "x86_64"
  host = "${path.module}/../host"

  host_files = merge(
    { for f in ["docker-compose.yml", "Caddyfile"] : "/opt/greenroot/${f}" => { content = file("${local.host}/${f}"), mode = "0644" } },
    { for f in fileset("${local.host}/bin", "*.sh") : "/opt/greenroot/bin/${f}" => { content = file("${local.host}/bin/${f}"), mode = "0755" } },
    { for f in fileset("${local.host}/systemd", "*") : "/etc/systemd/system/${f}" => { content = file("${local.host}/systemd/${f}"), mode = "0644" } },
    {
      "/etc/greenroot/host.env" = {
        mode = "0644"
        content = join("\n", [
          "ENVIRONMENT=${var.environment}",
          "AWS_REGION=${var.region}",
          "SECRET_ID=${aws_secretsmanager_secret.api.arn}",
          "DB_MASTER_SECRET_ARN=${aws_db_instance.main.master_user_secret[0].secret_arn}",
          "ECR_REPO=${aws_ecr_repository.api.repository_url}",
          "API_HOST=${local.api_host}",
          "ACME_EMAIL=${var.alarm_email}",
          "LOG_GROUP=${aws_cloudwatch_log_group.api.name}",
          "BACKUP_BUCKET=${aws_s3_bucket.backups.bucket}",
          "",
        ])
      }
    },
  )
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-${local.arch}"
}

resource "aws_eip" "api" {
  domain = "vpc"
}

resource "aws_eip_association" "api" {
  instance_id   = aws_instance.api.id
  allocation_id = aws_eip.api.id
}

resource "aws_instance" "api" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.api.id]
  iam_instance_profile   = aws_iam_instance_profile.api_host.name

  # IMDSv2 only; hop limit 2 so containers (one bridge hop) reach the role.
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    http_endpoint               = "enabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    encrypted             = true
    delete_on_termination = true
  }

  credit_specification {
    cpu_credits = "unlimited" # no throttling at peaks; billed only above baseline
  }

  # gzip keeps the cloud-config well under EC2's 16 KB user-data limit.
  user_data_replace_on_change = false
  user_data_base64 = base64gzip(templatefile("${path.module}/cloud-init.yaml.tftpl", {
    files = local.host_files
  }))

  lifecycle {
    ignore_changes = [ami, user_data_base64] # AMI updates and host-file changes are rolled out deliberately
  }

  tags = {
    Name = "${local.name}-api"
  }
}

# Recover automatically onto new hardware if AWS's host fails.
resource "aws_cloudwatch_metric_alarm" "api_host_recover" {
  alarm_name          = "${local.name}-api-host-auto-recover"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_System"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions          = { InstanceId = aws_instance.api.id }
  alarm_actions       = ["arn:aws:automate:${var.region}:ec2:recover", aws_sns_topic.alarms.arn]
}

# Daily EBS snapshots of the host (Redis AOF, Caddy certificates), 7 kept.
resource "aws_dlm_lifecycle_policy" "host" {
  description        = "${local.name} host volume snapshots"
  execution_role_arn = aws_iam_role.dlm.arn
  state              = "ENABLED"
  policy_details {
    resource_types = ["VOLUME"]
    target_tags    = { Project = "greenroot", Environment = var.environment }
    schedule {
      name = "daily"
      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["21:00"]
      }
      retain_rule {
        count = 7
      }
      copy_tags = true
    }
  }
}

data "aws_iam_policy_document" "dlm_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["dlm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "dlm" {
  name               = "${local.name}-dlm"
  assume_role_policy = data.aws_iam_policy_document.dlm_assume.json
}

resource "aws_iam_role_policy_attachment" "dlm" {
  role       = aws_iam_role.dlm.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}
