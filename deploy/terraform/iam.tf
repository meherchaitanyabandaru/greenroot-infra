# The host's instance role is the only AWS identity the API uses: S3, SES,
# SMS, Secrets Manager and CloudWatch all take credentials from it. No access
# keys exist anywhere.

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api_host" {
  name               = "${local.name}-api-host"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Shell access through SSM Session Manager (no SSH port, no keys).
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.api_host.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "api_host" {
  statement {
    sid       = "ReadSettings"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [aws_secretsmanager_secret.api.arn, aws_db_instance.main.master_user_secret[0].secret_arn]
  }
  statement {
    sid       = "UpdateSettings" # deploy/host/bin/set-secret.sh
    actions   = ["secretsmanager:PutSecretValue"]
    resources = [aws_secretsmanager_secret.api.arn]
  }
  statement {
    sid     = "PlatformBuckets"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket", "s3:GetBucketLocation"]
    resources = flatten([
      for b in aws_s3_bucket.platform : [b.arn, "${b.arn}/*"]
    ])
  }
  statement {
    sid       = "Backups"
    actions   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
    resources = [aws_s3_bucket.backups.arn, "${aws_s3_bucket.backups.arn}/*"]
  }
  statement {
    sid       = "PullImages"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    actions   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"]
    resources = [aws_ecr_repository.api.arn]
  }
  statement {
    sid       = "Logs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
    resources = ["${aws_cloudwatch_log_group.api.arn}:*", "${aws_cloudwatch_log_group.host.arn}:*"]
  }
  statement {
    sid       = "BackupMetric"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["GreenRoot"]
    }
  }
  statement {
    sid       = "Email"
    actions   = ["ses:SendEmail", "ses:SendRawEmail"]
    resources = ["*"]
  }
  statement {
    sid       = "SMS"
    actions   = ["sms-voice:SendTextMessage"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "api_host" {
  name   = "greenroot-api"
  role   = aws_iam_role.api_host.id
  policy = data.aws_iam_policy_document.api_host.json
}

resource "aws_iam_instance_profile" "api_host" {
  name = "${local.name}-api-host"
  role = aws_iam_role.api_host.name
}

# ── CI: GitHub Actions pushes images and asks the host to deploy (OIDC, no keys)

resource "aws_iam_openid_connect_provider" "github" {
  count           = var.github_repository == "" ? 0 : 1
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "github_assume" {
  count = var.github_repository == "" ? 0 : 1
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github[0].arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Only release tags of the API repository may deploy.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:ref:refs/tags/v*"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  count              = var.github_repository == "" ? 0 : 1
  name               = "${local.name}-github-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_assume[0].json
}

data "aws_iam_policy_document" "github_deploy" {
  count = var.github_repository == "" ? 0 : 1
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    actions = ["ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
    "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:BatchGetImage"]
    resources = [aws_ecr_repository.api.arn]
  }
  statement {
    actions   = ["ssm:SendCommand"]
    resources = [aws_instance.api.arn, "arn:aws:ssm:${var.region}::document/AWS-RunShellScript"]
  }
  statement {
    actions   = ["ssm:GetCommandInvocation"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  count  = var.github_repository == "" ? 0 : 1
  name   = "deploy"
  role   = aws_iam_role.github_deploy[0].id
  policy = data.aws_iam_policy_document.github_deploy[0].json
}
