# GreenRoot on AWS, sized for launch at minimal cost (~USD 30-35/month):
#
#   Internet ──► Caddy (TLS, :443) ─► API container ─► RDS PostgreSQL 17 + PostGIS
#                 └── on one EC2 t4g.small ──┘   └─► Redis container (AOF on EBS)
#   files.<domain> ─► CloudFront ─► S3 (public image buckets, via OAC; buckets stay private)
#   admin.<domain> ─► CloudFront ─► S3 (admin dashboard build)
#
# - Default VPC, public subnet for the host: no NAT gateway (USD 32+/month saved).
#   The host has only 80/443 open; admin access is SSM Session Manager (no SSH).
# - RDS is private (reachable only from the host's security group), TLS forced,
#   encrypted, 14 days of point-in-time recovery, deletion protection.
# - Every secret is in one Secrets Manager secret; the API reads it at start.
# - Container logs go to CloudWatch; alarms email var.alarm_email.

locals {
  name   = "greenroot-${var.environment}"
  prefix = "${local.name}-" # S3 bucket prefix (STORAGE_BUCKET_PREFIX)

  api_host   = "api.${var.domain}"
  admin_host = "admin.${var.domain}"
  files_host = "files.${var.domain}"

  # Platform buckets (platform/storage). Public ones are served by CloudFront.
  public_buckets  = ["profile-images", "plant-images", "market-ads", "nursery-logos"]
  private_buckets = ["loading-photos", "delivery-photos", "attachments", "quotation-pdfs", "order-pdfs"]
  all_buckets     = concat(local.public_buckets, local.private_buckets)
}

data "aws_caller_identity" "current" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# ── Security groups ─────────────────────────────────────────────────────────

resource "aws_security_group" "api" {
  name        = "${local.name}-api"
  description = "GreenRoot API host: HTTPS from anywhere (Caddy), nothing else"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP (redirects to HTTPS; ACME challenges)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Outbound (AWS APIs, Razorpay, FCM, ECR)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  name        = "${local.name}-db"
  description = "GreenRoot PostgreSQL: only from the API host"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "PostgreSQL from the API host"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.api.id]
  }
}
