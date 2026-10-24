output "api_url" {
  value = "https://${local.api_host}"
}

output "admin_url" {
  value = "https://${local.admin_host}"
}

output "files_url" {
  value = "https://${local.files_host}"
}

output "api_host_public_ip" {
  description = "Point api.<domain> here (A record) if you do not use Route 53."
  value       = aws_eip.api.public_ip
}

output "api_instance_id" {
  description = "aws ssm start-session --target <this>"
  value       = aws_instance.api.id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.api.repository_url
}

output "api_secret_arn" {
  description = "Secrets Manager secret with every API setting (AWS_SECRETS_ID)."
  value       = aws_secretsmanager_secret.api.arn
}

output "db_endpoint" {
  value = aws_db_instance.main.address
}

output "admin_bucket" {
  value = aws_s3_bucket.admin.bucket
}

output "admin_distribution_id" {
  value = aws_cloudfront_distribution.admin.id
}

output "backup_bucket" {
  value = aws_s3_bucket.backups.bucket
}

output "github_deploy_role_arn" {
  value = try(aws_iam_role.github_deploy[0].arn, "")
}

output "dns_records_to_create" {
  description = "Only when route53_zone_id is empty: create these at your DNS provider."
  value = local.use_route53 ? {} : {
    (local.api_host)   = "A ${aws_eip.api.public_ip}"
    (local.files_host) = "CNAME ${aws_cloudfront_distribution.files.domain_name}"
    (local.admin_host) = "CNAME ${aws_cloudfront_distribution.admin.domain_name}"
  }
}

output "cdn_certificate_validation" {
  description = "Only when route53_zone_id is empty: DNS records that validate the CloudFront certificate."
  value = local.use_route53 ? [] : [
    for o in aws_acm_certificate.cdn.domain_validation_options : "${o.resource_record_name} ${o.resource_record_type} ${o.resource_record_value}"
  ]
}
