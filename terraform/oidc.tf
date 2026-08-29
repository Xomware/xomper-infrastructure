#**********************
# GitHub Actions OIDC
# Keyless auth for the frontend and backend deploy workflows
#**********************

# Account-wide, created by whichever stack migrated first.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# One role per repo. The trust policy is the entire security boundary for OIDC,
# so a token minted in the frontend repo must not be able to touch lambdas.
locals {
  github_oidc_subjects = {
    frontend = var.github_frontend_subjects
    backend  = var.github_backend_subjects
  }
}

data "aws_iam_policy_document" "github_actions_trust" {
  for_each = local.github_oidc_subjects

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Any ref in the repo -- these workflows also run via workflow_dispatch from
    # other refs, which a ref-pinned subject would break.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for subject in each.value : "${subject}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  for_each = local.github_oidc_subjects

  name               = "${var.app_name}-github-actions-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust[each.key].json

  tags = merge(local.standard_tags, tomap({ "name" = "${var.app_name}-github-actions-${each.key}" }))
}

data "aws_iam_policy_document" "github_actions_frontend" {
  statement {
    sid    = "PublishSite"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      module.web.s3_bucket_arn,
      "${module.web.s3_bucket_arn}/*",
    ]
  }

  # The deploy resolves its distribution by alias at runtime and
  # ListDistributions has no resource form -- account-wide or nothing.
  # Read-only; the invalidation itself is scoped below.
  statement {
    sid       = "FindDistribution"
    effect    = "Allow"
    actions   = ["cloudfront:ListDistributions"]
    resources = ["*"]
  }

  # Get as well as Create: some of these deploys wait for the invalidation to
  # finish rather than firing and forgetting, so they poll.
  statement {
    sid    = "InvalidateCache"
    effect = "Allow"
    actions = [
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation",
    ]
    resources = [module.web.cloudfront_distribution_arn]
  }

  statement {
    sid     = "ReadBuildConfig"
    effect  = "Allow"
    actions = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:parameter/xomper/api/*",
    ]
  }

  # Decrypt covers the SecureString parameters; GenerateDataKey and Encrypt
  # cover writing to the site bucket, which is KMS-encrypted -- s3:PutObject
  # alone fails there with an AccessDenied on kms:GenerateDataKey.
  statement {
    sid    = "UseWebAppKey"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
    ]
    resources = [aws_kms_alias.web_app.target_key_arn]
  }
}

resource "aws_iam_role_policy" "github_actions_frontend" {
  name   = "deploy"
  role   = aws_iam_role.github_actions["frontend"].id
  policy = data.aws_iam_policy_document.github_actions_frontend.json
}

data "aws_iam_policy_document" "github_actions_backend" {
  statement {
    sid    = "PublishSharedLayer"
    effect = "Allow"
    actions = [
      "lambda:PublishLayerVersion",
      "lambda:ListLayerVersions",
    ]
    resources = [
      "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:layer:${var.app_name}-shared-packages",
      "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:layer:${var.app_name}-shared-packages:*",
    ]
  }

  # UpdateFunctionConfiguration --layers needs GetLayerVersion on EVERY layer
  # in the list it is given, not just the one being changed. Scoped to the
  # shared layer alone, attaching it to a function that also carries
  # xomper-duckdb was denied -- so api-values-compute silently kept an old
  # shared layer through three deploys that all reported success.
  #
  # Read-only, and by name prefix like DeployFunctions below, so a new layer
  # needs no IAM change. Publishing stays scoped to the shared layer above.
  statement {
    sid       = "ReadOwnLayers"
    effect    = "Allow"
    actions   = ["lambda:GetLayerVersion"]
    resources = ["arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:layer:${var.app_name}-*:*"]
  }

  statement {
    sid       = "ListLayers"
    effect    = "Allow"
    actions   = ["lambda:ListLayers"]
    resources = ["*"]
  }


  # By name prefix, so a new lambda needs no IAM change to be deployable.
  statement {
    sid    = "DeployFunctions"
    effect = "Allow"
    actions = [
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
    ]
    resources = ["arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:function:${var.app_name}-*"]
  }
}

resource "aws_iam_role_policy" "github_actions_backend" {
  name   = "deploy"
  role   = aws_iam_role.github_actions["backend"].id
  policy = data.aws_iam_policy_document.github_actions_backend.json
}

output "github_actions_frontend_role_arn" {
  description = "Role the frontend deploy workflow assumes via OIDC"
  value       = aws_iam_role.github_actions["frontend"].arn
}

output "github_actions_backend_role_arn" {
  description = "Role the backend deploy workflow assumes via OIDC"
  value       = aws_iam_role.github_actions["backend"].arn
}
