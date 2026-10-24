# CloudFront for files.<domain> (public images) and admin.<domain> (dashboard).
# Certificates are in us-east-1 (CloudFront's requirement).

locals {
  use_route53 = var.route53_zone_id != ""
}

resource "aws_acm_certificate" "cdn" {
  provider                  = aws.us_east_1
  domain_name               = local.files_host
  subject_alternative_names = [local.admin_host]
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cdn_validation" {
  for_each = local.use_route53 ? {
    for o in aws_acm_certificate.cdn.domain_validation_options : o.domain_name => o
  } : {}
  zone_id = var.route53_zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 300
}

resource "aws_acm_certificate_validation" "cdn" {
  count                   = local.use_route53 ? 1 : 0
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cdn.arn
  validation_record_fqdns = [for r in aws_route53_record.cdn_validation : r.fqdn]
}

locals {
  # Without Route 53 the certificate must be validated by hand first (output
  # cdn_certificate_validation), then re-apply.
  cdn_certificate_arn = local.use_route53 ? aws_acm_certificate_validation.cdn[0].certificate_arn : aws_acm_certificate.cdn.arn
}

resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "${local.name}-s3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

# Stored file URLs are https://files.<domain>/<prefix><bucket>/<key>
# (platform/storage fileURL). Each public bucket gets a path behaviour; this
# function drops the bucket segment so S3 sees just <key>. Anything else
# (private buckets, unknown paths) is refused.
resource "aws_cloudfront_function" "files_router" {
  name    = "${local.name}-files-router"
  runtime = "cloudfront-js-2.0"
  comment = "Strip the bucket segment for public buckets; refuse everything else"
  publish = true
  code    = <<-JS
    var PUBLIC = ${jsonencode([for b in local.public_buckets : "${local.prefix}${b}"])};
    function handler(event) {
      var req = event.request;
      var parts = req.uri.split('/');            // ["", bucket, key...]
      if (parts.length < 3 || PUBLIC.indexOf(parts[1]) < 0 || parts[2] === '') {
        return { statusCode: 404, statusDescription: 'Not Found' };
      }
      req.uri = '/' + parts.slice(2).join('/');
      return req;
    }
  JS
}

resource "aws_cloudfront_distribution" "files" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${local.name} public images"
  aliases         = [local.files_host]
  price_class     = "PriceClass_200" # includes India edge locations

  dynamic "origin" {
    for_each = toset(local.public_buckets)
    content {
      origin_id                = origin.key
      domain_name              = aws_s3_bucket.platform[origin.key].bucket_regional_domain_name
      origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
    }
  }

  # Unmatched paths: the router answers 404 before any origin is contacted.
  default_cache_behavior {
    target_origin_id       = local.public_buckets[0]
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.optimized.id
    compress               = true
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.files_router.arn
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = toset(local.public_buckets)
    content {
      path_pattern           = "/${local.prefix}${ordered_cache_behavior.key}/*"
      target_origin_id       = ordered_cache_behavior.key
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET", "HEAD"]
      cached_methods         = ["GET", "HEAD"]
      cache_policy_id        = data.aws_cloudfront_cache_policy.optimized.id
      compress               = true
      function_association {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.files_router.arn
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    acm_certificate_arn      = local.cdn_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

data "aws_iam_policy_document" "public_read_via_cdn" {
  for_each = toset(local.public_buckets)
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.platform[each.key].arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.files.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "public_read_via_cdn" {
  for_each = toset(local.public_buckets)
  bucket   = aws_s3_bucket.platform[each.key].id
  policy   = data.aws_iam_policy_document.public_read_via_cdn[each.key].json
}

# ── Admin dashboard ─────────────────────────────────────────────────────────

resource "aws_cloudfront_response_headers_policy" "admin" {
  name = "${local.name}-admin-security"
  security_headers_config {
    content_security_policy {
      override = true
      content_security_policy = join("; ", [
        "default-src 'self'",
        "script-src 'self'",
        "style-src 'self' 'unsafe-inline'", # MUI/emotion inject styles
        "img-src 'self' data: blob: https://${local.files_host} https://*.amazonaws.com",
        "font-src 'self' data:",
        "connect-src 'self' https://${local.api_host} https://*.amazonaws.com",
        "frame-ancestors 'none'",
        "base-uri 'none'",
        "form-action 'self'",
        "object-src 'none'",
      ])
    }
    strict_transport_security {
      override                   = true
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
    }
    content_type_options {
      override = true
    }
    frame_options {
      override     = true
      frame_option = "DENY"
    }
    referrer_policy {
      override        = true
      referrer_policy = "strict-origin-when-cross-origin"
    }
  }
}

resource "aws_cloudfront_distribution" "admin" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${local.name} admin dashboard"
  aliases             = [local.admin_host]
  default_root_object = "index.html"
  price_class         = "PriceClass_200"

  origin {
    origin_id                = "admin"
    domain_name              = aws_s3_bucket.admin.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  default_cache_behavior {
    target_origin_id           = "admin"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = data.aws_cloudfront_cache_policy.optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.admin.id
    compress                   = true
  }

  # Single-page app: client-side routes load index.html.
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    acm_certificate_arn      = local.cdn_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

data "aws_iam_policy_document" "admin_via_cdn" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.admin.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.admin.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "admin" {
  bucket = aws_s3_bucket.admin.id
  policy = data.aws_iam_policy_document.admin_via_cdn.json
}

# ── DNS ─────────────────────────────────────────────────────────────────────

resource "aws_route53_record" "files" {
  count   = local.use_route53 ? 1 : 0
  zone_id = var.route53_zone_id
  name    = local.files_host
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.files.domain_name
    zone_id                = aws_cloudfront_distribution.files.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "admin" {
  count   = local.use_route53 ? 1 : 0
  zone_id = var.route53_zone_id
  name    = local.admin_host
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.admin.domain_name
    zone_id                = aws_cloudfront_distribution.admin.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "api" {
  count   = local.use_route53 ? 1 : 0
  zone_id = var.route53_zone_id
  name    = local.api_host
  type    = "A"
  ttl     = 300
  records = [aws_eip.api.public_ip]
}
