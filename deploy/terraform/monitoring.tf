# Logs and alarms. Every alarm emails var.alarm_email (confirm the SNS mail).

resource "aws_sns_topic" "alarms" {
  name = "${local.name}-alarms"
}

resource "aws_sns_topic_subscription" "alarms_email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/greenroot/${var.environment}/api" # API, Caddy, Redis containers
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "host" {
  name              = "/greenroot/${var.environment}/host"
  retention_in_days = var.log_retention_days
}

# ── Log-based metrics (the API logs JSON via slog) ──────────────────────────

locals {
  log_metrics = {
    # Razorpay money that needs a human (payment_issues; PAYMENT_ISSUE marker).
    PaymentIssues = "\"PAYMENT_ISSUE\""
    # A refund done at Razorpay that the API failed to record.
    RefundNotRecorded = "\"refund done at Razorpay but not recorded\""
    ApiErrors         = "{ $.level = \"ERROR\" }"
    ApiPanics         = "\"panic\""
    WebhookRetries    = "\"razorpay webhook: will retry\""
  }
}

resource "aws_cloudwatch_log_metric_filter" "api" {
  for_each       = local.log_metrics
  name           = "${local.name}-${each.key}"
  log_group_name = aws_cloudwatch_log_group.api.name
  pattern        = each.value
  metric_transformation {
    name          = each.key
    namespace     = "GreenRoot"
    value         = "1"
    default_value = "0"
    dimensions    = {}
  }
}

locals {
  log_alarms = {
    PaymentIssues     = { threshold = 1, periods = 1, period = 300, desc = "Razorpay money needs a manual action: open Admin → Payment issues" }
    RefundNotRecorded = { threshold = 1, periods = 1, period = 300, desc = "A Razorpay refund succeeded but was not recorded: fix the subscription by hand" }
    ApiErrors         = { threshold = 25, periods = 1, period = 300, desc = "More than 25 API errors in 5 minutes" }
    ApiPanics         = { threshold = 1, periods = 1, period = 300, desc = "The API recovered from a panic" }
    WebhookRetries    = { threshold = 5, periods = 1, period = 900, desc = "Razorpay webhooks keep failing (Razorpay will retry for 24 h)" }
  }
}

resource "aws_cloudwatch_metric_alarm" "logs" {
  for_each            = local.log_alarms
  alarm_name          = "${local.name}-${each.key}"
  alarm_description   = each.value.desc
  namespace           = "GreenRoot"
  metric_name         = each.key
  statistic           = "Sum"
  period              = each.value.period
  evaluation_periods  = each.value.periods
  threshold           = each.value.threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  depends_on          = [aws_cloudwatch_log_metric_filter.api]
}

# ── Backups ─────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "backup_missing" {
  alarm_name          = "${local.name}-backup-missing"
  alarm_description   = "No successful logical backup in 26 hours (greenroot-backup.timer)"
  namespace           = "GreenRoot"
  metric_name         = "BackupSucceeded"
  dimensions          = { Environment = var.environment }
  statistic           = "Sum"
  period              = 3600
  evaluation_periods  = 26
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
}

# ── Host and database ───────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "host_status" {
  alarm_name          = "${local.name}-api-host-status"
  alarm_description   = "API host failed its instance status check"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_Instance"
  dimensions          = { InstanceId = aws_instance.api.id }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions       = [aws_sns_topic.alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "host_cpu" {
  alarm_name          = "${local.name}-api-host-cpu"
  alarm_description   = "API host CPU above 80% for 15 minutes: time for a bigger instance"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  dimensions          = { InstanceId = aws_instance.api.id }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alarms.arn]
}

locals {
  db_alarms = {
    cpu         = { metric = "CPUUtilization", op = "GreaterThanThreshold", threshold = 80, desc = "Database CPU above 80%" }
    storage     = { metric = "FreeStorageSpace", op = "LessThanThreshold", threshold = 2 * 1024 * 1024 * 1024, desc = "Database free storage below 2 GB" }
    memory      = { metric = "FreeableMemory", op = "LessThanThreshold", threshold = 64 * 1024 * 1024, desc = "Database freeable memory below 64 MB" }
    connections = { metric = "DatabaseConnections", op = "GreaterThanThreshold", threshold = 70, desc = "Database connections above 70 (max ~80 on micro)" }
    credits     = { metric = "CPUCreditBalance", op = "LessThanThreshold", threshold = 20, desc = "Database CPU credits running out: move to db.t4g.small" }
  }
}

resource "aws_cloudwatch_metric_alarm" "db" {
  for_each            = local.db_alarms
  alarm_name          = "${local.name}-db-${each.key}"
  alarm_description   = each.value.desc
  namespace           = "AWS/RDS"
  metric_name         = each.value.metric
  dimensions          = { DBInstanceIdentifier = aws_db_instance.main.identifier }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = each.value.threshold
  comparison_operator = each.value.op
  alarm_actions       = [aws_sns_topic.alarms.arn]
}

# ── Uptime: Route 53 health check on https://api.<domain>/health ─────────────
# Health-check metrics live in us-east-1, so this alarm and its topic do too.

resource "aws_route53_health_check" "api" {
  fqdn              = local.api_host
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30
  tags = {
    Name = "${local.name}-api"
  }
}

resource "aws_sns_topic" "alarms_us_east_1" {
  provider = aws.us_east_1
  name     = "${local.name}-alarms"
}

resource "aws_sns_topic_subscription" "alarms_us_east_1_email" {
  provider  = aws.us_east_1
  topic_arn = aws_sns_topic.alarms_us_east_1.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "api_down" {
  provider            = aws.us_east_1
  alarm_name          = "${local.name}-api-down"
  alarm_description   = "https://${local.api_host}/health is failing"
  namespace           = "AWS/Route53"
  metric_name         = "HealthCheckStatus"
  dimensions          = { HealthCheckId = aws_route53_health_check.api.id }
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  alarm_actions       = [aws_sns_topic.alarms_us_east_1.arn]
  ok_actions          = [aws_sns_topic.alarms_us_east_1.arn]
}
