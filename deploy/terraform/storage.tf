# S3: the nine platform buckets (prefixed, STORAGE_BUCKET_PREFIX), all with
# Block Public Access. The four image buckets apps show by URL are served
# through CloudFront (files.<domain>) with Origin Access Control, so nothing
# is publicly readable on S3 itself. Private files (licences, delivery photos,
# PDFs) are only reachable through short presigned links from the API.

resource "aws_s3_bucket" "platform" {
  for_each = toset(local.all_buckets)
  bucket   = "${local.prefix}${each.key}"
}

resource "aws_s3_bucket_public_access_block" "platform" {
  for_each                = aws_s3_bucket.platform
  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "platform" {
  for_each = aws_s3_bucket.platform
  bucket   = each.value.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "platform" {
  for_each = aws_s3_bucket.platform
  bucket   = each.value.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Private documents keep old versions 30 days (accidental overwrite/delete).
resource "aws_s3_bucket_versioning" "private" {
  for_each = toset(local.private_buckets)
  bucket   = aws_s3_bucket.platform[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "platform" {
  for_each = aws_s3_bucket.platform
  bucket   = each.value.id
  rule {
    id     = "housekeeping"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 2
    }
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
  depends_on = [aws_s3_bucket_versioning.private]
}

# The admin dashboard uploads attachments straight from the browser.
resource "aws_s3_bucket_cors_configuration" "uploads" {
  for_each = toset(["attachments", "delivery-photos", "market-ads", "nursery-logos"])
  bucket   = aws_s3_bucket.platform[each.key].id
  cors_rule {
    allowed_methods = ["PUT", "GET"]
    allowed_origins = ["https://${local.admin_host}"]
    allowed_headers = ["Content-Type", "Content-Length"]
    max_age_seconds = 3600
  }
}

# ── Logical backups (pg_dump, off the database host) ─────────────────────────

resource "aws_s3_bucket" "backups" {
  bucket = "${local.prefix}db-backups"
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    id     = "expire-old-dumps"
    status = "Enabled"
    filter {}
    expiration {
      days = var.logical_backup_retention_days
    }
    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
  depends_on = [aws_s3_bucket_versioning.backups]
}

# ── Admin dashboard (static build) ───────────────────────────────────────────

resource "aws_s3_bucket" "admin" {
  bucket = "${local.prefix}admin-web"
}

resource "aws_s3_bucket_public_access_block" "admin" {
  bucket                  = aws_s3_bucket.admin.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "admin" {
  bucket = aws_s3_bucket.admin.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ── Container registry ───────────────────────────────────────────────────────

resource "aws_ecr_repository" "api" {
  name                 = "${local.name}-api"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last 20 images (rollback room)"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 20 }
      action       = { type = "expire" }
    }]
  })
}
