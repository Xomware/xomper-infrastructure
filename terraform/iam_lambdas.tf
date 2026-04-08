# =============================================================================
# IAM Roles for Lambda Functions
# Split into: authorizer role, API lambda role
# =============================================================================

# -----------------------------------------------------------------------------
# Shared assume role policy for Lambda
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Separate assume role for API lambdas (needs API GW + Step Functions)
data "aws_iam_policy_document" "api_lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com", "apigateway.amazonaws.com", "states.amazonaws.com"]
    }
  }
}

# -----------------------------------------------------------------------------
# Authorizer Lambda Role -- minimal permissions
# -----------------------------------------------------------------------------
resource "aws_iam_role" "authorizer_role" {
  name               = "${var.app_name}-authorizer-exec"
  tags               = merge(local.standard_tags, tomap({ "name" = "${var.app_name}-authorizer-exec" }))
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "authorizer_role_policy" {
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:log-group:/aws/lambda/${var.app_name}-authorizer*"]
  }

  statement {
    sid    = "SSMReadOnly"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:parameter/${var.app_name}/*"]
  }

  statement {
    sid    = "KMSDecrypt"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    resources = [
      "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:key/*"
    ]
  }

  statement {
    sid    = "XRayTracing"
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "authorizer_role_policy" {
  name   = "${var.app_name}-authorizer-role-policy"
  role   = aws_iam_role.authorizer_role.id
  policy = data.aws_iam_policy_document.authorizer_role_policy.json
}

# -----------------------------------------------------------------------------
# API Lambda Role -- for email + CRUD lambdas
# -----------------------------------------------------------------------------
resource "aws_iam_role" "lambda_role" {
  name               = "${var.app_name}-lambda-exec"
  tags               = merge(local.standard_tags, tomap({ "name" = "${var.app_name}-lambda-exec" }))
  assume_role_policy = data.aws_iam_policy_document.api_lambda_assume_role.json
}

data "aws_iam_policy_document" "lambda_role_policy" {
  statement {
    sid    = "EC2NetworkInterfaces"
    effect = "Allow"
    actions = [
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeInstances",
      "ec2:AttachNetworkInterface"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "S3BucketAccess"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObjectAcl",
      "s3:GetObject",
      "s3:ListAllMyBuckets",
      "s3:GetObjectTagging",
      "s3:ListBucket",
      "s3:PutObjectTagging",
      "s3:GetBucketLocation",
      "s3:PutObjectAcl",
      "s3:GetObjectVersion",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion"
    ]
    resources = [
      "${module.web.s3_bucket_arn}",
      "${module.web.s3_bucket_arn}/*"
    ]
  }

  statement {
    sid    = "SSMParameters"
    effect = "Allow"
    actions = [
      "ssm:PutParameters",
      "ssm:PutParameter",
      "ssm:DeleteParameter",
      "ssm:DeleteParameters",
      "ssm:GetParameters",
      "ssm:GetParameter",
      "ssm:GetParameterHistory",
      "ssm:GetParametersByPath"
    ]
    resources = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:parameter/${var.app_name}/*"]
  }

  statement {
    sid    = "SecretsManagerAccess"
    effect = "Allow"
    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets",
      "secretsmanager:ListSecretVersionIds",
      "secretsmanager:UpdateSecretVersionStage",
      "secretsmanager:PutSecretValue",
      "secretsmanager:RotateSecret"
    ]
    resources = ["arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:secret:${var.app_name}-*"]
  }

  statement {
    sid    = "SecretsManagerRandom"
    effect = "Allow"
    actions = [
      "secretsmanager:GetRandomPassword"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:ListLogDeliveries",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
      "logs:FilterLogEvents"
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:log-group:/aws/lambda/${var.app_name}*"]
  }

  statement {
    sid    = "KMSAccess"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:GenerateDataKeyWithoutPlainText",
      "kms:DescribeKey",
      "kms:ReEncryptFrom",
      "kms:ReEncryptTo",
      "kms:ListAliases"
    ]
    resources = [
      "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:key/*"
    ]
  }

  statement {
    sid    = "LambdaInvoke"
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction",
      "lambda:GetFunction",
      "lambda:GetAlias",
      "lambda:ListFunctions",
      "lambda:ListAliases",
      "lambda:ListVersionsByFunction"
    ]
    resources = [
      "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:function:${var.app_name}*"
    ]
  }

  statement {
    sid     = "APIGatewayInvoke"
    effect  = "Allow"
    actions = ["execute-api:Invoke"]
    resources = [
      "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:${module.api.rest_api_id}/*/*/*"
    ]
  }

  statement {
    sid    = "XRayTracing"
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "xray:GetSamplingStatisticSummaries"
    ]
    resources = ["*"]
  }

  # DynamoDB runtime access -- no CreateTable/DeleteTable (those are Terraform's job)
  statement {
    sid    = "DynamoDBRuntime"
    effect = "Allow"
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchWriteItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DescribeStream",
      "dynamodb:GetShardIterator",
      "dynamodb:GetRecords",
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable"
    ]
    resources = [
      "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:table/${var.app_name}*",
      "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:table/${var.app_name}*/index/*",
      "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:table/${var.app_name}*/stream/*"
    ]
  }

  # SNS Push Notifications
  statement {
    sid    = "SNSPushNotifications"
    effect = "Allow"
    actions = [
      "sns:CreatePlatformEndpoint",
      "sns:DeleteEndpoint",
      "sns:GetEndpointAttributes",
      "sns:SetEndpointAttributes",
      "sns:Publish"
    ]
    resources = [
      aws_sns_platform_application.apns.arn,
      "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:endpoint/APNS/${var.app_name}-apns/*"
    ]
  }

  # SES scoped to the verified domain identity
  statement {
    sid    = "SESSendEmail"
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail"
    ]
    resources = [
      "arn:aws:ses:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:identity/${local.domain_name}"
    ]
  }
}

resource "aws_iam_role_policy" "lambda_role_policy" {
  name   = "${var.app_name}-lambda-role-policy"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.lambda_role_policy.json
}
