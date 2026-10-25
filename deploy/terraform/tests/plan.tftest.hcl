# Plans the whole stack against mocked AWS (no account, no cost):
#   terraform init -backend=false && terraform test
mock_provider "aws" {
  mock_resource "aws_sns_topic" {
    defaults = { arn = "arn:aws:sns:ap-south-1:123456789012:greenroot-alarms" }
  }
  mock_resource "aws_cloudfront_function" {
    defaults = { arn = "arn:aws:cloudfront::123456789012:function/greenroot-files-router" }
  }
  mock_resource "aws_cloudfront_distribution" {
    defaults = { arn = "arn:aws:cloudfront::123456789012:distribution/E123EXAMPLE" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/greenroot" }
  }
  mock_resource "aws_iam_openid_connect_provider" {
    defaults = { arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com" }
  }
  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws:s3:::greenroot-mock" }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:ap-south-1:123456789012:log-group:/greenroot/api" }
  }
  mock_resource "aws_secretsmanager_secret" {
    defaults = { arn = "arn:aws:secretsmanager:ap-south-1:123456789012:secret:greenroot/api" }
  }
  mock_resource "aws_ecr_repository" {
    defaults = { arn = "arn:aws:ecr:ap-south-1:123456789012:repository/greenroot-api" }
  }
  mock_resource "aws_instance" {
    defaults = { arn = "arn:aws:ec2:ap-south-1:123456789012:instance/i-0123456789abcdef0", id = "i-0123456789abcdef0" }
  }
  override_data {
    target = data.aws_subnets.default
    values = { ids = ["subnet-aaaa1111", "subnet-bbbb2222", "subnet-cccc3333"] }
  }
  override_data {
    target = data.aws_ec2_instance_type.api
    values = { supported_architectures = ["arm64"] }
  }
  override_data {
    target = data.aws_ssm_parameter.al2023
    values = { value = "ami-0123456789abcdef0" }
  }
  override_data {
    target = data.aws_iam_policy_document.api_host
    values = { json = "{}" }
  }
  override_data {
    target = data.aws_iam_policy_document.ec2_assume
    values = { json = "{}" }
  }
  override_data {
    target = data.aws_iam_policy_document.dlm_assume
    values = { json = "{}" }
  }
  override_data {
    target = data.aws_iam_policy_document.github_assume
    values = { json = "{}" }
  }
  override_data {
    target = data.aws_iam_policy_document.github_deploy
    values = { json = "{}" }
  }
  override_data {
    target = data.aws_iam_policy_document.public_read_via_cdn
    values = { json = "{}" }
  }
  override_data {
    target = data.aws_iam_policy_document.admin_via_cdn
    values = { json = "{}" }
  }
  override_resource {
    target = aws_db_instance.main
    values = {
      address            = "greenroot-production.abc123.ap-south-1.rds.amazonaws.com"
      identifier         = "greenroot-production"
      master_user_secret = [{ secret_arn = "arn:aws:secretsmanager:ap-south-1:123456789012:secret:rds!db-1", kms_key_id = "", secret_status = "active" }]
    }
  }
}

mock_provider "aws" {
  alias = "us_east_1"
  mock_resource "aws_acm_certificate" {
    defaults = { arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000" }
  }
  mock_resource "aws_sns_topic" {
    defaults = { arn = "arn:aws:sns:us-east-1:123456789012:greenroot-alarms" }
  }
}

mock_provider "random" {}

variables {
  domain      = "greenroot.in"
  alarm_email = "ops@greenroot.in"
}

# Mocked apply: nothing reaches AWS; computed values become known.
run "production_stack" {
  command = apply

  assert {
    condition     = length(aws_instance.api.user_data_base64) < 16384
    error_message = "cloud-init must stay under EC2's 16 KB user-data limit"
  }
  assert {
    condition     = aws_instance.api.metadata_options[0].http_tokens == "required" && aws_instance.api.metadata_options[0].http_put_response_hop_limit == 2
    error_message = "IMDSv2 only, reachable from containers"
  }
  assert {
    condition     = aws_db_instance.main.publicly_accessible == false && aws_db_instance.main.storage_encrypted && aws_db_instance.main.deletion_protection
    error_message = "the database must be private, encrypted and protected from deletion"
  }
  assert {
    condition     = aws_db_instance.main.backup_retention_period >= 7
    error_message = "point-in-time recovery needs at least 7 days of backups"
  }
  assert {
    condition     = alltrue([for b in aws_s3_bucket_public_access_block.platform : b.block_public_acls && b.block_public_policy && b.restrict_public_buckets])
    error_message = "no platform bucket may be public on S3 (CloudFront serves the public images)"
  }
  assert {
    condition     = length(aws_s3_bucket.platform) == 9
    error_message = "all nine platform buckets (platform/storage validBuckets)"
  }
  assert {
    condition     = alltrue([for b in ["profile-images", "plant-images", "market-ads", "nursery-logos"] : strcontains(aws_cloudfront_function.files_router.code, "greenroot-production-${b}")])
    error_message = "the files router must serve every public bucket"
  }
  assert {
    condition     = !strcontains(aws_cloudfront_function.files_router.code, "attachments")
    error_message = "private buckets must never be routed through the public CDN"
  }
  assert {
    condition     = jsondecode(aws_secretsmanager_secret_version.api.secret_string).TRUSTED_PROXIES == "172.16.0.0/12"
    error_message = "the API must trust Caddy's Docker network"
  }
  assert {
    condition     = jsondecode(aws_secretsmanager_secret_version.api.secret_string).STORAGE_BUCKET_PREFIX == "greenroot-production-"
    error_message = "bucket prefix must match the S3 bucket names"
  }
  assert {
    condition     = length(aws_route53_record.api) == 0 && length(output.dns_records_to_create) == 3
    error_message = "without a Route 53 zone the DNS records are listed for manual creation"
  }
}
