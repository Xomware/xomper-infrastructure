###############################################################################
# Platform identity storage
#
# Phase 4.6 and 4.8. The platform authenticates against the shared Cognito pool
# (see the xomper client in xomware-infrastructure), so these hold what Cognito
# does not: which Sleeper account a user has linked, and which leagues they
# follow.
#
# No migration. Supabase `profiles` rows stay with clt-dynasty-league; the
# platform starts empty because it has no users yet.
###############################################################################

# Rebuilds the Supabase `profiles` contract: cognito sub -> linked Sleeper
# account plus display metadata.
resource "aws_dynamodb_table" "platform_users" {
  deletion_protection_enabled = true
  name                        = "${var.app_name}-users"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "userId"

  attribute {
    name = "userId"
    type = "S"
  }

  # Looking a user up by their Sleeper id is how a shared league resolves who
  # else on a roster has an account here.
  attribute {
    name = "sleeperUserId"
    type = "S"
  }

  global_secondary_index {
    name            = "sleeperUserId-index"
    hash_key        = "sleeperUserId"
    projection_type = "ALL"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.dynamodb_kms_key_arn
  }

  # User-authored state that nothing can reconstruct, unlike the warehouse
  # tables. PITR stays on.
  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.standard_tags, { "name" = "${var.app_name}-users" })
}

# The inversion of `whitelisted_leagues`: instead of an admin allowing leagues
# in, users follow the leagues they care about.
#
# This is the cost control. Every scheduled job iterates followed leagues, so
# work scales with what people actually use rather than with everything that
# exists on Sleeper.
resource "aws_dynamodb_table" "platform_follows" {
  deletion_protection_enabled = true
  name                        = "${var.app_name}-follows"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "userId"
  range_key                   = "leagueId"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "leagueId"
    type = "S"
  }

  # Cron work list: every follower of a league, without scanning the table.
  global_secondary_index {
    name            = "leagueId-index"
    hash_key        = "leagueId"
    projection_type = "ALL"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.dynamodb_kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.standard_tags, { "name" = "${var.app_name}-follows" })
}

resource "aws_iam_role_policy" "platform_users_access" {
  name = "${var.app_name}-platform-users-access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PlatformIdentityTables"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
        ]
        Resource = [
          aws_dynamodb_table.platform_users.arn,
          "${aws_dynamodb_table.platform_users.arn}/index/*",
          aws_dynamodb_table.platform_follows.arn,
          "${aws_dynamodb_table.platform_follows.arn}/index/*",
        ]
      },
    ]
  })
}

output "platform_users_table" {
  value = aws_dynamodb_table.platform_users.name
}

output "platform_follows_table" {
  value = aws_dynamodb_table.platform_follows.name
}

###############################################################################
# /me — the current user's platform record
#
# Replaces the direct Supabase `profiles` read the frontend used to do. Three
# routes share one Lambda: they read the same item, resolve identity the same
# way, and return the same shape.
#
# Route paths are flat (`sleeper-link`, not `sleeper/link`) because
# api-gateway-service keys one API Gateway resource per endpoint on
# `path_part`, so two methods on one part collide at apply time.
###############################################################################

resource "aws_lambda_function" "users_me" {
  function_name    = "${var.app_name}-api-users-me"
  description      = "Current user's platform record: read, link Sleeper, unlink"
  filename         = "./templates/lambda_stub.zip"
  source_code_hash = filebase64sha256("./templates/lambda_stub.zip")
  handler          = "handler.handler"
  layers           = [aws_lambda_layer_version.lambda_layer.arn]
  runtime          = var.lambda_runtime
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout
  role             = aws_iam_role.lambda_role.arn

  environment {
    variables = local.lambda_variables
  }

  tracing_config {
    mode = var.lambda_trace_mode
  }

  tags = merge(local.standard_tags, tomap({
    "name"        = "${var.app_name}-api-users-me"
    "lambda_type" = "api"
  }))

  # Code is deployed from the backend repo; Terraform owns the shape only.
  lifecycle {
    ignore_changes = [
      description,
      filename,
      source_code_hash,
      layers
    ]
  }

  depends_on = [
    aws_iam_role_policy.lambda_role_policy,
    aws_iam_role.lambda_role
  ]
}

###############################################################################
# /me/leagues — which leagues the caller is in, and which they follow
#
# The league list itself comes from Sleeper live; only the follow set is
# stored. Three routes share one Lambda for the same reason /me/profile does:
# one table, one identity read, one response shape.
###############################################################################

resource "aws_lambda_function" "users_leagues" {
  function_name    = "${var.app_name}-api-users-leagues"
  description      = "The caller's leagues, with follow state"
  filename         = "./templates/lambda_stub.zip"
  source_code_hash = filebase64sha256("./templates/lambda_stub.zip")
  handler          = "handler.handler"
  layers           = [aws_lambda_layer_version.lambda_layer.arn]
  runtime          = var.lambda_runtime
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout
  role             = aws_iam_role.lambda_role.arn

  environment {
    variables = local.lambda_variables
  }

  tracing_config {
    mode = var.lambda_trace_mode
  }

  tags = merge(local.standard_tags, tomap({
    "name"        = "${var.app_name}-api-users-leagues"
    "lambda_type" = "api"
  }))

  # Code is deployed from the backend repo; Terraform owns the shape only.
  lifecycle {
    ignore_changes = [
      description,
      filename,
      source_code_hash,
      layers
    ]
  }

  depends_on = [
    aws_iam_role_policy.lambda_role_policy,
    aws_iam_role.lambda_role
  ]
}
