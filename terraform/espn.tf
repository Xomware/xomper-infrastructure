###############################################################################
# ESPN league read proxy
#
# A public ESPN league is readable straight from the browser, but a private one
# needs the member's espn_s2 and SWID cookies and browsers will not send those
# cross-site. So the read happens here instead, with cookies the user handed
# over, stored on their own platform_users row.
#
# No new IAM: this uses the shared lambda_role, which platform_users_access in
# platform_users.tf already grants on that table.
#
# Route paths are flat and one method each (`connect`, not `credentials` with
# PUT and DELETE) because api-gateway-service keys one API Gateway resource per
# endpoint on `path_part`, so two methods on one part collide at apply time.
# Same shape as /me/sleeper-link and /me/sleeper-unlink.
###############################################################################

resource "aws_lambda_function" "espn_league" {
  function_name    = "${var.app_name}-api-espn-league"
  description      = "Proxy ESPN league reads and hold the caller's ESPN cookies"
  filename         = "./templates/lambda_stub.zip"
  source_code_hash = filebase64sha256("./templates/lambda_stub.zip")
  handler          = "handler.handler"
  layers           = [data.aws_lambda_layer_version.shared_latest.arn]
  runtime          = var.lambda_runtime
  memory_size      = var.lambda_memory_size
  role             = aws_iam_role.lambda_role.arn

  # ESPN's league endpoint is slower than a DynamoDB read, and kona_player_info
  # for a whole league is the slowest call this function makes.
  timeout = 30

  environment {
    variables = local.lambda_variables
  }

  tracing_config {
    mode = var.lambda_trace_mode
  }

  tags = merge(local.standard_tags, tomap({
    "name"        = "${var.app_name}-api-espn-league"
    "lambda_type" = "api"
    "handler_dir" = "api_espn_league"
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

resource "aws_cloudwatch_log_group" "espn_league" {
  name              = "/aws/lambda/${aws_lambda_function.espn_league.function_name}"
  retention_in_days = 14
  tags              = local.standard_tags
}
