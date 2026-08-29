###############################################################################
# Social graph
#
# One table for friendships now, comments and reactions later. A generic
# pk/sk pair rather than named keys, because those three are different shapes
# of the same thing -- an actor, a target, and a timestamp -- and three tables
# would mean three sets of IAM and three places to keep in step.
#
# Keyed on the Cognito sub, never the Sleeper handle. Handle claims are
# unverified by design, so a graph built on them would let anyone befriend or
# be befriended as someone else.
###############################################################################

resource "aws_dynamodb_table" "social" {
  deletion_protection_enabled = true
  name                        = "${var.app_name}-social"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "pk"
  range_key                   = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.dynamodb_kms_key_arn
  }

  # User-authored relationships that nothing can reconstruct. Unlike the
  # warehouse tables, losing this loses something real.
  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.standard_tags, { "name" = "${var.app_name}-social" })
}

###############################################################################
# /me/friends — the caller's social graph
#
# Flat paths for the same reason as the rest of /me: api-gateway-service keys
# one API Gateway resource per endpoint on path_part, so two methods sharing a
# part collide at apply time.
###############################################################################

resource "aws_lambda_function" "users_friends" {
  function_name    = "${var.app_name}-api-users-friends"
  description      = "The caller's friends: list, request, accept, remove"
  filename         = "./templates/lambda_stub.zip"
  source_code_hash = filebase64sha256("./templates/lambda_stub.zip")
  handler          = "handler.handler"
  layers           = [data.aws_lambda_layer_version.shared_latest.arn]
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
    "name"        = "${var.app_name}-api-users-friends"
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
